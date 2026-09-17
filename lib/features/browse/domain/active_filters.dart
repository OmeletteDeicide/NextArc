import 'package:nextarc/features/browse/domain/filter_params.dart';

/// Nature d'un filtre actif (sert à nommer le filtre à retirer).
enum ActiveFilterKind { minScore, year, status, format, genre }

/// Un filtre actif, affiché en chip avec un × pour le retirer.
class ActiveFilter {
  const ActiveFilter({
    required this.kind,
    required this.value,
    required this.remove,
  });

  final ActiveFilterKind kind;

  /// Valeur brute (genre, code de format / statut, « 2018-2024 », « 7 »).
  final String value;

  /// Paramètres sans ce filtre.
  final FilterParams Function(FilterParams) remove;
}

/// Filtres actifs dans l'ordre d'affichage : un chip par genre et par format,
/// puis statut, année et score.
List<ActiveFilter> activeFiltersOf(FilterParams p) => [
      for (final g in p.genres)
        ActiveFilter(
          kind: ActiveFilterKind.genre,
          value: g,
          remove: (q) =>
              q.copyWith(genres: q.genres.where((x) => x != g).toList()),
        ),
      for (final f in p.formats)
        ActiveFilter(
          kind: ActiveFilterKind.format,
          value: f,
          remove: (q) =>
              q.copyWith(formats: q.formats.where((x) => x != f).toList()),
        ),
      if (p.status != null)
        ActiveFilter(
          kind: ActiveFilterKind.status,
          value: p.status!,
          remove: (q) => q.copyWith(clearStatus: true),
        ),
      if (p.yearFrom != null || p.yearTo != null)
        ActiveFilter(
          kind: ActiveFilterKind.year,
          value: '${p.yearFrom ?? ''}-${p.yearTo ?? ''}',
          remove: (q) => q.copyWith(clearYearFrom: true, clearYearTo: true),
        ),
      if (p.minScore != null)
        ActiveFilter(
          kind: ActiveFilterKind.minScore,
          value: '${p.minScore}',
          remove: (q) => q.copyWith(clearMinScore: true),
        ),
    ];

/// Nombre de filtres actifs, tel qu'affiché (« 3 filtres »).
int activeFilterCount(FilterParams p) => activeFiltersOf(p).length;

/// Filtre à proposer de retirer quand il n'y a aucun résultat : le plus
/// restrictif d'abord (score, année, statut), puis le dernier format ou genre
/// ajouté.
ActiveFilter? filterToRelax(FilterParams p) {
  final active = activeFiltersOf(p);
  if (active.isEmpty) return null;
  for (final kind in const [
    ActiveFilterKind.minScore,
    ActiveFilterKind.year,
    ActiveFilterKind.status,
    ActiveFilterKind.format,
    ActiveFilterKind.genre,
  ]) {
    final ofKind = active.where((f) => f.kind == kind);
    if (ofKind.isNotEmpty) return ofKind.last;
  }
  return active.last;
}

/// Seuils proposés pour le score minimum (null = peu importe).
const List<int?> minScoreSteps = [null, 6, 7, 8, 9];

/// AniList plafonne le total renvoyé : au-delà, on affiche « 5 000+ ».
const int anilistTotalCap = 5000;
