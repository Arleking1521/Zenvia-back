# Generated manually for Zenvia Kids legal document infrastructure.
from django.conf import settings
from django.db import migrations, models
import django.core.validators
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='LegalDocumentVersion',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('document_type', models.CharField(choices=[('privacy', 'Политика конфиденциальности'), ('terms', 'Условия использования')], max_length=20, verbose_name='Тип документа')),
                ('version', models.CharField(max_length=30, verbose_name='Версия')),
                ('language', models.CharField(choices=[('ru', 'Русский'), ('kk', 'Қазақша'), ('en', 'English'), ('zh', '中文')], default='ru', max_length=5, verbose_name='Язык')),
                ('title', models.CharField(max_length=255, verbose_name='Заголовок')),
                ('source_file', models.FileField(upload_to='legal_documents/%Y/%m/', validators=[django.core.validators.FileExtensionValidator(['docx'])], verbose_name='Исходный DOCX')),
                ('source_sha256', models.CharField(blank=True, editable=False, max_length=64, verbose_name='SHA-256 исходного файла')),
                ('extracted_html', models.TextField(blank=True, editable=False, verbose_name='Извлечённый HTML')),
                ('extracted_text', models.TextField(blank=True, editable=False, verbose_name='Извлечённый текст')),
                ('status', models.CharField(choices=[('draft', 'Черновик'), ('published', 'Опубликован'), ('archived', 'Архив')], default='draft', max_length=20, verbose_name='Статус')),
                ('effective_from', models.DateTimeField(blank=True, null=True, verbose_name='Действует с')),
                ('requires_reacceptance', models.BooleanField(default=False, verbose_name='Требует повторного согласия')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='Создан')),
                ('published_at', models.DateTimeField(blank=True, editable=False, null=True, verbose_name='Опубликован')),
            ],
            options={
                'verbose_name': 'Версия юридического документа',
                'verbose_name_plural': 'Версии юридических документов',
                'ordering': ['document_type', 'language', '-created_at'],
            },
        ),
        migrations.CreateModel(
            name='LegalAcceptance',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('accepted_at', models.DateTimeField(auto_now_add=True, verbose_name='Принято')),
                ('app_version', models.CharField(blank=True, default='', max_length=30, verbose_name='Версия приложения')),
                ('document', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='acceptances', to='legal_documents.legaldocumentversion', verbose_name='Документ')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='legal_acceptances', to=settings.AUTH_USER_MODEL, verbose_name='Пользователь')),
            ],
            options={
                'verbose_name': 'Согласие с юридическим документом',
                'verbose_name_plural': 'Согласия с юридическими документами',
                'ordering': ['-accepted_at'],
            },
        ),
        migrations.AddConstraint(
            model_name='legaldocumentversion',
            constraint=models.UniqueConstraint(fields=('document_type', 'version', 'language'), name='legal_unique_type_version_language'),
        ),
        migrations.AddConstraint(
            model_name='legaldocumentversion',
            constraint=models.UniqueConstraint(condition=models.Q(('status', 'published')), fields=('document_type', 'language'), name='legal_one_published_per_type_language'),
        ),
        migrations.AddConstraint(
            model_name='legalacceptance',
            constraint=models.UniqueConstraint(fields=('user', 'document'), name='legal_unique_user_document_acceptance'),
        ),
    ]
