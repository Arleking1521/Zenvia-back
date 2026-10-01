import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/legal_document.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'legal_repository.dart';

class ApiLegalRepository implements LegalRepository {
  final ApiClient client;

  ApiLegalRepository(this.client);

  @override
  Future<LegalDocument> getDocument({
    required String type,
    required String language,
    bool forceRefresh = false,
  }) async {
    final normalizedType = type == 'terms' ? 'terms' : 'privacy';
    final normalizedLanguage = _normalizeLanguage(language);
    final cacheKey = 'legal_document_${normalizedType}_$normalizedLanguage';

    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        ApiConfig.legal('$normalizedType/'),
        queryParameters: {'lang': normalizedLanguage},
      );
      final data = response.data ?? const <String, dynamic>{};
      final document = LegalDocument.fromJson(data);
      if (document.id <= 0) {
        throw const LegalRepositoryException('Получен некорректный документ.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(document.toJson()));
      return document;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(cacheKey);
        throw const LegalDocumentNotPublishedException();
      }

      // При проблеме с сетью показываем последнюю успешно загруженную версию.
      final cached = await _readCached(cacheKey);
      if (cached != null) return cached;

      throw LegalRepositoryException(
        _message(e, 'Не удалось загрузить документ.'),
      );
    }
  }

  Future<LegalDocument?> _readCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return LegalDocument.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeLanguage(String value) {
    final code = value.toLowerCase().split('-').first;
    return const {'ru', 'kk', 'en', 'zh'}.contains(code) ? code : 'ru';
  }

  String _message(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail']?.toString();
      if (detail != null && detail.trim().isNotEmpty) return detail;
    }
    return fallback;
  }
}
