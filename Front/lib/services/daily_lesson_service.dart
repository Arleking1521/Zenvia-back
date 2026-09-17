import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/language.dart';
import '../models/topic.dart';

class DailyLessonPlan {
  final List<WordItem> words;
  final Set<String> studiedWordIds;
  final int requiredCount;
  final bool isComplete;

  const DailyLessonPlan({
    required this.words,
    required this.studiedWordIds,
    required this.requiredCount,
    required this.isComplete,
  });

  int get studiedCount => math.min(studiedWordIds.length, requiredCount);

  bool isWordStudied(WordItem word) => studiedWordIds.contains(word.id);
}

/// Локальное состояние ежедневного знакомства со словами.
///
/// Храним отдельно для профиля ребёнка + языка + темы + даты.
/// Поэтому незавершённый набор из 5 слов не меняется при повторном входе
/// в тему в течение дня.
class DailyLessonService {
  static const int wordsPerDay = 5;
  static const String _selectedChildKey = 'selected_child_profile_id';
  static const String _version = 'v1';

  Future<DailyLessonPlan> loadPlan({
    required Topic topic,
    required AppLanguage language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getInt(_selectedChildKey) ?? 0;
    final date = _dateKey(DateTime.now());
    final base = 'daily_lesson_${_version}_${childId}_${language.apiCode}_${topic.id}';
    final selectionKey = '${base}_selection_$date';
    final studiedKey = '${base}_studied_$date';
    final completeKey = '${base}_complete_$date';
    final introducedKey = '${base}_introduced';

    final byId = <String, WordItem>{for (final word in topic.words) word.id: word};
    var selectedIds = prefs.getStringList(selectionKey) ?? <String>[];
    selectedIds = selectedIds.where(byId.containsKey).toList();

    if (selectedIds.isEmpty && topic.words.isNotEmpty) {
      final introduced = (prefs.getStringList(introducedKey) ?? <String>[]).toSet();
      final newWords = topic.words.where((word) => !introduced.contains(word.id)).toList();
      final count = math.min(wordsPerDay, newWords.length);
      selectedIds = newWords.take(count).map((word) => word.id).toList();
      await prefs.setStringList(selectionKey, selectedIds);
    }

    final selectedWords = selectedIds.map((id) => byId[id]).whereType<WordItem>().toList();
    final requiredCount = math.min(wordsPerDay, selectedWords.length);
    final studied = (prefs.getStringList(studiedKey) ?? <String>[])
        .where(selectedIds.contains)
        .toSet();

    var complete = prefs.getBool(completeKey) == true;
    if (requiredCount == 0 || studied.length >= requiredCount) {
      complete = true;
      if (prefs.getBool(completeKey) != true) {
        await _complete(
          prefs: prefs,
          completeKey: completeKey,
          introducedKey: introducedKey,
          selectedIds: selectedIds,
        );
      }
    }

    return DailyLessonPlan(
      words: selectedWords,
      studiedWordIds: studied,
      requiredCount: requiredCount,
      isComplete: complete,
    );
  }

  Future<DailyLessonPlan> markStudied({
    required Topic topic,
    required AppLanguage language,
    required String wordId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getInt(_selectedChildKey) ?? 0;
    final date = _dateKey(DateTime.now());
    final base = 'daily_lesson_${_version}_${childId}_${language.apiCode}_${topic.id}';
    final selectionKey = '${base}_selection_$date';
    final studiedKey = '${base}_studied_$date';
    final completeKey = '${base}_complete_$date';
    final introducedKey = '${base}_introduced';

    final selectedIds = prefs.getStringList(selectionKey) ?? <String>[];
    if (selectedIds.contains(wordId)) {
      final studied = (prefs.getStringList(studiedKey) ?? <String>[]).toSet();
      studied.add(wordId);
      await prefs.setStringList(studiedKey, studied.toList());

      final required = math.min(wordsPerDay, selectedIds.length);
      if (required == 0 || studied.where(selectedIds.contains).length >= required) {
        await _complete(
          prefs: prefs,
          completeKey: completeKey,
          introducedKey: introducedKey,
          selectedIds: selectedIds,
        );
      }
    }

    return loadPlan(topic: topic, language: language);
  }

  Future<bool> isComplete({
    required Topic topic,
    required AppLanguage language,
  }) async {
    final plan = await loadPlan(topic: topic, language: language);
    return plan.isComplete;
  }

  Future<void> _complete({
    required SharedPreferences prefs,
    required String completeKey,
    required String introducedKey,
    required List<String> selectedIds,
  }) async {
    await prefs.setBool(completeKey, true);
    final introduced = (prefs.getStringList(introducedKey) ?? <String>[]).toSet();
    introduced.addAll(selectedIds);
    await prefs.setStringList(introducedKey, introduced.toList());
  }

  String _dateKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
