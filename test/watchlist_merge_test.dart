import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_merge.dart';

GuestWatchlistEntry entry(
  int id, {
  ListStatus status = ListStatus.planning,
  int? progress,
  bool favourite = false,
  DateTime? updatedAt,
}) =>
    GuestWatchlistEntry(
      animeId: id,
      title: 'Media $id',
      status: status,
      progress: progress,
      favourite: favourite,
      updatedAt: updatedAt,
    );

void main() {
  final older = DateTime(2026, 1, 1);
  final newer = DateTime(2026, 6, 1);

  test('ajoute les médias absents sans toucher aux existants', () {
    final current = {1: entry(1, updatedAt: older)};
    final writes = computeMergeWrites(current, [entry(2, updatedAt: older)]);

    expect(writes.map((e) => e.animeId), [2]);
  });

  test('la version la plus récente gagne', () {
    final current = {
      1: entry(1, status: ListStatus.current, progress: 30, updatedAt: newer),
    };

    expect(
      computeMergeWrites(current, [entry(1, updatedAt: older)]),
      isEmpty,
    );

    final writes = computeMergeWrites(
      {1: entry(1, updatedAt: older)},
      [entry(1, status: ListStatus.current, progress: 30, updatedAt: newer)],
    );
    expect(writes.single.progress, 30);
  });

  test('une entrée sans date ne remplace jamais une existante', () {
    final current = {1: entry(1, progress: 12, updatedAt: older)};
    expect(computeMergeWrites(current, [entry(1, progress: 3)]), isEmpty);
  });

  test('un ❤️ n\'est jamais perdu', () {
    final keepsExistingLike = computeMergeWrites(
      {1: entry(1, favourite: true, updatedAt: older)},
      [entry(1, progress: 5, updatedAt: newer)],
    );
    expect(keepsExistingLike.single.favourite, isTrue);
    expect(keepsExistingLike.single.progress, 5);

    final addsIncomingLike = computeMergeWrites(
      {1: entry(1, progress: 8, updatedAt: newer)},
      [entry(1, favourite: true, updatedAt: older)],
    );
    expect(addsIncomingLike.single.favourite, isTrue);
    expect(addsIncomingLike.single.progress, 8);
  });

  test('tryParse rejette les entrées invalides et borne les valeurs', () {
    expect(GuestWatchlistEntry.tryParse('nope'), isNull);
    expect(GuestWatchlistEntry.tryParse({'animeId': -1}), isNull);
    expect(
      GuestWatchlistEntry.tryParse(
          {'animeId': 1, 'title': 'A', 'status': 'HACKED'}),
      isNull,
    );

    final parsed = GuestWatchlistEntry.tryParse({
      'animeId': 1,
      'title': 'x' * 900,
      'status': 'CURRENT',
      'score': 99,
      'progress': 999999,
      'coverImage': 'javascript:alert(1)',
    })!;
    expect(parsed.title.length, GuestWatchlistEntry.maxTitleLength);
    expect(parsed.score, isNull);
    expect(parsed.progress, isNull);
    expect(parsed.coverImage, isNull);
  });
}
