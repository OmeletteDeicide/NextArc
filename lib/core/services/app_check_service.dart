import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check : prouve à Firestore, Storage et aux Cloud Functions que
/// les requêtes viennent bien de l'app NextArc installée depuis le Play Store
/// (Play Integrity) ou l'App Store (App Attest, DeviceCheck en secours). En debug, un jeton de debug est affiché dans les logs et
/// doit être enregistré dans la console Firebase.
abstract final class AppCheckService {
  /// En-tête lu par les Cloud Functions HTTP.
  static const header = 'X-Firebase-AppCheck';

  /// À appeler juste après `Firebase.initializeApp()`. Ne bloque jamais le
  /// démarrage : sans App Check, l'app fonctionne tant que l'application
  /// n'est pas imposée côté console.
  static Future<void> activate() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
    } catch (e) {
      debugPrint('App Check non activé : $e');
    }
  }

  /// En-têtes à joindre aux appels des Cloud Functions (vide si le jeton ne
  /// peut pas être obtenu, par exemple sur une version installée hors Play).
  static Future<Map<String, String>> headers() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      return token == null ? const {} : {header: token};
    } catch (_) {
      return const {};
    }
  }
}
