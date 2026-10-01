from datetime import timedelta
from uuid import uuid4

from django.db import transaction
from django.utils import timezone

from rest_framework import status
from rest_framework.decorators import action
from rest_framework.generics import CreateAPIView
from rest_framework.mixins import CreateModelMixin, ListModelMixin, RetrieveModelMixin
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet, ReadOnlyModelViewSet, GenericViewSet
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, Avatar, ChildProfile, TariffPlan, Subscription
from .services import (
    TRIAL_DEFAULT_DAYS,
    TRIAL_TARIFF_CODE,
    get_active_subscription,
    get_child_profile_access,
    get_subscription_access,
    get_trial_access,
)
from .fake_payments import fake_payments_enabled_for
from .serializers import (
    ParentRegisterSerializer,
    ParentLoginSerializer,
    ParentSerializer,
    ParentSettingsSerializer,
    ChangePasswordSerializer,
    DeleteAccountSerializer,
    AvatarSerializer,
    ChildProfileSerializer,
    ChildProfileWriteSerializer,
    TariffPlanSerializer,
    SubscriptionSerializer,
    SubscriptionCreateSerializer,
    PromoCodeValidateSerializer,
    FakePaymentPurchaseSerializer,
)


class RegisterView(CreateAPIView):
    queryset = User.objects.all()
    serializer_class = ParentRegisterSerializer
    permission_classes = [AllowAny]


class ParentLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ParentLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']

        refresh = RefreshToken.for_user(user)
        return Response({
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'parent': ParentSerializer(user, context={'request': request}).data,
        })


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            ParentSerializer(request.user, context={'request': request}).data
        )

    def patch(self, request):
        serializer = ParentSettingsSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            ParentSerializer(request.user, context={'request': request}).data
        )


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            {'detail': 'Пароль успешно изменён.'},
            status=status.HTTP_200_OK,
        )


