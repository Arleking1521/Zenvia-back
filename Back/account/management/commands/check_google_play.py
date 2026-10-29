from pathlib import Path
from urllib.parse import quote

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

from account.models import TariffPlan


_SCOPE = 'https://www.googleapis.com/auth/androidpublisher'
_TARGET_REGION = 'KZ'


class Command(BaseCommand):
    help = 'Проверяет локальную и, при --online, удалённую конфигурацию Google Play Billing.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--online',
            action='store_true',
            help='Дополнительно проверить доступ service account к Android Publisher API.',
        )

    def handle(self, *args, **options):
        errors = []
        package_name = (settings.GOOGLE_PLAY_PACKAGE_NAME or '').strip()
        credentials_file = (settings.GOOGLE_PLAY_SERVICE_ACCOUNT_FILE or '').strip()

        if not package_name:
            errors.append('GOOGLE_PLAY_PACKAGE_NAME пуст.')
        elif package_name != 'kz.zenvia.kids':
            errors.append(
                f'GOOGLE_PLAY_PACKAGE_NAME={package_name!r}; ожидалось "kz.zenvia.kids".'
            )
        else:
            self.stdout.write(self.style.SUCCESS(f'Package name: {package_name}'))

        path = Path(credentials_file) if credentials_file else None
        credentials = None
        if path is None:
            errors.append('GOOGLE_PLAY_SERVICE_ACCOUNT_FILE пуст.')
        elif not path.is_file():
            errors.append(f'Service account JSON не найден: {path}')
        else:
            try:
                credentials = service_account.Credentials.from_service_account_file(
                    str(path),
                    scopes=[_SCOPE],
                )
                self.stdout.write(
                    self.style.SUCCESS(
                        f'Service account JSON: OK ({credentials.service_account_email})'
                    )
                )
            except Exception as exc:
                errors.append(f'Не удалось прочитать service account JSON: {exc}')

        mappings = list(
            TariffPlan.objects.filter(
                is_active=True,
                google_play_enabled=True,
            ).order_by('position', 'id')
        )
        if not mappings:
            errors.append('Нет активных тарифов с google_play_enabled=True.')
        else:
            self.stdout.write('Активные Google Play тарифы:')
            for plan in mappings:
                product_id = (plan.google_product_id or '').strip()
                base_plan_id = (plan.google_base_plan_id or '').strip()
                self.stdout.write(
                    f'  - {plan.code}: {product_id or "<EMPTY>"} / '
                    f'{base_plan_id or "<EMPTY>"}'
                )
                if not product_id:
                    errors.append(f'{plan.code}: пустой Google Product ID.')
                if not base_plan_id:
                    errors.append(f'{plan.code}: пустой Google Base Plan ID.')

        if options['online'] and credentials is not None and package_name:
            session = AuthorizedSession(credentials)
            checked_products = {}

            for plan in mappings:
                product_id = (plan.google_product_id or '').strip()
                base_plan_id = (plan.google_base_plan_id or '').strip()
                if not product_id or not base_plan_id:
                    continue

                if product_id not in checked_products:
                    safe_product_id = quote(product_id, safe='')
                    url = (
                        'https://androidpublisher.googleapis.com/androidpublisher/v3/'
                        f'applications/{package_name}/subscriptions/{safe_product_id}'
                    )
                    try:
                        response = session.get(url, timeout=20)
                    except Exception as exc:
                        errors.append(
                            f'Android Publisher API недоступен для {product_id!r}: {exc}'
                        )
                        checked_products[product_id] = None
                        continue

                    content_type = response.headers.get('content-type', '')
                    if response.status_code >= 400:
                        body = (response.text or '').strip()
                        errors.append(
                            f'Android Publisher API для {product_id!r} вернул '
                            f'HTTP {response.status_code}: {body[:800] or "<empty body>"}'
                        )
                        checked_products[product_id] = None
                        continue

                    body = (response.text or '').strip()
                    if not body:
                        errors.append(
                            f'Android Publisher API для {product_id!r} вернул '
                            f'HTTP {response.status_code}, но тело ответа пустое '
                            f'(Content-Type: {content_type or "<missing>"}).'
                        )
                        checked_products[product_id] = None
                        continue

                    try:
                        payload = response.json()
                    except ValueError:
                        errors.append(
                            f'Android Publisher API для {product_id!r} вернул '
                            f'HTTP {response.status_code}, но не JSON '
                            f'(Content-Type: {content_type or "<missing>"}): {body[:800]}'
                        )
                        checked_products[product_id] = None
                        continue

                    checked_products[product_id] = payload
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Android Publisher API: OK ({product_id})'
                        )
                    )

                remote_sub = checked_products.get(product_id)
                if not remote_sub:
                    continue

                if remote_sub.get('productId') != product_id:
                    errors.append(
                        f'Google Play вернул неожиданный Product ID: '
                        f'{remote_sub.get("productId")!r} вместо {product_id!r}.'
                    )
                    continue

                base_plan = next(
                    (
                        item
                        for item in remote_sub.get('basePlans', [])
                        if item.get('basePlanId') == base_plan_id
                    ),
                    None,
                )
                if base_plan is None:
                    found_ids = sorted(
                        item.get('basePlanId')
                        for item in remote_sub.get('basePlans', [])
                        if item.get('basePlanId')
                    )
                    errors.append(
                        f'В {product_id!r} нет Base Plan {base_plan_id!r}; '
                        f'найдено: {found_ids}'
                    )
                    continue

                state = base_plan.get('state')
                if state != 'ACTIVE':
                    errors.append(
                        f'{product_id}/{base_plan_id}: Base Plan имеет статус '
                        f'{state!r}, ожидался "ACTIVE".'
                    )
                    continue

                kz_config = next(
                    (
                        item
                        for item in base_plan.get('regionalConfigs', [])
                        if item.get('regionCode') == _TARGET_REGION
                    ),
                    None,
                )
                if kz_config is None:
                    errors.append(
                        f'{product_id}/{base_plan_id}: нет regionalConfig для KZ.'
                    )
                    continue

                if not kz_config.get('newSubscriberAvailability', False):
                    errors.append(
                        f'{product_id}/{base_plan_id}: в KZ '
                        f'newSubscriberAvailability=false.'
                    )
                    continue

                price = kz_config.get('price') or {}
                units = price.get('units', '0')
                nanos = int(price.get('nanos', 0) or 0)
                currency = price.get('currencyCode', '')
                try:
                    price_value = int(units) + nanos / 1_000_000_000
                    price_text = f'{price_value:g} {currency}'.strip()
                except (TypeError, ValueError):
                    price_text = f'{units} {currency}'.strip()

                self.stdout.write(
                    self.style.SUCCESS(
                        f'Google Play mapping OK: {product_id}/{base_plan_id}; '
                        f'state=ACTIVE; KZ=available; price={price_text or "<unknown>"}'
                    )
                )

        if errors:
            for error in errors:
                self.stderr.write(self.style.ERROR(f'ERROR: {error}'))
            raise CommandError(
                'Google Play Billing настроен не полностью. Исправьте ошибки выше.'
            )

        self.stdout.write(self.style.SUCCESS('Google Play Billing configuration: OK'))
