import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocaleController extends ChangeNotifier {
  static const supportedCodes = <String>{'ru', 'kk', 'en', 'zh'};

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  void useDeviceLocale() {
    setCode(PlatformDispatcher.instance.locale.languageCode);
  }

  void setCode(String? rawCode) {
    final code = normalizeCode(rawCode);
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
  }

  static String normalizeCode(String? rawCode) {
    final code = (rawCode ?? '').trim().toLowerCase();
    if (code == 'kz') return 'kk';
    if (code == 'cn') return 'zh';
    return supportedCodes.contains(code) ? code : 'ru';
  }
}

final appLocaleController = AppLocaleController();
