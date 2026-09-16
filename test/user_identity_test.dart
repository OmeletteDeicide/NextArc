import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/core/models/firestore_user_profile.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

FirestoreUserProfile _profile({
  String displayName = 'Simon',
  String? photoUrl = 'https://lh3.googleusercontent.com/google.jpg',
  bool? customName,
  bool? customPhoto,
  bool linked = true,
}) =>
    FirestoreUserProfile(
      uid: 'uid',
      displayName: displayName,
      email: 'test@example.com',
      photoUrl: photoUrl,
      anilistId: linked ? 42 : null,
      anilistName: linked ? 'Braillard' : null,
      anilistAvatar: linked ? 'https://s4.anilist.co/avatar.png' : null,
      customName: customName,
      customPhoto: customPhoto,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('pseudo et photo', () {
    test('rien de choisi sur NextArc → pseudo et photo AniList', () {
      final user = _profile().toUserModel();
      expect(user.displayName, 'Braillard');
      expect(user.avatar, 'https://s4.anilist.co/avatar.png');
      expect(user.anilistName, 'Braillard');
    });

    test('pseudo et photo choisis sur NextArc → gardés malgré AniList', () {
      final user = _profile(
        displayName: 'Espiègle',
        photoUrl: 'https://firebasestorage.googleapis.com/avatars/uid.jpg',
        customName: true,
        customPhoto: true,
      ).toUserModel();
      expect(user.displayName, 'Espiègle');
      expect(user.avatar, contains('firebasestorage'));
      // L'AniList lié reste affiché dans la ligne AniList
      expect(user.anilistName, 'Braillard');
    });

    test('ancien profil : photo envoyée dans Storage = photo choisie', () {
      final user = _profile(
        photoUrl: 'https://firebasestorage.googleapis.com/avatars/uid.jpg',
      ).toUserModel();
      expect(user.avatar, contains('firebasestorage'));
      expect(user.displayName, 'Braillard');
    });

    test('AniList délié → retour au pseudo et à la photo du compte', () {
      final user = _profile(linked: false).toUserModel();
      expect(user.displayName, 'Simon');
      expect(user.avatar, contains('googleusercontent'));
      expect(user.hasAnilist, isFalse);
    });

    test('liaison en direct (linkedTo) respecte les mêmes règles', () {
      final anilist = UserModel.fromAnilistJson({
        'id': 42,
        'name': 'Braillard',
        'avatar': {'large': 'https://s4.anilist.co/avatar.png'},
      });
      final chosen = _profile(linked: false, customName: true, displayName: 'Espiègle')
          .toUserModel()
          .linkedTo(anilist);
      expect(chosen.displayName, 'Espiègle');
      expect(chosen.avatar, 'https://s4.anilist.co/avatar.png');
      expect(chosen.id, 42);
    });
  });
}
