import '../models/legal_document.dart';

abstract class LegalRepository {
  Future<LegalDocument> getDocument({
    required String type,
    required String language,
    bool forceRefresh = false,
  });
}

class LegalRepositoryException implements Exception {
  final String message;
  const LegalRepositoryException(this.message);

  @override
  String toString() => message;
}

class LegalDocumentNotPublishedException extends LegalRepositoryException {
  const LegalDocumentNotPublishedException()
      : super('Документ пока не опубликован.');
}
