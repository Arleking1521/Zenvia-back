import logging

from django.core.management.base import BaseCommand

from account.google_play import (
    GooglePlayError,
    apply_google_subscription,
)
from account.models import Subscription

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = (
        'Синхронизирует локальные Google Play подписки с Android Publisher API. '
        'Предназначена для запуска по cron/systemd timer.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit',
            type=int,
            default=0,
            help='Ограничить количество подписок за один запуск (0 = без ограничения).',
        )
        parser.add_argument(
            '--parent-id',
            type=int,
            default=0,
            help='Синхронизировать подписки только указанного parent ID.',
        )

    def handle(self, *args, **options):
        queryset = (
            Subscription.objects
            .filter(payment_provider='google_play')
            .exclude(google_purchase_token__isnull=True)
            .exclude(google_purchase_token='')
            .exclude(status=Subscription.STATUS_EXPIRED)
            .select_related('parent', 'tariff')
            .order_by('id')
        )

        parent_id = options['parent_id']
        if parent_id:
            queryset = queryset.filter(parent_id=parent_id)

        limit = max(int(options['limit'] or 0), 0)
        if limit:
            queryset = queryset[:limit]

        total = 0
        updated = 0
        failed = 0

        for subscription in queryset.iterator() if not limit else queryset:
            total += 1
            old_status = subscription.status
            old_ends_at = subscription.ends_at
            old_auto_renew = subscription.auto_renew
            try:
                refreshed = apply_google_subscription(
                    subscription.parent,
                    subscription.google_purchase_token,
                    acknowledge=False,
                )
            except GooglePlayError as exc:
                failed += 1
                logger.exception(
                    'Google Play sync failed subscription=%s parent=%s',
                    subscription.pk,
                    subscription.parent_id,
                )
                self.stderr.write(
                    self.style.ERROR(
                        f'ERROR id={subscription.pk} parent={subscription.parent_id}: {exc}'
                    )
                )
                continue

            changed = (
                refreshed.status != old_status
                or refreshed.ends_at != old_ends_at
                or refreshed.auto_renew != old_auto_renew
            )
            if changed:
                updated += 1
                self.stdout.write(
                    self.style.SUCCESS(
                        'UPDATED '
                        f'id={refreshed.pk} parent={refreshed.parent_id} '
                        f'{old_status}->{refreshed.status} '
                        f'ends_at={refreshed.ends_at} auto_renew={refreshed.auto_renew}'
                    )
                )
            else:
                self.stdout.write(
                    f'OK id={refreshed.pk} parent={refreshed.parent_id} '
                    f'status={refreshed.status} ends_at={refreshed.ends_at}'
                )

        self.stdout.write(
            self.style.SUCCESS(
                f'Google Play sync complete: checked={total}, updated={updated}, failed={failed}'
            )
        )
