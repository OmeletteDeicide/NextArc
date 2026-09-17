import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nextarc/features/auth/data/user_profile_repository.dart';
import 'package:nextarc/features/auth/domain/profile_banner.dart';

/// Gère la mise à jour du profil Firebase + Firestore (pseudo + avatar).
class ProfileService {
  final _auth = fb.FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _profileRepo = UserProfileRepository();

  fb.User? get _user => _auth.currentUser;

  /// Met à jour le nom affiché (Firebase Auth + Firestore).
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    await _user?.updateDisplayName(trimmed);
    await _user?.reload();
    final uid = _user?.uid;
    if (uid != null) {
      await _profileRepo.updateProfileFields(uid: uid, displayName: trimmed);
    }
  }

  /// Upload une image dans Storage et met à jour photoURL (Firebase + Firestore).
  Future<String> updateAvatar(File imageFile) async {
    final uid = _user?.uid;
    if (uid == null) throw Exception('Non connecté');

    final ref = _storage.ref('avatars/$uid.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await task.ref.getDownloadURL();
    await _user?.updatePhotoURL(url);
    await _user?.reload();
    await _profileRepo.updateProfileFields(uid: uid, photoUrl: url);
    return url;
  }

  /// Enregistre la bannière : une image de l'appareil est d'abord envoyée
  /// dans Storage (banners/{uid}.jpg).
  Future<void> updateBanner({
    required BannerSource? source,
    String? url,
    String? label,
    File? file,
  }) async {
    final uid = _user?.uid;
    if (uid == null) throw Exception('Non connecté');

    var bannerUrl = url;
    if (source == BannerSource.device && file != null) {
      final task = await _storage.ref('banners/$uid.jpg').putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );
      bannerUrl = await task.ref.getDownloadURL();
    }
    await _profileRepo.updateBanner(
      uid: uid,
      source: source,
      url: source == BannerSource.cover || source == BannerSource.device
          ? bannerUrl
          : null,
      label: source == BannerSource.cover ? label : null,
    );
  }
}
