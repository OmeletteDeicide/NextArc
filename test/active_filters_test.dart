import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/browse/domain/active_filters.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';

void main() {
  const params = FilterParams(
    genres: ['Action', 'Sci-Fi'],
    formats: ['TV'],
    status: 'RELEASING',
    yearFrom: 2018,
    minScore: 8,
  );

  test('un chip par genre et format, puis statut, année, score', () {
    final active = activeFiltersOf(params);
    expect(active.map((f) => f.kind), [
      ActiveFilterKind.genre,
      ActiveFilterKind.genre,
      ActiveFilterKind.format,
      ActiveFilterKind.status,
      ActiveFilterKind.year,
      ActiveFilterKind.minScore,
    ]);
    expect(activeFilterCount(params), 6);
    expect(activeFilterCount(const FilterParams()), 0);
  });

  test('retirer un filtre ne touche pas aux autres', () {
    final sciFi = activeFiltersOf(params)[1];
    final without = sciFi.remove(params);
    expect(without.genres, ['Action']);
    expect(without.formats, ['TV']);
    expect(without.minScore, 8);

    final year = activeFiltersOf(params)
        .firstWhere((f) => f.kind == ActiveFilterKind.year);
    final noYear = year.remove(params);
    expect(noYear.yearFrom, isNull);
    expect(noYear.yearTo, isNull);
    expect(noYear.status, 'RELEASING');
  });

  test('aucun résultat : on propose d\'abord de retirer le score', () {
    expect(filterToRelax(params)!.kind, ActiveFilterKind.minScore);
    expect(
      filterToRelax(const FilterParams(genres: ['Action', 'Drama']))!.value,
      'Drama',
    );
    expect(filterToRelax(const FilterParams()), isNull);
  });
}
