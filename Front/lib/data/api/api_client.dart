import 'package:dio/dio.dart';

import 'api_config.dart';
import 'child_session_storage.dart';
import 'token_storage.dart';

class ApiClient {
  final TokenStorage tokenStorage;
  final ChildSessionStorage childSessionStorage;

  late final Dio dio;
  late final Dio _refreshDio;

  bool _refreshing = false;
  Future<bool>? _refreshFuture;

  ApiClient({
    TokenStorage? storage,
    ChildSessionStorage? childStorage,
  })  : tokenStorage = storage ?? const TokenStorage(),
        childSessionStorage = childStorage ?? ChildSessionStorage() {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    dio = Dio(options);
    _refreshDio = Dio(options);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await tokenStorage.readAccess();
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }

          final childId = await childSessionStorage.readSelectedChildId();
          if (childId != null && childId > 0) {
            options.headers['X-Child-Profile-ID'] = childId.toString();
          } else {
            options.headers.remove('X-Child-Profile-ID');
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401 ||
              error.requestOptions.extra['retried'] == true) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshToken();
          if (!refreshed) {
            handler.next(error);
            return;
          }

          final access = await tokenStorage.readAccess();
          final request = error.requestOptions;
          request.extra['retried'] = true;
          request.headers['Authorization'] = 'Bearer $access';

          try {
            final response = await dio.fetch(request);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    if (_refreshing && _refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshing = true;
    _refreshFuture = _doRefresh();

    try {
      return await _refreshFuture!;
    } finally {
      _refreshing = false;
      _refreshFuture = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = await tokenStorage.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiConfig.account('token/refresh/'),
        data: {'refresh': refresh},
      );

      final access = response.data?['access']?.toString();
      if (access == null || access.isEmpty) return false;

      await tokenStorage.saveAccess(access);
      return true;
    } on DioException {
      await tokenStorage.clear();
      await childSessionStorage.clear();
      return false;
    }
  }
}
