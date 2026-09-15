class RegistrationLanguage {
  final int id;
  final String title;
  final String code;
  final String? iconUrl;

  const RegistrationLanguage({
    required this.id,
    required this.title,
    required this.code,
    this.iconUrl,
  });
}

class AvatarOption {
  final int id;
  final String title;
  final String? imageUrl;

  const AvatarOption({
    required this.id,
    required this.title,
    this.imageUrl,
  });
}
