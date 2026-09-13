from rest_framework import serializers

from .models import User, Avatar
from word_learning.models import Level, Language


class AvatarSerializer(serializers.ModelSerializer):

    class Meta:
        model = Avatar
        fields = [
            'id',
            'title',
            'image',
        ]


class RegisterSerializer(serializers.ModelSerializer):
    username = serializers.CharField(
        min_length=3,
        max_length=128,
        error_messages={
            'blank': 'Введите логин.',
            'required': 'Введите логин.',
        },
    )
    first_name = serializers.CharField(
        min_length=2,
        max_length=128,
        error_messages={
            'blank': 'Введите имя ребёнка.',
            'required': 'Введите имя ребёнка.',
        },
    )
    base_language = serializers.PrimaryKeyRelatedField(
        queryset=Language.objects.all(),
        required=True,
        error_messages={
            'required': 'Выберите язык, который знает ребёнок.',
            'does_not_exist': 'Выбранный язык не найден.',
        },
    )
    icon = serializers.PrimaryKeyRelatedField(
        queryset=Avatar.objects.all(),
        required=True,
        error_messages={
            'required': 'Выберите аватар.',
            'does_not_exist': 'Выбранный аватар не найден.',
        },
    )
    password = serializers.CharField(
        write_only=True,
        min_length=6,
        error_messages={
            'blank': 'Введите пароль.',
            'required': 'Введите пароль.',
            'min_length': 'Пароль должен содержать минимум 6 символов.',
        },
    )
    password_confirm = serializers.CharField(
        write_only=True,
        min_length=6,
        error_messages={
            'blank': 'Подтвердите пароль.',
            'required': 'Подтвердите пароль.',
            'min_length': 'Пароль должен содержать минимум 6 символов.',
        },
    )

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'first_name',
            'base_language',
            'icon',
            'password',
            'password_confirm',
        ]

    def validate_username(self, value):
        value = value.strip()
        if ' ' in value:
            raise serializers.ValidationError('Логин не должен содержать пробелы.')
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Пользователь с таким логином уже существует.')
        return value

    def validate(self, attrs):
        if attrs.get('password') != attrs.get('password_confirm'):
            raise serializers.ValidationError({
                'password_confirm': 'Пароли не совпадают.'
            })
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')

        user = User(**validated_data)
        user.set_password(password)
        user.save()

        return user


class UserSerializer(serializers.ModelSerializer):
    icon = AvatarSerializer(read_only=True)
    level = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'first_name',
            'base_language',
            'icon',
            'total_xp',
            'level',
        ]

    def get_level(self, obj):
        level = (
            Level.objects
            .filter(xp_required__lte=obj.total_xp)
            .order_by('-xp_required')
            .first()
        )

        if not level:
            return None

        return {
            'number': level.number,
            'title': level.title,
            'xp_required': level.xp_required,
        }


class UserSettingsSerializer(serializers.ModelSerializer):
    """Настройки профиля, которые пользователь может менять из приложения."""

    base_language = serializers.PrimaryKeyRelatedField(
        queryset=Language.objects.all(),
        required=False,
        allow_null=False,
        error_messages={
            'does_not_exist': 'Выбранный язык не найден.',
            'null': 'Базовый язык не может быть пустым.',
        },
    )

    class Meta:
        model = User
        fields = ['base_language']


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(
        write_only=True,
        required=True,
        error_messages={
            'blank': 'Введите текущий пароль.',
            'required': 'Введите текущий пароль.',
        },
    )
    new_password = serializers.CharField(
        write_only=True,
        required=True,
        min_length=6,
        error_messages={
            'blank': 'Введите новый пароль.',
            'required': 'Введите новый пароль.',
            'min_length': 'Новый пароль должен содержать минимум 6 символов.',
        },
    )
    new_password_confirm = serializers.CharField(
        write_only=True,
        required=True,
        min_length=6,
        error_messages={
            'blank': 'Подтвердите новый пароль.',
            'required': 'Подтвердите новый пароль.',
            'min_length': 'Новый пароль должен содержать минимум 6 символов.',
        },
    )

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Текущий пароль указан неверно.')
        return value

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                'new_password_confirm': 'Новые пароли не совпадают.'
            })

        if attrs['old_password'] == attrs['new_password']:
            raise serializers.ValidationError({
                'new_password': 'Новый пароль должен отличаться от текущего.'
            })

        return attrs

    def save(self, **kwargs):
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save(update_fields=['password'])
        return user
