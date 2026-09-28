from rest_framework.exceptions import APIException
from rest_framework.permissions import BasePermission

from .services import get_subscription_access


class SubscriptionRequired(APIException):
    status_code = 403
    default_code = 'subscription_required'

    def __init__(self, access):
        reason = access.get('reason') or 'none'
        if reason == 'expired':
            message = 'Срок подписки истёк. Продлите подписку в родительском кабинете.'
        elif reason == 'pending':
            message = 'Подписка ожидает оплаты.'
        else:
            message = 'Для обучающего режима нужна активная подписка.'

        super().__init__({
            'code': 'subscription_required',
            'reason': reason,
            'detail': message,
            'ends_at': access.get('ends_at'),
        })


class HasActiveSubscription(BasePermission):
    """Protect child-learning API while leaving parent/payment API accessible."""

    def has_permission(self, request, view):
        user = getattr(request, 'user', None)
        if user is None or not user.is_authenticated:
            return False

        access = get_subscription_access(user)
        if access['active']:
            return True

        raise SubscriptionRequired(access)
