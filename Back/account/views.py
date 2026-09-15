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
from .serializers import (
    ParentRegisterSerializer,
    ParentLoginSerializer,
    ParentSerializer,
    ParentSettingsSerializer,
    ChangePasswordSerializer,
    AvatarSerializer,
    ChildProfileSerializer,
    ChildProfileWriteSerializer,
    TariffPlanSerializer,
    SubscriptionSerializer,
    SubscriptionCreateSerializer,
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
        child = serializer.save(parent=request.user)
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
        return TariffPlan.objects.filter(is_active=True).order_by('position', 'id')


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
            .select_related('tariff')
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
        })
