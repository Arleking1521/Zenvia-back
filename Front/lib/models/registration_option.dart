class RegistrationLanguage {
  final int id;
  final String title;
  final String code;
  final int position;
  final String? iconUrl;

  const RegistrationLanguage({
    required this.id,
    required this.title,
    required this.code,
    this.position = 0,
    this.iconUrl,
  });
}

class AvatarOption {
  final int id;
  final String title;
  final String? imageUrl;
  final String dragonColor;

  const AvatarOption({
    required this.id,
    required this.title,
    this.imageUrl,
    this.dragonColor = 'blue',
  });
}
