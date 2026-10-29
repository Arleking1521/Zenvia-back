import hashlib
import logging
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import quote

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

from .models import Subscription, TariffPlan

logger = logging.getLogger(__name__)
audit_logger = logging.getLogger('django.request')
_SCOPE = 'https://www.googleapis.com/auth/androidpublisher'


class GooglePlayError(Exception):
    pass


class GooglePlayConfigurationError(GooglePlayError):
    pass


class GooglePlayVerificationError(GooglePlayError):
    pass


def _authorized_session():
    credentials_file = (settings.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE or '').strip()
    if not credentials_file:
        raise GooglePlayConfigurationError(
            'GOOGLE_PLAY_SERVICE_ACCOUNT_FILE не настроен на сервере.'
        )
    path = Path(credentials_file)
    if not path.is_file():
        raise GooglePlayConfigurationError(
            'Файл service account Google Play не найден на сервере.'
        )
    credentials = service_account.Credentials.from_service_account_file(
        str(path),
        scopes=[_SCOPE],
    )
    return AuthorizedSession(credentials)


def _package_name():
    value = (settings.GOOGLE_PLAY_PACKAGE_NAME or '').strip()
    if not value:
        raise GooglePlayConfigurationError('GOOGLE_PLAY_PACKAGE_NAME не настроен.')
    return value


