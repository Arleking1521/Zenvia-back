import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String? iconUrl;
  final Color iconBg;
  final int current;
  final int target;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.iconUrl,
    required this.iconBg,
    required this.current,
    required this.target,
    required this.xpReward,
  });

  bool get isCompleted => current >= target;
  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
}
