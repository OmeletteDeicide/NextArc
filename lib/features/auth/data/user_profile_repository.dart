import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nextarc/core/models/firestore_user_profile.dart';
import 'package:nextarc/features/auth/domain/profile_banner.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

/// Gère le document Firestore users/{uid}.
class UserProfileRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── Lecture ───────────────────────────────────────────────────────────────

  Future<FirestoreUserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return FirestoreUserProfile.fromDocument(doc);
  }

  // ── Création / mise à jour ────────────────────────────────────────────────

  /// Crée le document si absent, sinon met à jour displayName/email/photoUrl.
  Future<FirestoreUserProfile> upsertProfile(UserModel user) async {
    if (user.firebaseUid == null) throw Exception('UID Firebase manquant');

    final ref = _users.doc(user.firebaseUid);
    final existing = await ref.get();

    if (!existing.exists) {
      // Première connexion — crée le document complet
      final profile = FirestoreUserProfile.fromUserModel(user);
      await ref.set(profile.toMap());
      return profile;
    }

    // Mise à jour partielle : on ne touche pas anilistId/createdAt
    final updates = <String, dynamic>{
      'displayName': user.accountName ?? user.displayName,
      'email': user.email,
      'photoUrl': user.accountPhoto ?? user.avatar,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await ref.update(updates);

    return FirestoreUserProfile.fromDocument(await ref.get());
  }

  /// Met à jour les infos AniList dans le profil Firestore.
  Future<void> linkAnilist({
    required String uid,
    required int anilistId,
    required String anilistName,
    String? anilistAvatar,
  }) async {
    await _users.doc(uid).update({
      'anilistId': anilistId,
      'anilistName': anilistName,
      'anilistAvatar': anilistAvatar,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retire la liaison AniList du profil.
  Future<void> unlinkAnilist(String uid) async {
    await _users.doc(uid).update({
      'anilistId': FieldValue.delete(),
      'anilistName': FieldValue.delete(),
      'anilistAvatar': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour le pseudo et/ou la photo depuis l'écran d'édition. Un pseudo
  /// ou une photo modifiés ici sont marqués « choisis » : AniList ne les
  /// remplacera plus.
  Future<void> updateProfileFields({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'displayName': displayName,
      'photoUrl': photoUrl,
      if (displayName != null) 'customName': true,
      if (photoUrl != null) 'customPhoto': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((_, v) => v == null);
    if (updates.length > 1) await _users.doc(uid).update(updates);
  }

  /// Enregistre la bannière choisie. [source] null = automatique (AniList
  /// puis dégradé) : les champs sont retirés.
  Future<void> updateBanner({
    required String uid,
    required BannerSource? source,
    String? url,
    String? label,
  }) async {
    await _users.doc(uid).update({
      'bannerSource': source?.value ?? FieldValue.delete(),
      'bannerUrl': url ?? FieldValue.delete(),
      'bannerLabel': label ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
