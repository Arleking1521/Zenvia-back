from rest_framework import serializers

from .models import LegalDocumentVersion


class LegalDocumentSerializer(serializers.ModelSerializer):
    type = serializers.CharField(source='document_type', read_only=True)
    html = serializers.CharField(source='extracted_html', read_only=True)
    plain_text = serializers.CharField(source='extracted_text', read_only=True)
    source_file_url = serializers.SerializerMethodField()

    class Meta:
        model = LegalDocumentVersion
        fields = (
            'id',
            'type',
            'version',
            'language',
            'title',
            'html',
            'plain_text',
            'effective_from',
            'published_at',
            'requires_reacceptance',
            'source_sha256',
            'source_file_url',
        )

    def get_source_file_url(self, obj):
        if not obj.source_file:
            return None
        request = self.context.get('request')
        url = obj.source_file.url
        return request.build_absolute_uri(url) if request else url
