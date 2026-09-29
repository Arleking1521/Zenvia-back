from django.urls import path

from .views import LegalAcceptView, LegalStatusView, PrivacyDocumentView, TermsDocumentView

app_name = 'legal_documents_api'

urlpatterns = [
    path('privacy/', PrivacyDocumentView.as_view(), name='privacy'),
    path('terms/', TermsDocumentView.as_view(), name='terms'),
    path('status/', LegalStatusView.as_view(), name='status'),
    path('accept/', LegalAcceptView.as_view(), name='accept'),
]
