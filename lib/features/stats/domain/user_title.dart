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

  factory UserTitle.from({
    required int animeCompleted,
    required int mangaCompleted,
    required int watchMinutes,
    required int readMinutes,
  }) {
    final isArcer = animeCompleted + mangaCompleted >= arcerMinCompleted &&
        (watchMinutes + readMinutes) ~/ 60 >= arcerMinHours;

    return UserTitle._(
      rankKey: _highest(ranks, animeCompleted),
      qualifierKey: _highest(qualifiers, watchMinutes ~/ 60),
      isArcer: isArcer,
    );
  }

  static T _highest<T>(List<(int, T)> tiers, int value) {
    var result = tiers.first.$2;
    for (final (min, key) in tiers) {
      if (value >= min) result = key;
    }
    return result;
  }

  /// Titre affiché, ex : « Grand Acheveur », « Légende Divin », « Arcer ».
  String get label {
    if (isArcer) return 'title_arcer'.tr();
    final name = rankKey.tr();
    return qualifierKey?.tr(namedArgs: {'name': name}) ?? name;
  }
}
