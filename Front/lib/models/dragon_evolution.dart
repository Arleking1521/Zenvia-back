class DragonLevel {
  final int id;
  final int number;
  final String title;
  final int xpRequired;
  final String? iconUrl;

  const DragonLevel({
    required this.id,
    required this.number,
    required this.title,
    required this.xpRequired,
    this.iconUrl,
  });
}

class DragonEvolutionData {
  final int totalXp;
  final DragonLevel? currentLevel;
  final DragonLevel? nextLevel;
  final int xpToNextLevel;
  final List<DragonLevel> levels;

  const DragonEvolutionData({
    required this.totalXp,
    required this.currentLevel,
    required this.nextLevel,
    required this.xpToNextLevel,
    required this.levels,
  });

  bool get isMaxLevel => nextLevel == null;

  int get xpEarnedInCurrentLevel {
    final current = currentLevel;
    if (current == null) return totalXp;
    return (totalXp - current.xpRequired).clamp(0, totalXp).toInt();
  }

  int get xpNeededForCurrentLevel {
    final current = currentLevel;
    final next = nextLevel;
    if (current == null || next == null) return 0;
    return (next.xpRequired - current.xpRequired).clamp(1, 1 << 30).toInt();
  }

  double get levelProgress {
    if (isMaxLevel) return 1.0;
    final needed = xpNeededForCurrentLevel;
    if (needed <= 0) return 0.0;
    return (xpEarnedInCurrentLevel / needed).clamp(0.0, 1.0).toDouble();
  }
}
