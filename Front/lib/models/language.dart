enum AppLanguage { english, chinese, kazakh, russian }

extension AppLanguageX on AppLanguage {
  String get apiCode {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.chinese:
        return 'zh';
      case AppLanguage.kazakh:
        return 'kk';
      case AppLanguage.russian:
        return 'ru';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chinese:
        return '中文';
      case AppLanguage.kazakh:
        return 'Қазақ тілі';
      case AppLanguage.russian:
        return 'Русский';
    }
  }

  String get subLabel {
    switch (this) {
      case AppLanguage.english:
        return 'Английский';
      case AppLanguage.chinese:
        return 'Китайский';
      case AppLanguage.kazakh:
        return 'Казахский';
      case AppLanguage.russian:
        return '';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AppLanguage.english:
        return '🇬🇧';
      case AppLanguage.chinese:
        return '🇨🇳';
      case AppLanguage.kazakh:
        return '🇰🇿';
      case AppLanguage.russian:
        return '🇷🇺';
    }
  }

  static AppLanguage fromApiCode(String? code) {
    switch (code) {
      case 'zh':
        return AppLanguage.chinese;
      case 'kk':
        return AppLanguage.kazakh;
      case 'ru':
        return AppLanguage.russian;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}