def _parse_time(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    except ValueError:
        return None


def _token_fp(token):
    return hashlib.sha256((token or '').encode('utf-8')).hexdigest()[:12]


def get_google_subscription(purchase_token):
    token = (purchase_token or '').strip()
    if not token:
        raise GooglePlayVerificationError('Пустой Google Play purchase token.')
    package = quote(_package_name(), safe='')
    encoded_token = quote(token, safe='')
    url = (
        'https://androidpublisher.googleapis.com/androidpublisher/v3/'
        f'applications/{package}/purchases/subscriptionsv2/tokens/{encoded_token}'
    )
    try:
        response = _authorized_session().get(url, timeout=20)
    except GooglePlayConfigurationError:
        raise
    except Exception as exc:
        logger.exception('Unable to contact Google Play Developer API')
        raise GooglePlayVerificationError(
            'Не удалось связаться с Google Play Developer API.'
        ) from exc
    if response.status_code >= 400:
        audit_logger.warning(
            'Google Play verification failed token=%s http=%s body=%s',
            _token_fp(token),
            response.status_code,
            response.text[:1000],
        )
        if response.status_code in {401, 403}:
            raise GooglePlayConfigurationError(
                'Service account не имеет доступа к Google Play Developer API '
                f'для приложения {_package_name()}. Проверьте API access и права '
                'на просмотр финансовых данных/заказов в Play Console.'
            )
        if response.status_code == 404:
            raise GooglePlayVerificationError(
                'Google Play не нашёл эту подписку. Проверьте package name, '
                'Product ID, Base Plan ID и тестовый аккаунт.'
            )
        raise GooglePlayVerificationError(
            'Google Play не подтвердил эту подписку.'
        )
    try:
        payload = response.json()
    except ValueError as exc:
        audit_logger.warning(
            'Google Play verification returned non-JSON token=%s http=%s body=%s',
            _token_fp(token),
            response.status_code,
            response.text[:1000],
        )
        raise GooglePlayVerificationError(
            'Google Play вернул некорректный ответ при проверке подписки.'
        ) from exc

    audit_logger.warning(
        'Google Play verification OK token=%s state=%s ack=%s region=%s lineItems=%s',
        _token_fp(token),
        payload.get('subscriptionState'),
        payload.get('acknowledgementState'),
        payload.get('regionCode'),
        [
            {
                'productId': item.get('productId'),
                'basePlanId': (item.get('offerDetails') or {}).get('basePlanId'),
                'offerId': (item.get('offerDetails') or {}).get('offerId'),
                'expiryTime': item.get('expiryTime'),
            }
            for item in (payload.get('lineItems') or [])
        ],
    )
    return payload


def _find_tariff_and_line_item(payload):
    candidates = []
    for line_item in payload.get('lineItems') or []:
        product_id = (line_item.get('productId') or '').strip()
        offer = line_item.get('offerDetails') or {}
        base_plan_id = (offer.get('basePlanId') or '').strip()
        if not product_id or not base_plan_id:
            continue
        tariff = TariffPlan.objects.filter(
            is_active=True,
            google_play_enabled=True,
            google_product_id=product_id,
            google_base_plan_id=base_plan_id,
        ).first()
        if tariff is None:
            continue
        expiry = _parse_time(line_item.get('expiryTime'))
        candidates.append((expiry or datetime.min.replace(tzinfo=UTC), tariff, line_item))

    if not candidates:
        actual = [
            {
                'productId': (item.get('productId') or '').strip(),
                'basePlanId': ((item.get('offerDetails') or {}).get('basePlanId') or '').strip(),
                'offerId': ((item.get('offerDetails') or {}).get('offerId') or '').strip(),
            }
            for item in (payload.get('lineItems') or [])
        ]
        configured = list(
            TariffPlan.objects.filter(is_active=True, google_play_enabled=True)
            .values('id', 'name', 'google_product_id', 'google_base_plan_id')
        )
        audit_logger.warning(
            'Google Play tariff mapping failed actual=%s configured=%s',
            actual,
            configured,
        )
        raise GooglePlayVerificationError(
            f'Не удалось сопоставить покупку Google Play с тарифом Zenvia. '
            f'Google вернул: {actual}. Проверьте Product ID и Base Plan ID.'
        )
    candidates.sort(key=lambda item: item[0], reverse=True)
    _, tariff, line_item = candidates[0]
    return tariff, line_item


def _local_status(remote_state, expiry):
    now = timezone.now()
    if remote_state in {
        'SUBSCRIPTION_STATE_ACTIVE',
        'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        'SUBSCRIPTION_STATE_CANCELED',
    } and (expiry is None or expiry > now):
        return Subscription.STATUS_ACTIVE
    if remote_state in {
        'SUBSCRIPTION_STATE_PENDING',
        'SUBSCRIPTION_STATE_PAUSED',
        'SUBSCRIPTION_STATE_ON_HOLD',
    }:
        return Subscription.STATUS_PENDING
    if remote_state == 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED':
        return Subscription.STATUS_CANCELLED
    return Subscription.STATUS_EXPIRED


def acknowledge_google_subscription(purchase_token, product_id):
    package = quote(_package_name(), safe='')
    product = quote(product_id, safe='')
    token = quote(purchase_token, safe='')
    url = (
        'https://androidpublisher.googleapis.com/androidpublisher/v3/'
        f'applications/{package}/purchases/subscriptions/{product}/tokens/{token}:acknowledge'
    )
    response = _authorized_session().post(url, json={}, timeout=20)
    # 409 can occur if another client has just acknowledged the same token.
    if response.status_code >= 400 and response.status_code != 409:
        logger.warning('Google Play acknowledge failed: %s %s', response.status_code, response.text[:500])
        raise GooglePlayVerificationError('Не удалось подтвердить покупку в Google Play.')


def cancel_google_subscription(purchase_token):
    package = quote(_package_name(), safe='')
    token = quote((purchase_token or '').strip(), safe='')
    url = (
        'https://androidpublisher.googleapis.com/androidpublisher/v3/'
        f'applications/{package}/purchases/subscriptionsv2/tokens/{token}:cancel'
    )
    body = {
        'cancellationContext': {
            'cancellationType': 'USER_REQUESTED_STOP_RENEWALS',
        }
    }
    response = _authorized_session().post(url, json=body, timeout=20)
    if response.status_code >= 400:
        logger.warning('Google Play cancel failed: %s %s', response.status_code, response.text[:500])
        raise GooglePlayVerificationError(
            'Google Play не смог отключить автопродление.'
        )


def apply_google_subscription(parent, purchase_token, *, acknowledge=True):
    token = (purchase_token or '').strip()
    payload = get_google_subscription(token)
    tariff, line_item = _find_tariff_and_line_item(payload)

    product_id = (line_item.get('productId') or '').strip()
    base_plan_id = ((line_item.get('offerDetails') or {}).get('basePlanId') or '').strip()
    order_id = (line_item.get('latestSuccessfulOrderId') or '').strip()
    expiry = _parse_time(line_item.get('expiryTime'))
    starts_at = _parse_time(payload.get('startTime'))
    remote_state = (payload.get('subscriptionState') or '').strip()
    auto_renew = bool((line_item.get('autoRenewingPlan') or {}).get('autoRenewEnabled'))
    local_status = _local_status(remote_state, expiry)

    with transaction.atomic():
        existing = (
            Subscription.objects.select_for_update()
            .filter(google_purchase_token=token)
            .first()
        )
        if existing is not None and existing.parent_id != parent.id:
            audit_logger.warning(
                'Google Play purchase token=%s already belongs to parent=%s, requested parent=%s',
                _token_fp(token),
                existing.parent_id,
                parent.id,
            )
            raise GooglePlayVerificationError(
                'Эта покупка Google Play уже привязана к другому аккаунту.'
            )
        subscription = existing or Subscription(parent=parent, tariff=tariff)
        subscription.tariff = tariff
        subscription.status = local_status
        subscription.starts_at = starts_at or subscription.starts_at
        subscription.ends_at = expiry
        subscription.auto_renew = auto_renew
        subscription.payment_provider = 'google_play'
        subscription.external_payment_id = order_id
        subscription.google_purchase_token = token
        subscription.google_product_id = product_id
        subscription.google_base_plan_id = base_plan_id
        subscription.google_order_id = order_id
        subscription.google_subscription_state = remote_state
        subscription.google_last_verified_at = timezone.now()
        subscription.save()
        audit_logger.warning(
            'Google Play subscription saved id=%s parent=%s token=%s product=%s basePlan=%s status=%s',
            subscription.pk, parent.id, _token_fp(token), product_id, base_plan_id, local_status,
        )

    if (
        acknowledge
        and payload.get('acknowledgementState') == 'ACKNOWLEDGEMENT_STATE_PENDING'
        and local_status == Subscription.STATUS_ACTIVE
    ):
        acknowledge_google_subscription(token, product_id)

    return subscription


def refresh_parent_google_subscription(parent, *, max_age_seconds=300):
    subscription = (
        Subscription.objects.filter(
            parent=parent,
            payment_provider='google_play',
            google_purchase_token__isnull=False,
        )
        .exclude(google_purchase_token='')
        .order_by('-created_at')
        .first()
    )
    if subscription is None:
        return None

    if subscription.google_last_verified_at:
        age = (timezone.now() - subscription.google_last_verified_at).total_seconds()
        if age < max_age_seconds:
            return subscription

    try:
        return apply_google_subscription(
            parent,
            subscription.google_purchase_token,
            acknowledge=False,
        )
    except GooglePlayError:
        logger.exception('Unable to refresh Google Play subscription for parent %s', parent.pk)
        return subscription
