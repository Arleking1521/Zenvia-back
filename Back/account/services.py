from django.utils import timezone
from rest_framework.exceptions import ValidationError

from .models import ChildProfile, Subscription


CHILD_PROFILE_HEADER = 'X-Child-Profile-ID'


def get_child_profile(request, *, required=True):
    """Возвращает выбранный профиль ребёнка, принадлежащий request.user.

    Клиент передаёт X-Child-Profile-ID. Для обратной совместимости, если у
    родителя ровно один активный детский профиль, он выбирается автоматически.
    """

    raw_id = request.headers.get(CHILD_PROFILE_HEADER)
    if not raw_id:
        raw_id = request.query_params.get('child_id')

    queryset = ChildProfile.objects.filter(parent=request.user, is_active=True)

    if raw_id:
        try:
            child_id = int(raw_id)
        except (TypeError, ValueError):
            raise ValidationError({'child_profile': 'Некорректный ID профиля ребёнка.'})

        profile = queryset.filter(pk=child_id).first()
        if not profile:
            raise ValidationError({'child_profile': 'Профиль ребёнка не найден или не принадлежит этому родителю.'})
        return profile

    children = list(queryset[:2])
    if len(children) == 1:
        return children[0]

    if not children:
        if required:
            raise ValidationError({'child_profile': 'Сначала создайте профиль ребёнка.'})
        return None

    if required:
        raise ValidationError({
            'child_profile': (
                f'Выберите профиль ребёнка и передайте его ID в заголовке {CHILD_PROFILE_HEADER}.'
            )
        })

    return None


def get_active_subscription(parent):
    """Return the newest currently active subscription for a parent."""
    subscriptions = (
        Subscription.objects
        .filter(parent=parent, status=Subscription.STATUS_ACTIVE)
        .select_related('tariff')
        .order_by('-created_at')
    )
    return next((item for item in subscriptions if item.is_current), None)



def get_subscription_access(parent):
    """Return a compact subscription-access state for child mode.

    Subscription.status is intentionally not mutated here: an active record can
    naturally become expired when ends_at passes. The access decision always
    uses is_current, so stale ACTIVE rows never grant learning access.
    """
    active = get_active_subscription(parent)
    if active is not None:
        return {
            'active': True,
            'reason': 'active',
            'subscription_id': active.id,
            'status': active.status,
            'tariff_id': active.tariff_id,
            'tariff_title': active.tariff.title,
            'ends_at': active.ends_at,
        }

    latest = (
        Subscription.objects
        .filter(parent=parent)
        .select_related('tariff')
        .order_by('-created_at')
        .first()
    )

    if latest is None:
        return {
            'active': False,
            'reason': 'none',
            'subscription_id': None,
            'status': None,
            'tariff_id': None,
            'tariff_title': None,
            'ends_at': None,
        }

    now = timezone.now()
    if latest.status == Subscription.STATUS_PENDING:
        reason = 'pending'
    elif latest.status == Subscription.STATUS_CANCELLED:
        reason = 'cancelled'
    elif (
        latest.status == Subscription.STATUS_EXPIRED
        or (latest.ends_at is not None and latest.ends_at <= now)
    ):
        reason = 'expired'
    elif latest.status == Subscription.STATUS_ACTIVE:
        # Covers future-dated or otherwise inactive ACTIVE rows.
        reason = 'inactive'
    else:
        reason = 'none'

    return {
        'active': False,
        'reason': reason,
        'subscription_id': latest.id,
        'status': latest.status,
        'tariff_id': latest.tariff_id,
        'tariff_title': latest.tariff.title,
        'ends_at': latest.ends_at,
    }

def get_child_profile_access(parent):
    """Server-side source of truth for child-profile creation limits."""
    subscription = get_active_subscription(parent)
    active_children = ChildProfile.objects.filter(
        parent=parent,
        is_active=True,
    ).count()

    if subscription is None:
        return {
            'active_subscription': False,
            'subscription_id': None,
            'tariff_id': None,
            'tariff_title': None,
            'max_children': 0,
            'active_children': active_children,
            'remaining_slots': 0,
            'can_create_child': False,
            'reason': 'Для создания профиля ребёнка нужна активная подписка.',
        }

    max_children = max(0, int(subscription.tariff.max_children))
    remaining = max(max_children - active_children, 0)
    return {
        'active_subscription': True,
        'subscription_id': subscription.id,
        'tariff_id': subscription.tariff_id,
        'tariff_title': subscription.tariff.title,
        'max_children': max_children,
        'active_children': active_children,
        'remaining_slots': remaining,
        'can_create_child': remaining > 0,
        'reason': (
            None
            if remaining > 0
            else f'Лимит профилей по тарифу исчерпан: {active_children} из {max_children}.'
        ),
    }
