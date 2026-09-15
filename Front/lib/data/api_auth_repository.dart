import 'package:dio/dio.dart';

import '../models/parent_account.dart';
import 'api/api_client.dart';
import 'api/api_config.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient client;

  ApiAuthRepository(this.client);

  @override
  Future<bool> isLoggedIn() async {
    final access = await client.tokenStorage.readAccess();
    final refresh = await client.tokenStorage.readRefresh();

    if ((access == null || access.isEmpty) &&
        (refresh == null || refresh.isEmpty)) {
      return false;
    }

    try {
      await client.dio.get(ApiConfig.account('me/'));
      return true;
    } on DioException {
      return false;
    }
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        ApiConfig.account('login/'),
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final access = response.data?['access']?.toString();
      final refresh = response.data?['refresh']?.toString();

      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        throw const AuthException('Сервер не вернул JWT-токены.');
      }

      await client.tokenStorage.save(access: access, refresh: refresh);
      await client.childSessionStorage.clear();
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(_messageFromDio(e, fallback: 'Не удалось войти.'));
    }
  }

  @override
  Future<void> register({
    required String parentName,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await client.dio.post(
        ApiConfig.account('register/'),
        data: {
          'first_name': parentName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'password_confirm': passwordConfirm,
        },
      );

      await login(email: email, password: password);
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(
        _messageFromDio(e, fallback: 'Не удалось зарегистрироваться.'),
      );
    }
  }

  @override
  Future<ParentAccount> getParent() async {
    try {
      final response = await client.dio.get<Map<String, dynamic>>(
        ApiConfig.account('me/'),
      );
      return _parent(response.data ?? const {});
    } on DioException catch (e) {
      throw AuthException(
        _messageFromDio(e, fallback: 'Не удалось загрузить профиль родителя.'),
      );
    }
  }

  @override
  Future<ParentAccount> updateParentName(String firstName) async {
    try {
      final response = await client.dio.patch<Map<String, dynamic>>(
        ApiConfig.account('me/'),
        data: {'first_name': firstName.trim()},
      );
      return _parent(response.data ?? const {});
    } on DioException catch (e) {
      throw AuthException(
        _messageFromDio(e, fallback: 'Не удалось изменить имя.'),
      );
    }
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      await client.dio.post(
        ApiConfig.account('change-password/'),
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
      );
    } on DioException catch (e) {
      throw AuthException(
        _messageFromDio(e, fallback: 'Не удалось изменить пароль.'),
      );
    }
  }

  @override
  Future<void> logout() async {
    await client.tokenStorage.clear();
    await client.childSessionStorage.clear();
  }

  ParentAccount _parent(Map<String, dynamic> row) {
    return ParentAccount(
      id: _asInt(row['id']),
      email: row['email']?.toString() ?? '',
      firstName: row['first_name']?.toString() ?? '',
      childrenCount: _asInt(row['children_count']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _messageFromDio(
    DioException error, {
    required String fallback,
  }) {
    final data = error.response?.data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) return detail.first.toString();

      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }

      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
        if (value is Map) {
          for (final nested in value.values) {
            if (nested is List && nested.isNotEmpty) {
              return nested.first.toString();
            }
            if (nested is String && nested.isNotEmpty) return nested;
          }
        }
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Нет соединения с сервером. Проверь IP компьютера, Wi-Fi и firewall.';
    }

    return fallback;
  }
}
