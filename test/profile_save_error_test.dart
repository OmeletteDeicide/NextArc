import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/auth/presentation/profile_edit_screen.dart';

void main() {
  FirebaseException storage(String code) =>
      FirebaseException(plugin: 'firebase_storage', code: code);

  test('stockage non activé (bucket absent) → message dédié', () {
    expect(profileSaveErrorKey(storage('object-not-found')),
        'profile_edit_error_storage');
    expect(profileSaveErrorKey(storage('bucket-not-found')),
        'profile_edit_error_storage');
  });

  test('refus des règles et réseau', () {
    expect(profileSaveErrorKey(storage('unauthorized')),
        'profile_edit_error_denied');
    expect(profileSaveErrorKey(storage('retry-limit-exceeded')),
        'profile_edit_error_network');
  });

  test('autre erreur → message générique, jamais le texte brut', () {
    expect(profileSaveErrorKey(Exception('boom')), 'auth_error_generic');
  });
}
