/// Données calculées pour les cartes de partage.
library;

/// Moyenne des notes posées (les notes absentes ou à 0 sont ignorées),
/// null si aucune note.
double? meanScoreOf(Iterable<double?> scores) {
  final rated = [
    for (final s in scores)
      if (s != null && s > 0) s,
  ];
  if (rated.isEmpty) return null;
  return rated.reduce((a, b) => a + b) / rated.length;
}

/// Note affichée sur une carte : « 8,3 » (virgule hors anglais), « — » sinon.
String formatCardScore(double? score, {required String languageCode}) {
  if (score == null) return '—';
  final raw = score.toStringAsFixed(1);
  return languageCode == 'en' ? raw : raw.replaceAll('.', ',');
}

/// Rang affiché sur une jaquette : « 01 », « 02 »…
String coverRank(int index) => (index + 1).toString().padLeft(2, '0');
