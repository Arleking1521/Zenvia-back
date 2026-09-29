from django.contrib import admin
from django.shortcuts import get_object_or_404, render
from django.urls import path, reverse
from django.utils.html import format_html

from .models import LegalAcceptance, LegalDocumentVersion


@admin.register(LegalDocumentVersion)
class LegalDocumentVersionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'document_type',
        'version',
        'language',
        'status',
        'effective_from',
        'published_at',
        'preview_link',
    )
    list_filter = ('document_type', 'language', 'status', 'requires_reacceptance')
    search_fields = ('title', 'version', 'source_sha256')
    ordering = ('document_type', 'language', '-created_at')
    readonly_fields = (
        'source_sha256',
        'extracted_html',
        'extracted_text',
        'created_at',
        'published_at',
        'preview_link',
    )
    fieldsets = (
        ('Документ', {
            'fields': (
                'document_type', 'version', 'language', 'title', 'source_file',
            ),
        }),
        ('Публикация', {
            'fields': (
                'status', 'effective_from', 'requires_reacceptance',
                'published_at', 'preview_link',
            ),
        }),
        ('Проверка исходника', {
            'fields': ('source_sha256',),
        }),
        ('Автоматически извлечённое содержимое', {
            'fields': ('extracted_html', 'extracted_text'),
            'classes': ('collapse',),
        }),
        ('Служебное', {
            'fields': ('created_at',),
            'classes': ('collapse',),
        }),
    )

    def get_readonly_fields(self, request, obj=None):
        base = list(super().get_readonly_fields(request, obj))
        if obj and obj.status == LegalDocumentVersion.STATUS_PUBLISHED:
            return [
                'document_type', 'version', 'language', 'title', 'source_file',
                'status', 'effective_from', 'requires_reacceptance',
                'source_sha256', 'extracted_html', 'extracted_text',
                'created_at', 'published_at', 'preview_link',
            ]
        return base

    def get_urls(self):
        urls = super().get_urls()
        custom = [
            path(
                '<int:object_id>/preview/',
                self.admin_site.admin_view(self.preview_view),
                name='legal_documents_legaldocumentversion_preview',
            ),
        ]
        return custom + urls

    def preview_view(self, request, object_id):
        obj = get_object_or_404(LegalDocumentVersion, pk=object_id)
        return render(
            request,
            'legal_documents/document.html',
            {
                'document': obj,
                'fallback_title': obj.title,
                'is_admin_preview': True,
            },
        )

    @admin.display(description='Предпросмотр')
    def preview_link(self, obj):
        if obj is None or not obj.pk:
            return 'Сохраните черновик для предпросмотра'
        url = reverse('admin:legal_documents_legaldocumentversion_preview', args=[obj.pk])
        return format_html('<a href="{}" target="_blank">Открыть</a>', url)


@admin.register(LegalAcceptance)
class LegalAcceptanceAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'document', 'accepted_at', 'app_version')
    list_filter = ('document__document_type', 'document__language', 'document__version')
    search_fields = ('user__email', 'document__title', 'document__version')
    readonly_fields = ('user', 'document', 'accepted_at', 'app_version')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
