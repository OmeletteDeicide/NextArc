import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;

/// Étapes de suppression exécutées par la Cloud Function `deleteAccount`.
enum DeletionServerStep {
  /// users/{uid} et ses sous-collections (liste, notes, journal).
  data,

  /// Photo / bannière puis compte Firebase Auth (à faire en dernier).
  account,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'AccountDeletionException($statusCode)';
}

/// Appelle la Cloud Function de suppression avec le jeton du compte connecté.
class AccountDeletionService {
  static final _endpoint = Uri.parse(
    'https://europe-west1-nextarc-fdbde.cloudfunctions.net/deleteAccount',
  );

  Future<void> run(DeletionServerStep step) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) throw const AccountDeletionException(401);

    final token = await user.getIdToken(true);
    final response = await http
        .post(
          _endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'step': step.name}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw AccountDeletionException(response.statusCode);
    }
  }
}

/// La saisie de confirmation correspond exactement au mot attendu
/// (majuscules comprises, espaces autour tolérés).
bool deletionConfirmationMatches(String input, String word) =>
    input.trim() == word;
