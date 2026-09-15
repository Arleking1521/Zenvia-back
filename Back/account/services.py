from rest_framework.exceptions import ValidationError

from .models import ChildProfile


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
