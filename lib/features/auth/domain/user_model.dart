import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:nextarc/features/auth/domain/profile_banner.dart';

/// Photo envoyée depuis NextArc (Firebase Storage), donc choisie par
/// l'utilisateur — par opposition à la photo Google ou AniList.
bool isUploadedPhoto(String? url) =>
    url != null && url.contains('firebasestorage');

/// Pseudo et photo affichés pour un compte NextArc lié (ou non) à AniList :
/// ce que l'utilisateur a choisi sur NextArc passe toujours avant AniList ;
/// sinon AniList remplace le pseudo / la photo reçus de Google ou de l'e-mail.
({String name, String? avatar}) resolveIdentity({
  required String accountName,
  required String? accountPhoto,
  String? anilistName,
  String? anilistAvatar,
  required bool customName,
  required bool customPhoto,
}) {
  final useAnilistName =
      !customName && anilistName != null && anilistName.isNotEmpty;
  final useAnilistAvatar = !customPhoto && anilistAvatar != null;
  return (
    name: useAnilistName ? anilistName : accountName,
    avatar: useAnilistAvatar ? anilistAvatar : accountPhoto,
  );
}

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
    this.anilistName,
    this.accountName,
    this.accountPhoto,
    this.customName = false,
    this.customPhoto = false,
    this.bannerSource,
    this.bannerUrl,
    this.bannerLabel,
  });

  // ── Firebase ──────────────────────────────────────────────────────────────
  final String? firebaseUid;
  final String? email;

  // ── AniList (optionnel — 0 si non lié) ───────────────────────────────────
  final int id;

  /// Pseudo affiché (déjà résolu entre NextArc et AniList).
  final String name;

  /// Photo affichée (déjà résolue entre NextArc et AniList).
  final String? avatarLarge;
  final String? avatarMedium;
  final String? bannerImage;
  final String? siteUrl;

  /// Pseudo du compte AniList lié.
  final String? anilistName;

  // ── Identité propre au compte NextArc ────────────────────────────────────

  /// Pseudo / photo du compte NextArc (Google, e-mail ou choisis).
  final String? accountName;
  final String? accountPhoto;

  /// Pseudo / photo choisis par l'utilisateur dans NextArc : AniList ne les
  /// remplace pas.
  final bool customName;
  final bool customPhoto;

  /// Bannière choisie dans NextArc (null = automatique : AniList puis
  /// dégradé) et son libellé (« Cyberpunk: Edgerunners »).
  final BannerSource? bannerSource;
  final String? bannerUrl;
  final String? bannerLabel;

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get hasAnilist => id > 0;
  bool get hasFirebase => firebaseUid != null;

  /// Liste lue directement sur AniList : seulement pour un compte AniList sans
  /// compte NextArc. Dès qu'un compte NextArc existe, Firestore fait foi et la
  /// liste AniList y est fusionnée.
  bool get usesAnilistList => hasAnilist && !hasFirebase;

  /// Photo de profil affichée.
  String? get avatar => avatarLarge ?? avatarMedium;

  /// Bannière affichée sur le Profil (null = dégradé NextArc).
  String? get profileBanner => resolveBannerUrl(
        source: bannerSource,
        chosenUrl: bannerUrl,
        anilistBanner: bannerImage,
      );

  /// Nom affiché, sinon partie locale de l'email.
  String get displayName =>
      name.isNotEmpty ? name : (email?.split('@').first ?? 'Utilisateur');

  // ── Factories ─────────────────────────────────────────────────────────────

  factory UserModel.fromAnilistJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as Map<String, dynamic>?;
    final name = json['name'] as String;
    return UserModel(
      id: json['id'] as int,
      name: name,
      anilistName: name,
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
      accountName: user.displayName,
      accountPhoto: user.photoURL,
      customPhoto: isUploadedPhoto(user.photoURL),
    );
  }

  /// Lie le compte AniList [anilist] à ce compte NextArc, en respectant le
  /// pseudo et la photo choisis sur NextArc.
  UserModel linkedTo(UserModel anilist) {
    final identity = resolveIdentity(
      accountName: accountName ?? name,
      accountPhoto: accountPhoto ?? avatar,
      anilistName: anilist.anilistName ?? anilist.name,
      anilistAvatar: anilist.avatar,
      customName: customName,
      customPhoto: customPhoto,
    );
    return UserModel(
      firebaseUid: firebaseUid,
      email: email,
      id: anilist.id,
      name: identity.name,
      avatarLarge: identity.avatar,
      bannerImage: anilist.bannerImage,
      siteUrl: anilist.siteUrl,
      anilistName: anilist.anilistName ?? anilist.name,
      accountName: accountName,
      accountPhoto: accountPhoto,
      customName: customName,
      customPhoto: customPhoto,
      bannerSource: bannerSource,
      bannerUrl: bannerUrl,
      bannerLabel: bannerLabel,
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
    String? anilistName,
    String? accountName,
    String? accountPhoto,
    bool? customName,
    bool? customPhoto,
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
        anilistName: anilistName ?? this.anilistName,
        accountName: accountName ?? this.accountName,
        accountPhoto: accountPhoto ?? this.accountPhoto,
        customName: customName ?? this.customName,
        customPhoto: customPhoto ?? this.customPhoto,
        bannerSource: bannerSource,
        bannerUrl: bannerUrl,
        bannerLabel: bannerLabel,
      );
}
