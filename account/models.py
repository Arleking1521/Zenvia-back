# Models из приложения account
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils.translation import gettext_lazy as _
# Create your models here.

class Avatar(models.Model):
    title = models.CharField(max_length=128, verbose_name=_('Название'))
    image = models.ImageField(upload_to='profile_icons/')

    
    class Meta:
        verbose_name = 'Иконка профиля'
        verbose_name_plural = 'Иконки профилей'

    def __str__(self):
        return self.title

class User(AbstractUser):
    username = models.CharField(max_length=128, unique=True, verbose_name=_('Логин'))
    password = models.CharField(max_length=128, verbose_name=_('Пароль'))
    first_name = models.CharField(max_length=128, verbose_name=_('Имя ребенка'))
    base_language = models.ForeignKey('word_learning.Language', on_delete=models.SET_NULL, null=True, blank=True, verbose_name='Базовыйй язык')
    icon = models.ForeignKey(Avatar, on_delete=models.SET_NULL, blank=True, null=True)
    total_xp = models.PositiveIntegerField(default=0, verbose_name='Опыт')

    REQUIRED_FIELDS = ['first_name']

    def __str__(self):
        return f'{self.username} : {self.first_name}'


class UserLearningLanguage(models.Model):
    profile = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='learning_languages'
    )

    language = models.ForeignKey(
        'word_learning.Language',
        on_delete=models.CASCADE
    )

    is_active = models.BooleanField(
        default=True
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['profile', 'language'],
                name='unique_user_learning_language'
            )
        ]