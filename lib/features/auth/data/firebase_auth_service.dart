import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

/// Service Firebase Auth — email/password + Google Sign-In.
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

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
