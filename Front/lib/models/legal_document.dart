class LegalDocument {
  final int id;
  final String type;
  final String version;
  final String language;
  final String title;
  final String html;
  final String plainText;
  final DateTime? effectiveFrom;
  final DateTime? publishedAt;
  final bool requiresReacceptance;
  final String sourceSha256;
  final String? sourceFileUrl;

  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.language,
    required this.title,
    required this.html,
    required this.plainText,
    required this.effectiveFrom,
    required this.publishedAt,
    required this.requiresReacceptance,
    required this.sourceSha256,
    required this.sourceFileUrl,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: _asInt(json['id']),
      type: json['type']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      language: json['language']?.toString() ?? 'ru',
      title: json['title']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
      plainText: json['plain_text']?.toString() ?? '',
      effectiveFrom: DateTime.tryParse(json['effective_from']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      requiresReacceptance: json['requires_reacceptance'] == true,
      sourceSha256: json['source_sha256']?.toString() ?? '',
      sourceFileUrl: _nullableString(json['source_file_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'version': version,
        'language': language,
        'title': title,
        'html': html,
        'plain_text': plainText,
        'effective_from': effectiveFrom?.toIso8601String(),
        'published_at': publishedAt?.toIso8601String(),
        'requires_reacceptance': requiresReacceptance,
        'source_sha256': sourceSha256,
        'source_file_url': sourceFileUrl,
      };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }
}
