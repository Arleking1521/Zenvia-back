import 'language.dart';

class LearnedWord {
  final int wordId;
  final int conceptId;
  final AppLanguage language;
  final String text;
  final String? transcription;
  final String? imageUrl;
  final String? audioUrl;

  const LearnedWord({
    required this.wordId,
    required this.conceptId,
    required this.language,
    required this.text,
    this.transcription,
    this.imageUrl,
    this.audioUrl,
  });
}
