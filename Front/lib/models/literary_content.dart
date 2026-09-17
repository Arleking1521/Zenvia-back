import 'language.dart';

enum LiteraryContentType {
  poem,
  proverb,
  riddle,
  tongueTwister,
  other,
}

extension LiteraryContentTypeX on LiteraryContentType {
  String get title {
    switch (this) {
      case LiteraryContentType.poem:
        return 'Стихи';
      case LiteraryContentType.proverb:
        return 'Пословицы';
      case LiteraryContentType.riddle:
        return 'Загадки';
      case LiteraryContentType.tongueTwister:
        return 'Скороговорки';
      case LiteraryContentType.other:
        return 'Другое';
    }
  }

  String get emoji {
    switch (this) {
      case LiteraryContentType.poem:
        return '📜';
      case LiteraryContentType.proverb:
        return '💬';
      case LiteraryContentType.riddle:
        return '❓';
      case LiteraryContentType.tongueTwister:
        return '👅';
      case LiteraryContentType.other:
        return '✨';
    }
  }

  static LiteraryContentType fromApiCode(String? value) {
    switch (value) {
      case 'poem':
        return LiteraryContentType.poem;
      case 'proverb':
        return LiteraryContentType.proverb;
      case 'riddle':
        return LiteraryContentType.riddle;
      case 'tongue_twister':
        return LiteraryContentType.tongueTwister;
      default:
        return LiteraryContentType.other;
    }
  }
}

class LiteraryContentItem {
  final int id;
  final String title;
  final String text;
  final LiteraryContentType type;
  final AppLanguage language;
  final String? imageUrl;
  final String? audioUrl;
  final String? author;
  final String difficulty;

  const LiteraryContentItem({
    required this.id,
    required this.title,
    required this.text,
    required this.type,
    required this.language,
    required this.difficulty,
    this.imageUrl,
    this.audioUrl,
    this.author,
  });
}
