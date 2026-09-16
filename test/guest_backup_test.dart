import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/domain/guest_backup.dart';

void main() {
  final now = DateTime(2026, 9, 16, 9, 30);

  test('jamais exportée', () {
    expect(backupAge(null, now).key, 'settings_backup_never');
  });

  test('plus tôt dans la journée → aujourd\'hui', () {
    expect(backupAge(DateTime(2026, 9, 16, 0, 5), now).key,
        'settings_backup_today');
  });

  test('hier soir, même moins de 24 h avant → hier', () {
    expect(backupAge(DateTime(2026, 9, 15, 23, 50), now).key,
        'settings_backup_yesterday');
  });

  test('plusieurs jours, y compris d\'un mois sur l\'autre', () {
    final age = backupAge(DateTime(2026, 8, 30, 12), now);
    expect(age.key, 'settings_backup_days');
    expect(age.days, 17);
  });
}
