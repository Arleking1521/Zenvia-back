from django.urls import path

from .models import LegalDocumentVersion
from .views import legal_document_page

app_name = 'legal_documents_web'

urlpatterns = [
    path(
        'privacy/',
        legal_document_page,
        {'document_type': LegalDocumentVersion.TYPE_PRIVACY},
        name='privacy',
    ),
    path(
        'terms/',
        legal_document_page,
        {'document_type': LegalDocumentVersion.TYPE_TERMS},
        name='terms',
    ),
]
