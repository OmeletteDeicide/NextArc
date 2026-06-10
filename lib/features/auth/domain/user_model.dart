/// Modèle représentant l'utilisateur AniList connecté.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.avatarLarge,
    this.avatarMedium,
    this.bannerImage,
    this.siteUrl,
  });

  final int id;
  final String name;
  final String? avatarLarge;
  final String? avatarMedium;
  final String? bannerImage;
  final String? siteUrl;

  String? get avatar => avatarLarge ?? avatarMedium;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as Map<String, dynamic>?;
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarLarge: avatar?['large'] as String?,
      avatarMedium: avatar?['medium'] as String?,
      bannerImage: json['bannerImage'] as String?,
      siteUrl: json['siteUrl'] as String?,
    );
  }
}
