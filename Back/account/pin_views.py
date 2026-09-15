from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from .pin_serializers import ParentPinSetSerializer, ParentPinVerifySerializer


class ParentPinVerifyThrottle(UserRateThrottle):
    # Ограничивает простой перебор PIN с одного родительского аккаунта.
    rate = '10/min'


class ParentPinView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({'has_pin': bool(request.user.parental_pin_hash)})

    def post(self, request):
        serializer = ParentPinSetSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            {
                'has_pin': True,
                'detail': 'Родительский PIN сохранён.',
            },
            status=status.HTTP_200_OK,
        )


class ParentPinVerifyView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ParentPinVerifyThrottle]

    def post(self, request):
        serializer = ParentPinVerifySerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        valid = serializer.is_valid_pin()
        return Response({'valid': valid}, status=status.HTTP_200_OK)
