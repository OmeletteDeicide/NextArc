import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Modèle utilisateur NextArc — Firebase (primaire) + AniList (optionnel).
class UserModel {
  const UserModel({
    this.firebaseUid,
    this.email,
    this.id = 0,
    this.name = '',
    this.avatarLarge,
    this.avatarMedium,
    this.bannerImage,
    this.siteUrl,
  });

  // ── Firebase ──────────────────────────────────────────────────────────────
  final String? firebaseUid;
  final String? email;

  // ── AniList (optionnel — 0 si non lié) ───────────────────────────────────
  final int id;
  final String name;
  final String? avatarLarge;
  final String? avatarMedium;
  final String? bannerImage;
  final String? siteUrl;

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get hasAnilist => id > 0;
  bool get hasFirebase => firebaseUid != null;

  /// Liste lue directement sur AniList : seulement pour un compte AniList sans
  /// compte NextArc. Dès qu'un compte NextArc existe, Firestore fait foi et la
  /// liste AniList y est fusionnée.
  bool get usesAnilistList => hasAnilist && !hasFirebase;

  /// Photo de profil : AniList d'abord, puis Firebase photoURL.
  String? get avatar => avatarLarge ?? avatarMedium;

  /// Nom affiché : AniList name, sinon partie locale de l'email.
  String get displayName =>
      name.isNotEmpty ? name : (email?.split('@').first ?? 'Utilisateur');

  // ── Factories ─────────────────────────────────────────────────────────────

  factory UserModel.fromAnilistJson(Map<String, dynamic> json) {
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

  factory UserModel.fromFirebase(fb.User user) {
    return UserModel(
      firebaseUid: user.uid,
      email: user.email,
      name: user.displayName ?? '',
      avatarLarge: user.photoURL,
    );
  }

  /// Copie en liant un compte AniList à cet utilisateur Firebase.
  UserModel withAnilist(Map<String, dynamic> json) {
    final avatar = json['avatar'] as Map<String, dynamic>?;
    return UserModel(
      firebaseUid: firebaseUid,
      email: email,
      id: json['id'] as int,
      name: json['name'] as String,
      avatarLarge: avatar?['large'] as String?,
      avatarMedium: avatar?['medium'] as String?,
      bannerImage: json['bannerImage'] as String?,
      siteUrl: json['siteUrl'] as String?,
    );
  }

  UserModel copyWith({
    String? firebaseUid,
    String? email,
    int? id,
    String? name,
    String? avatarLarge,
    String? avatarMedium,
    String? bannerImage,
    String? siteUrl,
  }) =>
      UserModel(
        firebaseUid: firebaseUid ?? this.firebaseUid,
        email: email ?? this.email,
        id: id ?? this.id,
        name: name ?? this.name,
        avatarLarge: avatarLarge ?? this.avatarLarge,
        avatarMedium: avatarMedium ?? this.avatarMedium,
        bannerImage: bannerImage ?? this.bannerImage,
        siteUrl: siteUrl ?? this.siteUrl,
      );
}
