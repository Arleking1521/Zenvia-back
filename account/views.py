from rest_framework import status
from rest_framework.generics import CreateAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ReadOnlyModelViewSet

from .models import User, Avatar
from .serializers import (
    RegisterSerializer,
    UserSerializer,
    AvatarSerializer,
    UserSettingsSerializer,
    ChangePasswordSerializer,
)


class RegisterView(CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(
            request.user,
            context={'request': request},
        )
        return Response(serializer.data)

    def patch(self, request):
        serializer = UserSettingsSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        # Возвращаем полный профиль, чтобы Flutter сразу обновил UI.
        response_serializer = UserSerializer(
            request.user,
            context={'request': request},
        )
        return Response(response_serializer.data)


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
    # Аватары нужны на экране регистрации, когда JWT ещё нет.
    permission_classes = [AllowAny]
