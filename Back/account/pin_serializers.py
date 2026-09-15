import re

from django.contrib.auth.hashers import check_password, make_password
from rest_framework import serializers


_PIN_RE = re.compile(r'^\d{4}$')


class ParentPinSetSerializer(serializers.Serializer):
    password = serializers.CharField(write_only=True, required=True)
    pin = serializers.CharField(write_only=True, required=True, min_length=4, max_length=4)
    pin_confirm = serializers.CharField(write_only=True, required=True, min_length=4, max_length=4)

    def validate_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Пароль родителя указан неверно.')
        return value

    def validate_pin(self, value):
        if not _PIN_RE.fullmatch(value):
            raise serializers.ValidationError('PIN должен состоять ровно из 4 цифр.')
        return value

    def validate(self, attrs):
        if attrs['pin'] != attrs['pin_confirm']:
            raise serializers.ValidationError({'pin_confirm': 'PIN-коды не совпадают.'})
        return attrs

    def save(self, **kwargs):
        user = self.context['request'].user
        user.parental_pin_hash = make_password(self.validated_data['pin'])
        user.save(update_fields=['parental_pin_hash'])
        return user


class ParentPinVerifySerializer(serializers.Serializer):
    pin = serializers.CharField(write_only=True, required=True, min_length=4, max_length=4)

    def validate_pin(self, value):
        if not _PIN_RE.fullmatch(value):
            raise serializers.ValidationError('Введите 4 цифры PIN-кода.')
        return value

    def is_valid_pin(self):
        user = self.context['request'].user
        stored = user.parental_pin_hash or ''
        if not stored:
            return False
        return check_password(self.validated_data['pin'], stored)
