import '../models/achievement.dart';
import '../models/dragon_evolution.dart';
import '../models/daily_lesson.dart';
import '../models/learned_word.dart';
import '../models/literary_content.dart';
import '../models/language.dart';
import '../models/topic.dart';

abstract class AppRepository {
  Future<List<Topic>> getTopics();
  Future<List<LanguageOption>> getAvailableLanguages();
  Future<List<Achievement>> getAchievements();
  Future<DailyLessonPlan> getDailyLesson({
    required Topic topic,
    required AppLanguage language,
  });
  Future<DailyLessonPlan> markDailyWordListened({
    required int lessonId,
    required String wordId,
  });

  Future<AppLanguage> getSelectedLanguage();
  Future<void> setSelectedLanguage(AppLanguage lang);

  Future<int> getXp();
  Future<int> getLevel();
  Future<String> getChildName();
  Future<String?> getLevelDragonUrl();
  Future<DragonEvolutionData> getDragonEvolution();
  Future<List<LearnedWord>> getLearnedWordsAllLanguages();
  Future<List<LiteraryContentItem>> getLiteraryContent(AppLanguage language);
  Future<void> markLiteraryContentListened(int contentId);
}
