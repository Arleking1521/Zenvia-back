from __future__ import annotations

from django.http import Http404
from django.shortcuts import render
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import LegalAcceptance, LegalDocumentVersion
from .serializers import LegalDocumentSerializer


SUPPORTED_LANGUAGES = {'ru', 'kk', 'en', 'zh'}


def _normalize_language(value: str | None) -> str:
    code = (value or '').lower().split('-')[0]
    return code if code in SUPPORTED_LANGUAGES else 'ru'


def get_published_document(document_type: str, language: str):
    now = timezone.now()
    base = LegalDocumentVersion.objects.filter(
        document_type=document_type,
        status=LegalDocumentVersion.STATUS_PUBLISHED,
    ).filter(
        models_effective_filter(now)
    )

    requested = base.filter(language=language).order_by('-published_at', '-id').first()
    if requested:
        return requested

    if language != 'ru':
        fallback = base.filter(language='ru').order_by('-published_at', '-id').first()
        if fallback:
            return fallback

    return base.order_by('-published_at', '-id').first()


def models_effective_filter(now):
    from django.db.models import Q
    return Q(effective_from__isnull=True) | Q(effective_from__lte=now)


class PublishedLegalDocumentView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    document_type = None

    def get(self, request):
        language = _normalize_language(request.query_params.get('lang'))
        document = get_published_document(self.document_type, language)
        if document is None:
            return Response(
                {
                    'code': 'legal_document_not_published',
                    'detail': 'Документ пока не опубликован.',
                    'type': self.document_type,
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(
            LegalDocumentSerializer(document, context={'request': request}).data
        )


class PrivacyDocumentView(PublishedLegalDocumentView):
    document_type = LegalDocumentVersion.TYPE_PRIVACY


class TermsDocumentView(PublishedLegalDocumentView):
    document_type = LegalDocumentVersion.TYPE_TERMS


class LegalStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        language = _normalize_language(
            request.query_params.get('lang')
            or getattr(request.user, 'interface_language', 'ru')
        )
        payload = {}
        for doc_type in (
            LegalDocumentVersion.TYPE_PRIVACY,
            LegalDocumentVersion.TYPE_TERMS,
        ):
            document = get_published_document(doc_type, language)
            if document is None:
                payload[doc_type] = None
                continue
            payload[doc_type] = {
                'id': document.id,
                'version': document.version,
                'language': document.language,
                'requires_reacceptance': document.requires_reacceptance,
                'accepted': LegalAcceptance.objects.filter(
                    user=request.user,
                    document=document,
                ).exists(),
            }
        return Response(payload)


class LegalAcceptView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            document_id = int(request.data.get('document_id'))
        except (TypeError, ValueError):
            return Response(
                {'detail': 'Укажите корректный document_id.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        document = LegalDocumentVersion.objects.filter(
            pk=document_id,
            status=LegalDocumentVersion.STATUS_PUBLISHED,
        ).first()
        if document is None or not document.is_effective:
            raise Http404

        acceptance, _ = LegalAcceptance.objects.get_or_create(
            user=request.user,
            document=document,
            defaults={
                'app_version': str(request.data.get('app_version') or '')[:30],
            },
        )
        return Response(
            {
                'accepted': True,
                'document_id': document.id,
                'accepted_at': acceptance.accepted_at,
            },
            status=status.HTTP_200_OK,
        )


def legal_document_page(request, document_type):
    language = _normalize_language(
        request.GET.get('lang') or getattr(request, 'LANGUAGE_CODE', 'ru')
    )
    document = get_published_document(document_type, language)
    title = dict(LegalDocumentVersion.TYPE_CHOICES).get(document_type, 'Документ')
    return render(
        request,
        'legal_documents/document.html',
        {
            'document': document,
            'fallback_title': title,
        },
        status=200,
    )