class DeleteAccountView(APIView):
    """Безвозвратно удаляет родительский аккаунт и связанные данные.

    User является корнем пользовательских данных. Связанные ChildProfile,
    Subscription, PromoCodeUsage и LegalAcceptance используют CASCADE;
    учебные данные ребёнка, в свою очередь, каскадно удаляются вместе с
    ChildProfile. Общие справочники, тарифы, промокоды, языки, аватары и
    юридические документы не удаляются.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeleteAccountSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)

        # Берём строку пользователя под блокировку, чтобы параллельный запрос
        # не смог изменить связанные данные в момент удаления.
        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=request.user.pk)
            user.delete()

        return Response(
            {'detail': 'Аккаунт и связанные с ним данные удалены.'},
            status=status.HTTP_200_OK,
        )


class AvatarViewSet(ReadOnlyModelViewSet):
    queryset = Avatar.objects.all().order_by('id')
    serializer_class = AvatarSerializer
    permission_classes = [AllowAny]


class ChildProfileViewSet(ModelViewSet):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            ChildProfile.objects
            .filter(parent=self.request.user)
            .select_related('base_language', 'icon')
            .order_by('id')
        )

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update'):
            return ChildProfileWriteSerializer
        return ChildProfileSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Lock the parent row so two concurrent requests cannot exceed the
        # tariff's child-profile limit. The backend is the source of truth;
        # the Flutter-side disabled button is only UX.
        with transaction.atomic():
            parent = User.objects.select_for_update().get(pk=request.user.pk)
            access = get_child_profile_access(parent)
            if not access['can_create_child']:
                return Response(
                    {
                        'detail': access['reason'],
                        'child_access': access,
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )
            child = serializer.save(parent=parent)

        return Response(
            ChildProfileSerializer(child, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        child = self.get_object()
        serializer = self.get_serializer(child, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        child = serializer.save()
        return Response(
            ChildProfileSerializer(child, context={'request': request}).data
        )

    def destroy(self, request, *args, **kwargs):
        # Не удаляем учебную историю физически; профиль можно восстановить из БД.
        child = self.get_object()
        child.is_active = False
        child.save(update_fields=['is_active'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class TariffPlanViewSet(ReadOnlyModelViewSet):
    serializer_class = TariffPlanSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            TariffPlan.objects
            .filter(is_active=True, is_public=True)
            .order_by('position', 'id')
        )


class PromoCodeValidateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PromoCodeValidateSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        promo = serializer.validated_data['promo']

        return Response({
            'valid': True,
            'code': promo.code,
            'kindergarten': {
                'id': promo.kindergarten_id,
                'name': promo.kindergarten.name,
            },
            'tariff': TariffPlanSerializer(
                promo.tariff,
                context={'request': request},
            ).data,
        })


class SubscriptionViewSet(
    CreateModelMixin,
    ListModelMixin,
    RetrieveModelMixin,
    GenericViewSet,
):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            Subscription.objects
            .filter(parent=self.request.user)
            .select_related(
                'tariff',
                'promo_usage__promo_code__kindergarten',
            )
            .order_by('-created_at')
        )

    def get_serializer_class(self):
        if self.action == 'create':
            return SubscriptionCreateSerializer
        return SubscriptionSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        subscription = serializer.save()
        return Response(
            SubscriptionSerializer(subscription, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['post'], url_path='start-trial')
    @transaction.atomic
    def start_trial(self, request):
        # Lock the parent row so two simultaneous taps cannot create two trials.
        parent = User.objects.select_for_update().get(pk=request.user.pk)

        if Subscription.objects.filter(
            parent=parent,
            payment_provider='trial',
        ).exists():
            return Response(
                {'detail': 'Пробный период для этого аккаунта уже использован.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            get_active_subscription(parent) is not None
            or parent.subscriptions.filter(
                status=Subscription.STATUS_PENDING,
            ).exists()
        ):
            return Response(
                {
                    'detail': (
                        'Нельзя запустить пробный период, пока есть активная '
                        'подписка или подписка, ожидающая оплаты.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        tariff, _ = TariffPlan.objects.get_or_create(
            code=TRIAL_TARIFF_CODE,
            defaults={
                'title': 'Пробный период 7 дней',
                'description': 'Бесплатный пробный доступ без автопродления.',
                'price': '0.00',
                'currency': 'KZT',
                'duration_days': TRIAL_DEFAULT_DAYS,
                'max_children': 2,
                'is_active': True,
                'is_public': False,
                'position': 0,
            },
        )
        if not tariff.is_active:
            return Response(
                {'detail': 'Пробный период временно отключён.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        now = timezone.now()
        subscription = Subscription.objects.create(
            parent=parent,
            tariff=tariff,
            status=Subscription.STATUS_ACTIVE,
            starts_at=now,
            ends_at=now + timedelta(days=tariff.duration_days),
            auto_renew=False,
            payment_provider='trial',
            external_payment_id='',
        )

        return Response(
            SubscriptionSerializer(
                subscription,
                context={'request': request},
            ).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['post'], url_path='fake-purchase')
    def fake_purchase(self, request):
        if not fake_payments_enabled_for(request.user):
            return Response(
                {
                    'detail': (
                        'Тестовая оплата отключена или этот аккаунт не включён '
                        'в список тестировщиков.'
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = FakePaymentPurchaseSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        scenario = serializer.validated_data.get(
            'scenario',
            FakePaymentPurchaseSerializer.SCENARIO_SUCCESS,
        )

        if scenario == FakePaymentPurchaseSerializer.SCENARIO_DECLINED:
            return Response({
                'result': 'declined',
                'message': 'Тестовый банк отклонил платёж.',
                'subscription': None,
            })

        if scenario == FakePaymentPurchaseSerializer.SCENARIO_CANCELLED:
            return Response({
                'result': 'cancelled',
                'message': 'Пользователь отменил тестовую оплату.',
                'subscription': None,
            })

        if scenario == FakePaymentPurchaseSerializer.SCENARIO_NETWORK_ERROR:
            return Response(
                {
                    'result': 'network_error',
                    'detail': 'Имитация ошибки сети платёжного провайдера.',
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        subscription = serializer.save()
        subscription.payment_provider = 'fake'
        subscription.external_payment_id = f'FAKE-{uuid4().hex.upper()}'

        if scenario == FakePaymentPurchaseSerializer.SCENARIO_SUCCESS:
            now = timezone.now()
            subscription.status = Subscription.STATUS_ACTIVE
            subscription.starts_at = now
            subscription.ends_at = now + timedelta(
                days=subscription.tariff.duration_days,
            )
            result = 'success'
            message = 'Тестовая оплата успешно проведена.'
        else:
            # pending deliberately remains unpaid so the UI can be tested.
            subscription.status = Subscription.STATUS_PENDING
            result = 'pending'
            message = 'Тестовый платёж оставлен в ожидании.'

        subscription.save(update_fields=[
            'status',
            'starts_at',
            'ends_at',
            'payment_provider',
            'external_payment_id',
            'updated_at',
        ])

        return Response({
            'result': result,
            'message': message,
            'subscription': SubscriptionSerializer(
                subscription,
                context={'request': request},
            ).data,
        })

    @action(detail=False, methods=['post'], url_path='fake-reset')
    def fake_reset(self, request):
        if not fake_payments_enabled_for(request.user):
            return Response(
                {
                    'detail': (
                        'Тестовая оплата отключена или этот аккаунт не включён '
                        'в список тестировщиков.'
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        fake_subscriptions = Subscription.objects.filter(
            parent=request.user,
            payment_provider='fake',
        )
        deleted_count = fake_subscriptions.count()
        # PromoCodeUsage has CASCADE from Subscription, so test promo usage is
        # removed too and the same code can be tested again.
        fake_subscriptions.delete()

        return Response({
            'reset': True,
            'deleted_subscriptions': deleted_count,
        })

    @action(detail=False, methods=['get'], url_path='current')
    def current(self, request):
        subscriptions = self.get_queryset()
        current = next((item for item in subscriptions if item.is_current), None)
        if current is None:
            current = subscriptions.filter(status=Subscription.STATUS_PENDING).first()
        if current is None:
            return Response(None, status=status.HTTP_200_OK)
        return Response(
            SubscriptionSerializer(current, context={'request': request}).data
        )


class SubscriptionStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(get_subscription_access(request.user))


class DashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        children = (
            ChildProfile.objects
            .filter(parent=request.user, is_active=True)
            .select_related('base_language', 'icon')
            .order_by('id')
        )
        subscriptions = (
            Subscription.objects
            .filter(parent=request.user)
            .select_related('tariff')
            .order_by('-created_at')
        )
        current = next((item for item in subscriptions if item.is_current), None)
        if current is None:
            current = subscriptions.filter(status=Subscription.STATUS_PENDING).first()

        return Response({
            'parent': ParentSerializer(request.user, context={'request': request}).data,
            'children': ChildProfileSerializer(
                children,
                many=True,
                context={'request': request},
            ).data,
            'subscription': (
                SubscriptionSerializer(current, context={'request': request}).data
                if current else None
            ),
            'child_access': get_child_profile_access(request.user),
            'trial': get_trial_access(request.user),
        })
