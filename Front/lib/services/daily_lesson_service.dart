import '../data/app_repository.dart';
import '../models/daily_lesson.dart';
import '../models/language.dart';
import '../models/topic.dart';

/// Thin wrapper over the backend-owned daily lesson state.
///
/// Selection, studied words, completion and the server date now live in Django,
/// so clearing SharedPreferences or changing the phone date cannot unlock games.
class DailyLessonService {
  static const int wordsPerDay = 5;

  final AppRepository repository;

  const DailyLessonService(this.repository);

  Future<DailyLessonPlan> loadPlan({
    required Topic topic,
    required AppLanguage language,
  }) {
    return repository.getDailyLesson(
      topic: topic,
      language: language,
    );
  }

  Future<DailyLessonPlan> markStudied({
    required Topic topic,
    required AppLanguage language,
    required String wordId,
    int? lessonId,
  }) async {
    final id = lessonId ??
        (await loadPlan(topic: topic, language: language)).lessonId;
    return repository.markDailyWordListened(
      lessonId: id,
      wordId: wordId,
    );
  }

  Future<bool> isComplete({
    required Topic topic,
    required AppLanguage language,
  }) async {
    final plan = await loadPlan(topic: topic, language: language);
    return plan.isComplete;
  }
}
