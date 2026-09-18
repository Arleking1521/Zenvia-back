from dataclasses import dataclass
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from account.models import ChildProfile

from .models import DailyXP


DEFAULT_DAILY_XP_LIMIT = 100
DEFAULT_DAILY_XP_TIMEZONE = 'Asia/Almaty'


@dataclass(frozen=True)
class XPAwardResult:
    requested_xp: int
    granted_xp: int
    daily_xp: int
    daily_xp_limit: int
    daily_xp_remaining: int
    daily_limit_reached: bool
    date: str

    def as_dict(self):
        return {
            'xp_requested': self.requested_xp,
            'xp_granted': self.granted_xp,
            'daily_xp': self.daily_xp,
            'daily_xp_limit': self.daily_xp_limit,
            'daily_xp_remaining': self.daily_xp_remaining,
            'daily_limit_reached': self.daily_limit_reached,
            'daily_xp_date': self.date,
        }


def get_daily_xp_limit() -> int:
    try:
        return max(0, int(getattr(settings, 'DAILY_XP_LIMIT', DEFAULT_DAILY_XP_LIMIT)))
    except (TypeError, ValueError):
        return DEFAULT_DAILY_XP_LIMIT


def get_daily_xp_timezone():
    name = getattr(settings, 'DAILY_XP_TIMEZONE', DEFAULT_DAILY_XP_TIMEZONE)
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, TypeError, ValueError):
        return ZoneInfo(DEFAULT_DAILY_XP_TIMEZONE)


def get_xp_local_date():
    return timezone.now().astimezone(get_daily_xp_timezone()).date()


def get_daily_xp_status(profile) -> dict:
    limit = get_daily_xp_limit()
    local_date = get_xp_local_date()
    daily = DailyXP.objects.filter(profile_id=profile.pk, date=local_date).first()
    earned = daily.earned_xp if daily else 0
    remaining = max(limit - earned, 0)
    return {
        'daily_xp': earned,
        'daily_xp_limit': limit,
        'daily_xp_remaining': remaining,
        'daily_limit_reached': remaining <= 0,
        'daily_xp_date': local_date.isoformat(),
    }


@transaction.atomic
def award_xp(profile, requested_xp: int) -> XPAwardResult:
    """Единственная точка начисления XP.

    Даже если клиент повторит запрос или отправит собственное значение XP,
    фактически будет начислено не больше остатка дневного лимита.
    """
    try:
        requested = max(0, int(requested_xp))
    except (TypeError, ValueError):
        requested = 0

    limit = get_daily_xp_limit()
    local_date = get_xp_local_date()

    locked_profile = ChildProfile.objects.select_for_update().get(pk=profile.pk)

    daily, _ = DailyXP.objects.get_or_create(
        profile=locked_profile,
        date=local_date,
        defaults={'earned_xp': 0},
    )
    daily = DailyXP.objects.select_for_update().get(pk=daily.pk)

    remaining = max(limit - daily.earned_xp, 0)
    granted = min(requested, remaining)

    if granted > 0:
        daily.earned_xp += granted
        daily.save(update_fields=['earned_xp', 'updated_at'])

        locked_profile.total_xp += granted
        locked_profile.save(update_fields=['total_xp'])

    # Синхронизируем переданный объект, чтобы дальнейшие проверки достижений
    # в рамках того же запроса видели актуальный total_xp.
    profile.total_xp = locked_profile.total_xp

    remaining_after = max(limit - daily.earned_xp, 0)
    return XPAwardResult(
        requested_xp=requested,
        granted_xp=granted,
        daily_xp=daily.earned_xp,
        daily_xp_limit=limit,
        daily_xp_remaining=remaining_after,
        daily_limit_reached=remaining_after <= 0,
        date=local_date.isoformat(),
    )
