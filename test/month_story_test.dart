import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/month_story.dart';

void main() {
  group('compareMonths', () {
    test('mois précédent sous 3 h → pas de comparaison', () {
      final r = compareMonths(currentMinutes: 600, previousMinutes: 179);
      expect(r.trend, MonthTrend.hidden);
    });

    test('hausse → pourcentage', () {
      final r = compareMonths(currentMinutes: 576, previousMinutes: 417);
      expect(r.trend, MonthTrend.percent);
      expect(r.percent, 38);
    });

    test('baisse d\'au plus 10 % → pourcentage', () {
      final r = compareMonths(currentMinutes: 540, previousMinutes: 600);
      expect(r.trend, MonthTrend.percent);
      expect(r.percent, -10);
    });

    test('baisse plus forte → phrase neutre', () {
      final r = compareMonths(currentMinutes: 300, previousMinutes: 600);
      expect(r.trend, MonthTrend.calmer);
    });

    test('même temps → « autant »', () {
      final r = compareMonths(currentMinutes: 600, previousMinutes: 600);
      expect(r.trend, MonthTrend.same);
    });
  });

  test('signedPercent', () {
    expect(signedPercent(38), '+38');
    expect(signedPercent(-7), '−7');
    expect(signedPercent(0), '0');
  });

  test('heroDuration', () {
    expect(heroDuration(576), '9 H 36');
    expect(heroDuration(605), '10 H 05');
    expect(heroDuration(720), '12 H');
    expect(heroDuration(45), '45 MIN');
    expect(heroDuration(0), '0 MIN');
  });

  test('lastMonths traverse le changement d\'année', () {
    final months = lastMonths(DateTime(2026, 2, 14), count: 4);
    expect(months, [
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
  });

  test('barRatios', () {
    expect(barRatios([0, 50, 100]), [0, 0.5, 1]);
    expect(barRatios([0, 0]), [0, 0]);
  });
}
