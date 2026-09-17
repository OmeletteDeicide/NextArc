import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/list_items.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

ListItem _item(int id, ListStatus status,
        {double? score, bool favourite = false, int progress = 0, int? total}) =>
    ListItem.fromLocal(GuestWatchlistEntry(
      animeId: id,
      title: 'Titre $id',
      status: status,
      score: score,
      favourite: favourite,
      progress: progress,
      episodes: total,
    ));

void main() {
  group('plusOne', () {
    test('ajoute un épisode sans changer le statut', () {
      final r = plusOne(progress: 3, total: 12, status: ListStatus.current);
      expect(r.progress, 4);
      expect(r.status, ListStatus.current);
    });

    test('atteindre le total passe en Terminé', () {
      final r = plusOne(progress: 11, total: 12, status: ListStatus.current);
      expect(r.progress, 12);
      expect(r.status, ListStatus.completed);
    });

    test('total inconnu : pas de limite', () {
      final r = plusOne(progress: 1100, total: null, status: ListStatus.current);
      expect(r.progress, 1101);
      expect(r.status, ListStatus.current);
    });

    test('un média prévu passe en cours', () {
      final r = plusOne(progress: 0, total: 0, status: ListStatus.planning);
      expect(r.progress, 1);
      expect(r.status, ListStatus.current);
    });

    test('ne dépasse jamais le total', () {
      final r = plusOne(progress: 14, total: 12, status: ListStatus.current);
      expect(r.progress, 12);
      expect(r.status, ListStatus.completed);
    });
  });

  group('canPlusOne', () {
    test('seulement en cours et pas encore fini', () {
      expect(_item(1, ListStatus.current, progress: 3, total: 12).canPlusOne,
          isTrue);
      expect(_item(2, ListStatus.current, progress: 12, total: 12).canPlusOne,
          isFalse);
      expect(_item(3, ListStatus.current, progress: 40).canPlusOne, isTrue);
      expect(_item(4, ListStatus.paused, progress: 3, total: 12).canPlusOne,
          isFalse);
    });
  });

  group('buildListTabs', () {
    test('ordre de l\'app, statuts vides masqués, Favoris toujours présent', () {
      final tabs = buildListTabs([
        _item(1, ListStatus.completed),
        _item(2, ListStatus.current),
        _item(3, ListStatus.dropped),
      ]);
      expect(tabs.map((t) => t.key), [
        'CURRENT',
        'FAVOURITES',
        'COMPLETED',
        'DROPPED',
      ]);
      expect(tabs[1].items, isEmpty);
    });

    test('favoris : ❤️ uniquement, triés par note', () {
      final tabs = buildListTabs([
        _item(1, ListStatus.completed, score: 7, favourite: true),
        _item(2, ListStatus.completed, score: 9, favourite: true),
        _item(3, ListStatus.completed, score: 10),
      ]);
      final favourites = tabs.firstWhere((t) => t.isFavourites);
      expect(favourites.items.map((i) => i.mediaId), [2, 1]);
    });
  });

  group('countReleasesWithin', () {
    final now = DateTime(2026, 9, 15, 12);

    test('compte les diffusions des 7 prochains jours', () {
      final times = [
        now.subtract(const Duration(hours: 1)), // déjà passée
        now.add(const Duration(hours: 2)),
        now.add(const Duration(days: 6)),
        now.add(const Duration(days: 7)),
        now.add(const Duration(days: 8)), // trop loin
      ];
      expect(countReleasesWithin(times, now: now), 3);
    });

    test('aucune diffusion → 0', () {
      expect(countReleasesWithin(const [], now: now), 0);
    });
  });

  group('progression affichée', () {
    test('total connu, sinon épisodes sortis, sinon ?', () {
      expect(formatProgress(12, total: 24, aired: 10), '12/24');
      expect(formatProgress(1150, total: null, aired: 1178), '1150/1178');
      expect(formatProgress(3, total: null, aired: null), '3/?');
      expect(formatProgress(0, total: 0, aired: 0), '0/?');
    });

    test('plafond de la barre', () {
      expect(progressCeiling(total: 24, aired: 30), 24);
      expect(progressCeiling(total: null, aired: 1178), 1178);
      expect(progressCeiling(), isNull);
    });
  });
}
