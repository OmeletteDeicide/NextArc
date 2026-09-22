/// Logique du récap narratif « Ton mois » de l'écran Stats.
library;

/// En dessous de ce temps le mois précédent, la comparaison n'a pas de sens.
const int minPreviousMinutesForComparison = 3 * 60;

/// Baisse maximale (en %) encore annoncée en pourcentage.
const int maxAnnouncedDecrease = 10;

enum MonthTrend {
  /// Mois précédent trop léger : pas de comparaison.
  hidden,

  /// Hausse, ou baisse d'au plus [maxAnnouncedDecrease] % : pourcentage.
  percent,

  /// Exactement le même temps.
  same,

  /// Baisse plus forte : phrase neutre (« un mois plus calme »).
  calmer,
}

/// Comparaison du temps du mois avec le mois précédent.
({MonthTrend trend, int percent}) compareMonths({
  required int currentMinutes,
  required int previousMinutes,
}) {
  if (previousMinutes < minPreviousMinutesForComparison) {
    return (trend: MonthTrend.hidden, percent: 0);
  }
  final change =
      ((currentMinutes - previousMinutes) / previousMinutes * 100).round();
  if (change == 0) return (trend: MonthTrend.same, percent: 0);
  if (change > 0 || change >= -maxAnnouncedDecrease) {
    return (trend: MonthTrend.percent, percent: change);
  }
  return (trend: MonthTrend.calmer, percent: change);
}

/// Pourcentage signé : « +38 », « −7 » (vrai signe moins).
String signedPercent(int percent) =>
    percent > 0 ? '+$percent' : percent < 0 ? '−${-percent}' : '0';

/// Grand chiffre du récap : « 9 H 36 », « 12 H », « 45 MIN ». Dès 1 000 h,
/// les minutes disparaissent et les milliers sont séparés (« 12 000 H ») pour
/// que la ligne garde la largeur de « EN PLUS. ».
String heroDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest MIN';
  if (hours >= 1000) {
    final digits = '$hours';
    final split = digits.length - 3;
    // Espace insécable : le nombre ne se coupe jamais
    return '${digits.substring(0, split)} ${digits.substring(split)} H';
  }
  if (rest == 0) return '$hours H';
  return '$hours H ${rest.toString().padLeft(2, '0')}';
}

/// Les [count] derniers mois jusqu'à [now] inclus, du plus ancien au plus récent.
List<DateTime> lastMonths(DateTime now, {int count = 7}) => [
      for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month - i),
    ];

/// Hauteur relative de chaque barre (0 → 1) par rapport au mois le plus chargé.
List<double> barRatios(List<int> minutes) {
  final max = minutes.fold<int>(0, (m, v) => v > m ? v : m);
  if (max == 0) return List.filled(minutes.length, 0);
  return [for (final v in minutes) v / max];
}
