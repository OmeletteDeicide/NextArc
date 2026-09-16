import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

/// Document Firestore : users/{uid}
class FirestoreUserProfile {
  const FirestoreUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.anilistId,
    this.anilistName,
    this.anilistAvatar,
    this.customName,
    this.customPhoto,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;

  /// Pseudo / photo du compte NextArc (Google, e-mail ou choisis dans l'app).
  final String displayName;
  final String email;
  final String? photoUrl;

  // AniList (optionnel — null si non lié)
  final int? anilistId;
  final String? anilistName;
  final String? anilistAvatar;

  /// Pseudo / photo choisis dans NextArc (null = jamais renseigné : anciens
  /// documents).
  final bool? customName;
  final bool? customPhoto;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Pseudo choisi dans NextArc : AniList ne le remplace pas.
  bool get nameIsCustom => customName ?? false;

  /// Photo choisie dans NextArc. Anciens documents : une photo envoyée dans
  /// Firebase Storage ne peut venir que de l'écran d'édition du profil.
  bool get photoIsCustom => customPhoto ?? isUploadedPhoto(photoUrl);

  // ── Sérialisation ─────────────────────────────────────────────────────────

  /// L'uid n'est pas écrit : c'est l'id du document (règles Firestore).
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (anilistId != null) 'anilistId': anilistId,
        if (anilistName != null) 'anilistName': anilistName,
        if (anilistAvatar != null) 'anilistAvatar': anilistAvatar,
        if (customName != null) 'customName': customName,
        if (customPhoto != null) 'customPhoto': customPhoto,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory FirestoreUserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return FirestoreUserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      anilistId: map['anilistId'] as int?,
      anilistName: map['anilistName'] as String?,
      anilistAvatar: map['anilistAvatar'] as String?,
      customName: map['customName'] as bool?,
      customPhoto: map['customPhoto'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory FirestoreUserProfile.fromDocument(DocumentSnapshot doc) {
    return FirestoreUserProfile.fromMap(
        doc.id, doc.data() as Map<String, dynamic>);
  }

  // ── Conversion vers/depuis UserModel ──────────────────────────────────────

  factory FirestoreUserProfile.fromUserModel(UserModel user) {
    final now = DateTime.now();
    return FirestoreUserProfile(
      uid: user.firebaseUid!,
      displayName: user.accountName ?? user.displayName,
      email: user.email ?? '',
      photoUrl: user.accountPhoto ?? user.avatar,
      anilistId: user.hasAnilist ? user.id : null,
      anilistName: user.hasAnilist ? (user.anilistName ?? user.name) : null,
      customName: user.customName ? true : null,
      customPhoto: user.customPhoto ? true : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Utilisateur de l'app : identité NextArc, complétée par AniList selon
  /// les choix de l'utilisateur (voir [resolveIdentity]).
  UserModel toUserModel() {
    final identity = resolveIdentity(
      accountName: displayName,
      accountPhoto: photoUrl,
      anilistName: anilistName,
      anilistAvatar: anilistAvatar,
      customName: nameIsCustom,
      customPhoto: photoIsCustom,
    );
    return UserModel(
      firebaseUid: uid,
      email: email,
      id: anilistId ?? 0,
      name: identity.name,
      avatarLarge: identity.avatar,
      anilistName: anilistName,
      accountName: displayName,
      accountPhoto: photoUrl,
      customName: nameIsCustom,
      customPhoto: photoIsCustom,
    );
  }
}
