import '../models/achievement.dart';
import '../models/language.dart';
import '../models/topic.dart';

abstract class AppRepository {
  Future<List<Topic>> getTopics();
  Future<List<Achievement>> getAchievements();

  Future<AppLanguage> getSelectedLanguage();
  Future<void> setSelectedLanguage(AppLanguage lang);

  Future<int> getXp();
  Future<int> getLevel();
  Future<String> getChildName();
}
