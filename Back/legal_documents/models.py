from __future__ import annotations

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import FileExtensionValidator
from django.db import models, transaction
from django.db.models import Q
from django.utils import timezone

from .services import extract_docx_payload


class LegalDocumentVersion(models.Model):
    TYPE_PRIVACY = 'privacy'
    TYPE_TERMS = 'terms'
    TYPE_CHOICES = (
        (TYPE_PRIVACY, 'Политика конфиденциальности'),
        (TYPE_TERMS, 'Условия использования'),
    )

    LANGUAGE_CHOICES = (
        ('ru', 'Русский'),
        ('kk', 'Қазақша'),
        ('en', 'English'),
        ('zh', '中文'),
    )

    STATUS_DRAFT = 'draft'
    STATUS_PUBLISHED = 'published'
    STATUS_ARCHIVED = 'archived'
    STATUS_CHOICES = (
        (STATUS_DRAFT, 'Черновик'),
        (STATUS_PUBLISHED, 'Опубликован'),
        (STATUS_ARCHIVED, 'Архив'),
    )

    document_type = models.CharField(
        max_length=20,
        choices=TYPE_CHOICES,
        verbose_name='Тип документа',
    )
    version = models.CharField(max_length=30, verbose_name='Версия')
    language = models.CharField(
        max_length=5,
        choices=LANGUAGE_CHOICES,
        default='ru',
        verbose_name='Язык',
    )
    title = models.CharField(max_length=255, verbose_name='Заголовок')
    source_file = models.FileField(
        upload_to='legal_documents/%Y/%m/',
        validators=[FileExtensionValidator(['docx'])],
        verbose_name='Исходный DOCX',
    )
    source_sha256 = models.CharField(
        max_length=64,
        blank=True,
        editable=False,
        verbose_name='SHA-256 исходного файла',
    )
    extracted_html = models.TextField(
        blank=True,
        editable=False,
        verbose_name='Извлечённый HTML',
    )
    extracted_text = models.TextField(
        blank=True,
        editable=False,
        verbose_name='Извлечённый текст',
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_DRAFT,
        verbose_name='Статус',
    )
    effective_from = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Действует с',
    )
    requires_reacceptance = models.BooleanField(
        default=False,
        verbose_name='Требует повторного согласия',
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создан')
    published_at = models.DateTimeField(
        null=True,
        blank=True,
        editable=False,
        verbose_name='Опубликован',
    )

    class Meta:
        verbose_name = 'Версия юридического документа'
        verbose_name_plural = 'Версии юридических документов'
        ordering = ['document_type', 'language', '-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['document_type', 'version', 'language'],
                name='legal_unique_type_version_language',
            ),
            models.UniqueConstraint(
                fields=['document_type', 'language'],
                condition=Q(status='published'),
                name='legal_one_published_per_type_language',
            ),
        ]

    def __str__(self):
        return f'{self.get_document_type_display()} {self.version} [{self.language}]'

    @property
    def is_effective(self) -> bool:
        return self.effective_from is None or self.effective_from <= timezone.now()

    def clean(self):
        super().clean()
        if self.status == self.STATUS_PUBLISHED and not self.source_file:
            raise ValidationError({'source_file': 'Для публикации требуется DOCX-файл.'})

        if self.pk:
            original = type(self).objects.filter(pk=self.pk).first()
            if original and original.status == self.STATUS_PUBLISHED:
                protected = (
                    'document_type', 'version', 'language', 'title',
                    'source_file', 'source_sha256', 'extracted_html',
                    'extracted_text', 'effective_from',
                    'requires_reacceptance',
                )
                changed = any(
                    getattr(original, field) != getattr(self, field)
                    for field in protected
                )
                if changed:
                    raise ValidationError(
                        'Опубликованную версию нельзя изменять. Создайте новую версию документа.'
                    )

    def _refresh_extracted_content(self):
        if not self.source_file:
            return
        html, text, sha256 = extract_docx_payload(self.source_file)
        self.extracted_html = html
        self.extracted_text = text
        self.source_sha256 = sha256

    def save(self, *args, **kwargs):
        file_is_new = bool(self.source_file) and (
            not getattr(self.source_file, '_committed', True)
            or not self.extracted_html
            or not self.source_sha256
        )
        if file_is_new:
            self._refresh_extracted_content()

        if self.status == self.STATUS_PUBLISHED and not self.published_at:
            self.published_at = timezone.now()

        with transaction.atomic():
            if self.status == self.STATUS_PUBLISHED:
                type(self).objects.filter(
                    document_type=self.document_type,
                    language=self.language,
                    status=self.STATUS_PUBLISHED,
                ).exclude(pk=self.pk).update(status=self.STATUS_ARCHIVED)
            super().save(*args, **kwargs)


class LegalAcceptance(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='legal_acceptances',
        verbose_name='Пользователь',
    )
    document = models.ForeignKey(
        LegalDocumentVersion,
        on_delete=models.PROTECT,
        related_name='acceptances',
        verbose_name='Документ',
    )
    accepted_at = models.DateTimeField(auto_now_add=True, verbose_name='Принято')
    app_version = models.CharField(
        max_length=30,
        blank=True,
        default='',
        verbose_name='Версия приложения',
    )

    class Meta:
        verbose_name = 'Согласие с юридическим документом'
        verbose_name_plural = 'Согласия с юридическими документами'
        ordering = ['-accepted_at']
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'document'],
                name='legal_unique_user_document_acceptance',
            ),
        ]

    def __str__(self):
        return f'{self.user} → {self.document}'
