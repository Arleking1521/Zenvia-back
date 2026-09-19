import 'dart:math' as math;

import 'topic.dart';

class DailyLessonPlan {
  final int lessonId;
  final List<WordItem> words;
  final Set<String> studiedWordIds;
  final int requiredCount;
  final bool isComplete;
  final String? date;

  const DailyLessonPlan({
    required this.lessonId,
    required this.words,
    required this.studiedWordIds,
    required this.requiredCount,
    required this.isComplete,
    this.date,
  });

  int get studiedCount => math.min(studiedWordIds.length, requiredCount);

  bool isWordStudied(WordItem word) => studiedWordIds.contains(word.id);
}
