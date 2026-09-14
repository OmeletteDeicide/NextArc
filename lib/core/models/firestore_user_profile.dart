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
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  // AniList (optionnel — null si non lié)
  final int? anilistId;
  final String? anilistName;
  final String? anilistAvatar;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Sérialisation ─────────────────────────────────────────────────────────

  /// L'uid n'est pas écrit : c'est l'id du document (règles Firestore).
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (anilistId != null) 'anilistId': anilistId,
        if (anilistName != null) 'anilistName': anilistName,
        if (anilistAvatar != null) 'anilistAvatar': anilistAvatar,
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
      displayName: user.displayName,
      email: user.email ?? '',
      photoUrl: user.avatar,
      anilistId: user.hasAnilist ? user.id : null,
      anilistName: user.hasAnilist ? user.name : null,
      anilistAvatar: user.hasAnilist ? user.avatarLarge : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Fusionne ce profil Firestore dans un UserModel (enrichit les données).
  UserModel toUserModel() => UserModel(
        firebaseUid: uid,
        email: email,
        id: anilistId ?? 0,
        name: anilistName ?? displayName,
        avatarLarge: anilistAvatar ?? photoUrl,
        avatarMedium: photoUrl,
      );

  FirestoreUserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    int? anilistId,
    String? anilistName,
    String? anilistAvatar,
  }) =>
      FirestoreUserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        anilistId: anilistId ?? this.anilistId,
        anilistName: anilistName ?? this.anilistName,
        anilistAvatar: anilistAvatar ?? this.anilistAvatar,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
