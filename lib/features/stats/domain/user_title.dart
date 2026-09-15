import 'package:easy_localization/easy_localization.dart';

/// Titre de profil, toujours calculé sur le cumul total (jamais sur un mois).
///
/// - Nom : selon le nombre d'anime terminés (Curieux → Légende).
/// - Qualificatif : selon les heures de visionnage (Petit → Divin).
/// - **Arcer** : titre ultime, qui remplace les deux, quand anime + manga
///   terminés et heures de visionnage + lecture cumulées atteignent les seuils.
class UserTitle {
  const UserTitle._({
    required this.rankKey,
    required this.qualifierKey,
    required this.isArcer,
    required this.animeCompleted,
    required this.watchHours,
    required this.totalCompleted,
    required this.totalHours,
  });

  /// Anime + manga terminés nécessaires pour Arcer.
  static const arcerMinCompleted = 1500;

  /// Heures de visionnage + lecture nécessaires pour Arcer.
  static const arcerMinHours = 12000;

  /// (anime terminés minimum, clé de traduction), du plus bas au plus haut.
  static const ranks = [
    (0, 'title_rank_curious'),
    (10, 'title_rank_spectator'),
    (25, 'title_rank_explorer'),
    (50, 'title_rank_finisher'),
    (75, 'title_rank_marathoner'),
    (100, 'title_rank_terminator'),
    (150, 'title_rank_achiever'),
    (250, 'title_rank_sentinel'),
    (400, 'title_rank_veteran'),
    (600, 'title_rank_conqueror'),
    (800, 'title_rank_master'),
    (1000, 'title_rank_legend'),
  ];

  /// (heures de visionnage minimum, clé de traduction ou null = sans
  /// qualificatif). Chaque traduction est un motif contenant `{name}`.
  static const qualifiers = <(int, String?)>[
    (0, 'title_qual_little'),
    (100, null),
    (400, 'title_qual_great'),
    (1000, 'title_qual_eminent'),
    (2000, 'title_qual_supreme'),
    (5000, 'title_qual_absolute'),
    (10000, 'title_qual_divine'),
  ];

  final String rankKey;
  final String? qualifierKey;
  final bool isArcer;

  final int animeCompleted;
  final int watchHours;

  /// Cumuls anime + manga utilisés pour Arcer.
  final int totalCompleted;
  final int totalHours;

  factory UserTitle.from({
    required int animeCompleted,
    required int mangaCompleted,
    required int watchMinutes,
    required int readMinutes,
  }) {
    final watchHours = watchMinutes ~/ 60;
    final totalCompleted = animeCompleted + mangaCompleted;
    final totalHours = (watchMinutes + readMinutes) ~/ 60;

    return UserTitle._(
      rankKey: _highest(ranks, animeCompleted),
      qualifierKey: _highest(qualifiers, watchHours),
      isArcer: totalCompleted >= arcerMinCompleted &&
          totalHours >= arcerMinHours,
      animeCompleted: animeCompleted,
      watchHours: watchHours,
      totalCompleted: totalCompleted,
      totalHours: totalHours,
    );
  }

  static T _highest<T>(List<(int, T)> tiers, int value) {
    var result = tiers.first.$2;
    for (final (min, key) in tiers) {
      if (value >= min) result = key;
    }
    return result;
  }

  /// Prochain nom : (anime terminés manquants, clé du nom), null si Légende.
  (int, String)? get nextRank {
    for (final (min, key) in ranks) {
      if (animeCompleted < min) return (min - animeCompleted, key);
    }
    return null;
  }

  /// Heures de visionnage manquantes pour le prochain qualificatif,
  /// null si Divin.
  int? get hoursToNextQualifier {
    for (final (min, _) in qualifiers) {
      if (watchHours < min) return min - watchHours;
    }
    return null;
  }

  // ── Jauges de l'écran « Mon titre » ──────────────────────────────────────

  /// Position du nom actuel dans [ranks].
  int get rankIndex => _indexOf(ranks, animeCompleted);

  /// Anime terminés requis pour le nom suivant, null si Légende.
  int? get nextRankThreshold =>
      rankIndex + 1 < ranks.length ? ranks[rankIndex + 1].$1 : null;

  /// Avancée vers le nom suivant (0 → 1), 1 si Légende.
  double get rankProgress {
    final next = nextRankThreshold;
    return next == null ? 1 : (animeCompleted / next).clamp(0.0, 1.0);
  }

  /// Position du qualificatif actuel dans [qualifiers].
  int get qualifierIndex => _indexOf(qualifiers, watchHours);

  /// Heures requises pour le qualificatif suivant, null si Divin.
  int? get nextQualifierThreshold => qualifierIndex + 1 < qualifiers.length
      ? qualifiers[qualifierIndex + 1].$1
      : null;

  /// Clé du qualificatif suivant (null = palier « sans qualificatif »).
  String? get nextQualifierKey => qualifierIndex + 1 < qualifiers.length
      ? qualifiers[qualifierIndex + 1].$2
      : null;

  /// Le prochain palier fait perdre le mot actuel (« Petit Curieux » →
  /// « Curieux ») : à annoncer, sinon l'utilisateur croit à une régression.
  bool get nextQualifierDropsWord =>
      nextQualifierThreshold != null &&
      nextQualifierKey == null &&
      qualifierKey != null;

  /// Avancée vers le qualificatif suivant (0 → 1), 1 si Divin.
  double get qualifierProgress {
    final next = nextQualifierThreshold;
    return next == null ? 1 : (watchHours / next).clamp(0.0, 1.0);
  }

  static int _indexOf<T>(List<(int, T)> tiers, int value) {
    var index = 0;
    for (var i = 0; i < tiers.length; i++) {
      if (value >= tiers[i].$1) index = i;
    }
    return index;
  }

  // ── Route vers Arcer ─────────────────────────────────────────────────────

  /// Avancée vers le seuil Arcer des titres terminés (0 → 1).
  double get arcerCompletedProgress =>
      (totalCompleted / arcerMinCompleted).clamp(0.0, 1.0);

  /// Avancée vers le seuil Arcer des heures de visionnage + lecture (0 → 1).
  double get arcerHoursProgress =>
      (totalHours / arcerMinHours).clamp(0.0, 1.0);

  /// Nombre de paliers affichés sur la route (un par qualificatif).
  static int get tierCount => qualifiers.length;

  /// Palier atteint, de 1 à [tierCount] (le dernier pour un Arcer).
  int get tier {
    if (isArcer) return tierCount;
    var reached = 1;
    for (var i = 0; i < qualifiers.length; i++) {
      if (watchHours >= qualifiers[i].$1) reached = i + 1;
    }
    return reached;
  }

  /// Titre affiché, ex : « Grand Acheveur », « Légende Divin », « Arcer ».
  String get label {
    if (isArcer) return 'title_arcer'.tr();
    final name = rankKey.tr();
    return qualifierKey?.tr(namedArgs: {'name': name}) ?? name;
  }
}
