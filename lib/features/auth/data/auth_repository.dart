import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/core/constants/app_constants.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';

/// Clé de stockage du token dans flutter_secure_storage.
const _kTokenKey = 'anilist_access_token';

/// Requête GraphQL pour récupérer le profil de l'utilisateur connecté.
const _viewerQuery = '''
  query Viewer {
    Viewer {
      id
      name
      avatar {
        large
        medium
      }
      bannerImage
      siteUrl
    }
  }
''';

/// Repository gérant l'authentification AniList (OAuth2 flux implicite).
class AuthRepository {
  AuthRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // ── Login (Authorization Code flow) ─────────────────────────────────────

  /// Lance le flux OAuth AniList (Authorization Code) et retourne l'utilisateur.
  Future<UserModel> login() async {
    // Étape 1 : ouvre la page d'autorisation AniList (response_type=code)
    final authUri = Uri.https(
      'anilist.co',
      '/api/v2/oauth/authorize',
      {
        'client_id': AppConstants.anilistClientId,
        'redirect_uri': AppConstants.anilistRedirectUri,
        'response_type': 'code',
      },
    );
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'nextarc',
      );

      // Étape 2 : récupère le code d'autorisation depuis le callback
      final callbackUri = Uri.parse(result);
      final code = callbackUri.queryParameters['code'];

      if (code == null || code.isEmpty) {
        throw const AuthException('Code d\'autorisation non reçu.');
      }

      // Étape 3 : échange le code contre un access_token
      final token = await _exchangeCodeForToken(code);

      // Stocke le token de façon sécurisée
      await _storage.write(key: _kTokenKey, value: token);
      AnilistClient.setAuthToken(token);

      // Étape 4 : récupère le profil utilisateur
      return await _fetchViewer();
    } on AuthException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('CANCELED') || msg.contains('canceled')) {
        throw const AuthException('Connexion annulée.');
      }
      throw AuthException('Connexion échouée : $e');
    }
  }

  /// Échange le code d'autorisation contre un access_token via le proxy Firebase.
  Future<String> _exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://anilisttoken-qgwvvtarwa-ew.a.run.app'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'redirect_uri': AppConstants.anilistRedirectUri,
      }),
    );

    if (response.statusCode != 200) {
      throw AuthException('Échange token échoué (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;

    if (token == null || token.isEmpty) {
      throw const AuthException('Access token absent de la réponse.');
    }

    return token;
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.delete(key: _kTokenKey);
    AnilistClient.clearAuth();
  }

  // ── Restauration de session ──────────────────────────────────────────────

  /// Tente de restaurer la session depuis le token stocké.
  /// Retourne null si aucun token ou token invalide.
  Future<UserModel?> restoreSession() async {
    final token = await _storage.read(key: _kTokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      AnilistClient.setAuthToken(token);
      return await _fetchViewer();
    } on AuthException {
      // Erreur d'auth (401, profil introuvable) → token invalide, on nettoie
      await _storage.delete(key: _kTokenKey);
      AnilistClient.clearAuth();
      return null;
    } catch (_) {
      // Erreur réseau / timeout → on garde le token, l'utilisateur réessaiera
      AnilistClient.clearAuth();
      return null;
    }
  }

  // ── Requête Viewer ───────────────────────────────────────────────────────

  Future<UserModel> _fetchViewer() async {
    final result = await AnilistClient.instance.query(
      QueryOptions(document: gql(_viewerQuery)),
    );

    if (result.hasException) {
      throw AuthException(
        'Impossible de récupérer le profil : ${result.exception}',
      );
    }

    final data = result.data?['Viewer'] as Map<String, dynamic>?;
    if (data == null) throw const AuthException('Profil utilisateur introuvable.');

    return UserModel.fromJson(data);
  }
}

// ── Exception typée ───────────────────────────────────────────────────────────

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
