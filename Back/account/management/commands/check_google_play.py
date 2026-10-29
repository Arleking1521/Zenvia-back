from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

from account.models import TariffPlan


_SCOPE = 'https://www.googleapis.com/auth/androidpublisher'


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
            url = (
                'https://androidpublisher.googleapis.com/androidpublisher/v3/'
                f'applications/{package_name}/subscriptions?pageSize=100'
            )
            try:
                response = AuthorizedSession(credentials).get(url, timeout=20)
            except Exception as exc:
                errors.append(f'Android Publisher API недоступен: {exc}')
            else:
                if response.status_code >= 400:
                    errors.append(
                        'Android Publisher API вернул '
                        f'HTTP {response.status_code}: {response.text[:500]}'
                    )
                else:
                    payload = response.json()
                    remote = {
                        item.get('productId'): item
                        for item in payload.get('subscriptions', [])
                        if item.get('productId')
                    }
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'Android Publisher API: OK, подписок найдено: {len(remote)}'
                        )
                    )
                    for plan in mappings:
                        remote_sub = remote.get(plan.google_product_id)
                        if remote_sub is None:
                            errors.append(
                                f'Google Play не вернул Product ID {plan.google_product_id!r}.'
                            )
                            continue
                        base_plan_ids = {
                            item.get('basePlanId')
                            for item in remote_sub.get('basePlans', [])
                            if item.get('basePlanId')
                        }
                        if plan.google_base_plan_id not in base_plan_ids:
                            errors.append(
                                f'В {plan.google_product_id!r} нет Base Plan '
                                f'{plan.google_base_plan_id!r}; найдено: '
                                f'{sorted(base_plan_ids)}'
                            )
                        else:
                            self.stdout.write(
                                self.style.SUCCESS(
                                    f'Google Play mapping OK: '
                                    f'{plan.google_product_id}/{plan.google_base_plan_id}'
                                )
                            )

        if errors:
            for error in errors:
                self.stderr.write(self.style.ERROR(f'ERROR: {error}'))
            raise CommandError(
                'Google Play Billing настроен не полностью. Исправьте ошибки выше.'
            )

        self.stdout.write(self.style.SUCCESS('Google Play Billing configuration: OK'))
