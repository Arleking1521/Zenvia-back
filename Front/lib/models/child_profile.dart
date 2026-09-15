class ChildLanguageInfo {
  final int id;
  final String title;
  final String code;
  final String? iconUrl;

  const ChildLanguageInfo({
    required this.id,
    required this.title,
    required this.code,
    this.iconUrl,
  });
}

class ChildAvatarInfo {
  final int id;
  final String title;
  final String? imageUrl;

  const ChildAvatarInfo({
    required this.id,
    required this.title,
    this.imageUrl,
  });
}

class ChildLevelInfo {
  final int number;
  final String title;
  final int xpRequired;

  const ChildLevelInfo({
    required this.number,
    required this.title,
    required this.xpRequired,
  });
}

class ChildProfile {
  final int id;
  final String name;
  final ChildLanguageInfo? baseLanguage;
  final ChildAvatarInfo? avatar;
  final int totalXp;
  final ChildLevelInfo? level;
  final bool isActive;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.baseLanguage,
    required this.avatar,
    required this.totalXp,
    required this.level,
    required this.isActive,
  });
}
