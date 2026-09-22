import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

/// Service Firebase Auth — email/password, Google et Apple (iOS).
class FirebaseAuthService {
  final _auth = fb.FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  fb.User? get currentUser => _auth.currentUser;

  Future<fb.User> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user!;
  }

  Future<fb.User> createAccount(
    String email,
    String password,
    String displayName,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
      await cred.user!.reload();
    }
    return _auth.currentUser!;
  }

  Future<fb.User> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw fb.FirebaseAuthException(
        code: 'canceled',
        message: 'Connexion Google annulée.',
      );
    }
    final googleAuth = await account.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  /// Envoie le lien « Mot de passe oublié » dans la langue de l'app. Ne dit
  /// jamais si l'adresse a un compte (protection contre l'énumération).
  Future<void> sendPasswordReset(String email, {String? languageCode}) async {
    if (languageCode != null) await _auth.setLanguageCode(languageCode);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') rethrow;
    }
  }

  /// Sign in with Apple (feuille native iOS). Apple ne transmet le nom qu'à la
  /// toute première connexion : le pseudo se choisit ensuite dans le profil.
  Future<fb.User> signInWithApple() async {
    final cred = await _auth.signInWithProvider(_appleProvider());
    return cred.user!;
  }

  /// Exigé par Apple avant de supprimer un compte : révoque l'accès « Se
  /// connecter avec Apple ». Demande une nouvelle validation (Face ID) pour
  /// obtenir un code d'autorisation. Sans effet si Apple n'est pas lié.
  /// Relance l'annulation de l'utilisateur ; les autres erreurs (révocation
  /// non configurée côté Firebase) ne bloquent pas la suppression.
  Future<void> revokeAppleIfLinked() async {
    final user = _auth.currentUser;
    if (user == null ||
        !user.providerData.any((p) => p.providerId == 'apple.com')) {
      return;
    }
    try {
      final cred = await user.reauthenticateWithProvider(_appleProvider());
      final code = cred.additionalUserInfo?.authorizationCode;
      if (code != null) await _auth.revokeTokenWithAuthorizationCode(code);
    } on fb.FirebaseAuthException catch (e) {
      if (isCanceledAuthError(e.code)) rethrow;
    }
  }

  static fb.AppleAuthProvider _appleProvider() => fb.AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}

/// Codes renvoyés quand l'utilisateur ferme la feuille de connexion.
bool isCanceledAuthError(String code) =>
    code == 'canceled' ||
    code == 'web-context-canceled' ||
    code == 'user-cancelled' ||
    code == 'popup-closed-by-user';
