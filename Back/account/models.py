from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone
from django.utils.translation import gettext_lazy as _


class Avatar(models.Model):
    title = models.CharField(max_length=128, verbose_name=_('Название'))
    image = models.ImageField(upload_to='profile_icons/')

    class Meta:
        verbose_name = 'Иконка профиля'
        verbose_name_plural = 'Иконки профилей'

    def __str__(self):
        return self.title


class User(AbstractUser):
    """Родительский аккаунт.

    Авторизация во внешнем API выполняется по email + password. Поле username
    сохранено как техническое, чтобы не ломать существующую AUTH_USER_MODEL и
    старые миграции Django; для новых родителей в username записывается email.
    """

    username = models.CharField(max_length=128, unique=True, verbose_name=_('Технический логин'))
    password = models.CharField(max_length=128, verbose_name=_('Пароль'))
    email = models.EmailField(unique=True, verbose_name=_('Email'))
    first_name = models.CharField(max_length=128, verbose_name=_('Имя родителя'))
    parental_pin_hash = models.CharField(
        max_length=128,
        blank=True,
        default='',
        verbose_name=_('Хеш родительского PIN'),
    )

    REQUIRED_FIELDS = ['email', 'first_name']

    class Meta:
        verbose_name = 'Родитель'
        verbose_name_plural = 'Родители'

    def __str__(self):
        return f'{self.first_name} <{self.email}>'


class ChildProfile(models.Model):
    parent = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='children',
        verbose_name='Родитель',
    )
    name = models.CharField(max_length=128, verbose_name='Имя ребёнка')
    base_language = models.ForeignKey(
        'word_learning.Language',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='child_profiles',
        verbose_name='Базовый язык',
    )
    icon = models.ForeignKey(
        Avatar,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='child_profiles',
        verbose_name='Аватар',
    )
    total_xp = models.PositiveIntegerField(default=0, verbose_name='Опыт')
    is_active = models.BooleanField(default=True, verbose_name='Активный профиль')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создан')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Обновлён')

    class Meta:
        verbose_name = 'Профиль ребёнка'
        verbose_name_plural = 'Профили детей'
        ordering = ['id']

    def __str__(self):
        return f'{self.name} — {self.parent.email}'


class ChildLearningLanguage(models.Model):
    profile = models.ForeignKey(
        ChildProfile,
        on_delete=models.CASCADE,
        related_name='learning_languages',
        verbose_name='Профиль ребёнка',
    )
    language = models.ForeignKey(
        'word_learning.Language',
        on_delete=models.CASCADE,
        verbose_name='Изучаемый язык',
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Изучаемый язык ребёнка'
        verbose_name_plural = 'Изучаемые языки детей'
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'language'],
                name='unique_child_learning_language',
            )
        ]

    def __str__(self):
        return f'{self.profile.name}: {self.language.code}'


class TariffPlan(models.Model):
    code = models.SlugField(max_length=64, unique=True, verbose_name='Код')
    title = models.CharField(max_length=128, verbose_name='Название')
    description = models.TextField(blank=True, verbose_name='Описание')
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name='Цена')
    currency = models.CharField(max_length=8, default='KZT', verbose_name='Валюта')
    duration_days = models.PositiveIntegerField(default=30, verbose_name='Срок, дней')
    max_children = models.PositiveSmallIntegerField(default=1, verbose_name='Максимум профилей детей')
    is_active = models.BooleanField(default=True, verbose_name='Активен')
    position = models.PositiveIntegerField(default=0, verbose_name='Порядок')

    class Meta:
        verbose_name = 'Тариф'
        verbose_name_plural = 'Тарифы'
        ordering = ['position', 'id']

    def __str__(self):
        return self.title


class Subscription(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_ACTIVE = 'active'
    STATUS_EXPIRED = 'expired'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = (
        (STATUS_PENDING, 'Ожидает оплаты'),
        (STATUS_ACTIVE, 'Активна'),
        (STATUS_EXPIRED, 'Истекла'),
        (STATUS_CANCELLED, 'Отменена'),
    )

    parent = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='subscriptions',
        verbose_name='Родитель',
    )
    tariff = models.ForeignKey(
        TariffPlan,
        on_delete=models.PROTECT,
        related_name='subscriptions',
        verbose_name='Тариф',
    )
    status = models.CharField(
        max_length=16,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        verbose_name='Статус',
    )
    starts_at = models.DateTimeField(null=True, blank=True, verbose_name='Начало')
    ends_at = models.DateTimeField(null=True, blank=True, verbose_name='Окончание')
    auto_renew = models.BooleanField(default=False, verbose_name='Автопродление')
    payment_provider = models.CharField(max_length=64, blank=True, verbose_name='Платёжный провайдер')
    external_payment_id = models.CharField(max_length=128, blank=True, verbose_name='ID платежа у провайдера')
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создана')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Обновлена')

    class Meta:
        verbose_name = 'Подписка'
        verbose_name_plural = 'Подписки'
        ordering = ['-created_at']

    @property
    def is_current(self):
        if self.status != self.STATUS_ACTIVE:
            return False
        if self.starts_at and self.starts_at > timezone.now():
            return False
        if self.ends_at and self.ends_at <= timezone.now():
            return False
        return True

    def __str__(self):
        return f'{self.parent.email}: {self.tariff.title} ({self.status})'
