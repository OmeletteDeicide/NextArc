import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Filets de sécurité du mode invité : date du dernier export JSON et bandeau
// « Mode invité » masquable pour la session.

const _storage = FlutterSecureStorage();
const _lastExportKey = 'guest_last_export_ms';

/// Date du dernier export de la liste locale, null si jamais exportée.
final lastGuestExportProvider = FutureProvider<DateTime?>((ref) async {
  try {
    final raw = await _storage.read(key: _lastExportKey);
    final ms = raw == null ? null : int.tryParse(raw);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  } catch (_) {
    return null;
  }
});

/// Mémorise qu'un export vient d'être fait.
Future<void> recordGuestExport([DateTime? at]) => _storage.write(
      key: _lastExportKey,
      value: '${(at ?? DateTime.now()).millisecondsSinceEpoch}',
    );

/// Bandeau « Mode invité » de Ma liste fermé par l'utilisateur (session).
final guestBannerDismissedProvider = StateProvider<bool>((_) => false);

/// Ancienneté de la dernière sauvegarde, en jours calendaires :
/// clé de traduction + nombre de jours.
({String key, int days}) backupAge(DateTime? last, DateTime now) {
  if (last == null) return (key: 'settings_backup_never', days: 0);
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(last.year, last.month, last.day))
      .inDays;
  if (days <= 0) return (key: 'settings_backup_today', days: 0);
  if (days == 1) return (key: 'settings_backup_yesterday', days: 1);
  return (key: 'settings_backup_days', days: days);
}
