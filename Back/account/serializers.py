from rest_framework import serializers

from .models import (
    User,
    Avatar,
    ChildProfile,
    TariffPlan,
    Subscription,
)
from word_learning.models import Language, Level


class AvatarSerializer(serializers.ModelSerializer):
    class Meta:
        model = Avatar
        fields = ['id', 'title', 'image']


class ParentRegisterSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(
        required=True,
        error_messages={
            'blank': 'Введите email.',
            'required': 'Введите email.',
            'invalid': 'Введите корректный email.',
        },
    )
    first_name = serializers.CharField(
        min_length=2,
        max_length=128,
        error_messages={
            'blank': 'Введите имя родителя.',
            'required': 'Введите имя родителя.',
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
            'email',
            'first_name',
            'password',
            'password_confirm',
        ]
        read_only_fields = ['id']

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Родитель с таким email уже зарегистрирован.')
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError('Этот email уже используется.')
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
        email = validated_data['email'].lower()

        user = User(
            username=email,  # техническое поле, внешняя авторизация идёт по email
            email=email,
            first_name=validated_data['first_name'].strip(),
        )
        user.set_password(password)
        user.save()
        return user


class ParentLoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, required=True)

    def validate(self, attrs):
        email = attrs['email'].strip().lower()
        password = attrs['password']

        user = User.objects.filter(email__iexact=email).first()
        if not user or not user.check_password(password):
            raise serializers.ValidationError('Неверный email или пароль.')
        if not user.is_active:
            raise serializers.ValidationError('Аккаунт отключён.')

        attrs['user'] = user
        return attrs


class ParentSerializer(serializers.ModelSerializer):
    children_count = serializers.IntegerField(source='children.count', read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'email',
            'first_name',
            'children_count',
        ]


class ParentSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['first_name']

    def validate_first_name(self, value):
        value = value.strip()
        if len(value) < 2:
            raise serializers.ValidationError('Имя родителя должно содержать минимум 2 символа.')
        return value


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, required=True, min_length=6)
    new_password_confirm = serializers.CharField(write_only=True, required=True, min_length=6)

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


class ChildLanguageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Language
        fields = ['id', 'title', 'code', 'icon']


class ChildProfileSerializer(serializers.ModelSerializer):
    base_language = ChildLanguageSerializer(read_only=True)
    icon = AvatarSerializer(read_only=True)
    level = serializers.SerializerMethodField()

    class Meta:
        model = ChildProfile
        fields = [
            'id',
            'name',
            'base_language',
            'icon',
            'total_xp',
            'level',
            'is_active',
            'created_at',
            'updated_at',
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


class ChildProfileWriteSerializer(serializers.ModelSerializer):
    base_language = serializers.PrimaryKeyRelatedField(
        queryset=Language.objects.all(),
        required=True,
        error_messages={
            'required': 'Выберите базовый язык ребёнка.',
            'does_not_exist': 'Выбранный язык не найден.',
        },
    )
    icon = serializers.PrimaryKeyRelatedField(
        queryset=Avatar.objects.all(),
        required=True,
        error_messages={
            'required': 'Выберите аватар ребёнка.',
            'does_not_exist': 'Выбранный аватар не найден.',
        },
    )

    class Meta:
        model = ChildProfile
        fields = ['id', 'name', 'base_language', 'icon']
        read_only_fields = ['id']

    def validate_name(self, value):
        value = value.strip()
        if len(value) < 2:
            raise serializers.ValidationError('Имя ребёнка должно содержать минимум 2 символа.')
        return value


class TariffPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = TariffPlan
        fields = [
            'id',
            'code',
            'title',
            'description',
            'price',
            'currency',
            'duration_days',
            'max_children',
        ]


class SubscriptionSerializer(serializers.ModelSerializer):
    tariff = TariffPlanSerializer(read_only=True)
    is_current = serializers.BooleanField(read_only=True)

    class Meta:
        model = Subscription
        fields = [
            'id',
            'tariff',
            'status',
            'starts_at',
            'ends_at',
            'auto_renew',
            'payment_provider',
            'external_payment_id',
            'is_current',
            'created_at',
            'updated_at',
        ]


class SubscriptionCreateSerializer(serializers.Serializer):
    tariff = serializers.PrimaryKeyRelatedField(
        queryset=TariffPlan.objects.filter(is_active=True),
    )

    def validate(self, attrs):
        parent = self.context['request'].user
        if parent.subscriptions.filter(
            status__in=[Subscription.STATUS_PENDING, Subscription.STATUS_ACTIVE]
        ).exists():
            raise serializers.ValidationError(
                'У родителя уже есть активная подписка или подписка, ожидающая оплаты.'
            )
        tariff = attrs['tariff']
        children_count = parent.children.filter(is_active=True).count()
        if children_count > tariff.max_children:
            raise serializers.ValidationError(
                f'Тариф поддерживает максимум {tariff.max_children} профилей детей, '
                f'а у вас уже создано {children_count}.'
            )
        return attrs

    def create(self, validated_data):
        return Subscription.objects.create(
            parent=self.context['request'].user,
            tariff=validated_data['tariff'],
            status=Subscription.STATUS_PENDING,
        )
