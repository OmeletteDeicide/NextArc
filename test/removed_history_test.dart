import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';

GuestWatchlistEntry _entry(int id, {bool deleted = false}) => GuestWatchlistEntry(
      animeId: id,
      title: 'Titre $id',
      status: ListStatus.current,
      progress: 12,
      episodes: 24,
      score: 8.5,
      favourite: true,
      mediaType: 'MANGA',
      deleted: deleted,
      updatedAt: DateTime(2026, 9, 1),
    );

RemovedEntry _removed(int id, DateTime at) =>
    RemovedEntry(entry: _entry(id), removedAt: at);

void main() {
  final now = DateTime(2026, 9, 21, 12);

  test('aller-retour JSON sans perte', () {
    final removed = RemovedEntry(
      entry: _entry(7),
      removedAt: now,
      notificationsEnabled: true,
    );
    final back = RemovedEntry.tryParse(removed.toJson())!;
    expect(back.mediaId, 7);
    expect(back.entry.progress, 12);
    expect(back.entry.score, 8.5);
    expect(back.entry.favourite, isTrue);
    expect(back.entry.isManga, isTrue);
    expect(back.removedAt, now);
    expect(back.notificationsEnabled, isTrue);
  });

  test('données illisibles ignorées', () {
    expect(RemovedEntry.tryParse(null), isNull);
    expect(RemovedEntry.tryParse({'entry': {}, 'removedAt': 1}), isNull);
    expect(RemovedEntry.tryParse({'entry': _entry(1).toJson()}), isNull);
  });

  test('historique : 30 jours, du plus récent au plus ancien', () {
    final list = pruneRemovedHistory([
      _removed(1, now.subtract(const Duration(days: 2))),
      _removed(2, now.subtract(const Duration(days: 31))),
      _removed(3, now.subtract(const Duration(hours: 1))),
    ], now: now);
    expect(list.map((e) => e.mediaId), [3, 1]);
  });

  test('historique limité à 100 titres', () {
    final list = pruneRemovedHistory([
      for (var i = 0; i < 150; i++)
        _removed(i + 1, now.subtract(Duration(minutes: i))),
    ], now: now);
    expect(list.length, kRemovedHistoryMax);
    expect(list.first.mediaId, 1);
  });

  test('restauration : état d\'avant, daté de maintenant', () {
    final restored =
        restoredEntry(_removed(4, now), now: DateTime(2026, 9, 22));
    expect(restored.progress, 12);
    expect(restored.deleted, isFalse);
    expect(restored.updatedAt, DateTime(2026, 9, 22));
  });

  test('conflit seulement si le titre est de nouveau dans la liste', () {
    final removed = _removed(5, now);
    expect(restoreWouldOverwrite(removed, [_entry(9)]), isFalse);
    expect(restoreWouldOverwrite(removed, [_entry(5, deleted: true)]), isFalse);
    expect(restoreWouldOverwrite(removed, [_entry(5)]), isTrue);
  });
}
