class ApiConfig {
  /// Для реального телефона укажи IP компьютера:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  ///
  /// Для production:
  /// flutter run --dart-define=API_BASE_URL=https://api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String accountPrefix = '/api/account';
  static const String apiPrefix = '/api';

  static String account(String path) => _join(accountPrefix, path);
  static String api(String path) => _join(apiPrefix, path);

  static String _join(String prefix, String path) {
    final cleanPrefix = prefix.endsWith('/')
        ? prefix.substring(0, prefix.length - 1)
        : prefix;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanPrefix/$cleanPath';
  }

  static String absoluteMediaUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = value.startsWith('/') ? value : '/$value';
    return '$base$path';
  }
}
