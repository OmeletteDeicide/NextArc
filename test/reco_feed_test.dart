import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/domain/reco_feed.dart';

MediaModel _m(int id, {int score = 70}) =>
    MediaModel(id: id, titleRomaji: 'Titre $id', averageScore: score);

RecoSource _fav(int id, {double? score}) => RecoSource(
  id: id,
  title: 'Aimé $id',
  kind: RecoSourceKind.favourite,
  score: score,
);

RecoSource _rated(int id, double score) => RecoSource(
  id: id,
  title: 'Noté $id',
  kind: RecoSourceKind.rated,
  score: score,
);

void main() {
  group('selectRecoSources', () {
    test('❤️ d\'abord, puis note 10, puis note ≥ 8', () {
      final selected = selectRecoSources([
        _rated(1, 8),
        _rated(2, 10),
        _fav(3),
      ], now: DateTime(2026, 1, 1));
      expect(selected.map((s) => s.id), [3, 2, 1]);
    });

    test('rotation quotidienne dans un même niveau', () {
      final favs = [_fav(1), _fav(2), _fav(3), _fav(4), _fav(5)];
      final day1 = selectRecoSources(favs, now: DateTime(2026, 3, 1), max: 2);
      final day2 = selectRecoSources(favs, now: DateTime(2026, 3, 2), max: 2);
      expect(day1.length, 2);
      expect(day1.map((s) => s.id), isNot(equals(day2.map((s) => s.id))));
      // Même jour → même tirage
      expect(
        selectRecoSources(
          favs,
          now: DateTime(2026, 3, 1, 22),
          max: 2,
        ).map((s) => s.id),
        day1.map((s) => s.id),
      );
    });
  });

  group('buildRecoFeed', () {
    test('jamais un titre de la liste ni deux fois le même titre', () {
      final feed = buildRecoFeed(
        sources: [_fav(1), _fav(2)],
        recosBySource: {
          1: [_m(10), _m(11, score: 90), _m(12)],
          2: [_m(11), _m(12), _m(13), _m(99)],
        },
        excludeIds: {99},
      );
      final all = [
        feed.pick!.media.id,
        for (final r in feed.rails) ...r.items.map((m) => m.id),
      ];
      expect(all.toSet().length, all.length);
      expect(all, isNot(contains(99)));
    });

    test(
      'la reco du jour est la mieux notée du premier rail et n\'y reste pas',
      () {
        final feed = buildRecoFeed(
          sources: [_fav(1)],
          recosBySource: {
            1: [_m(10, score: 60), _m(11, score: 90), _m(12, score: 70)],
          },
          excludeIds: const {},
        );
        expect(feed.pick!.media.id, 11);
        expect(feed.rails.single.items.map((m) => m.id), [10, 12]);
      },
    );

    test('rail « Dans tes genres » dédoublonné, seulement si personnalisé', () {
      final feed = buildRecoFeed(
        sources: [_fav(1)],
        recosBySource: {
          1: [_m(10), _m(11)],
        },
        excludeIds: const {},
        genres: const ['Action', 'Drama'],
        genrePool: [_m(11), _m(20), _m(21)],
      );
      expect(feed.genreItems.map((m) => m.id), [20, 21]);
      expect(feed.genres, ['Action', 'Drama']);
    });

    test('aucune source → tendances, pas de rails', () {
      final feed = buildRecoFeed(
        sources: const [],
        recosBySource: const {},
        excludeIds: {2},
        trending: [_m(1), _m(2), _m(3)],
        genrePool: [_m(4)],
      );
      expect(feed.isPersonalised, isFalse);
      expect(feed.trending.map((m) => m.id), [1, 3]);
      expect(feed.genreItems, isEmpty);
    });
  });

  test('dominantGenres', () {
    expect(
      dominantGenres([
        ['Action', 'Drama'],
        ['Action', 'Sci-Fi'],
        ['Drama'],
        null,
      ]),
      ['Action', 'Drama'],
    );
  });
}
