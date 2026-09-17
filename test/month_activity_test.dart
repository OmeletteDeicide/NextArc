import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

GuestWatchlistEntry entry({
  int id = 1,
  ListStatus status = ListStatus.current,
  int? progress,
  double? score,
  bool favourite = false,
  String mediaType = 'ANIME',
  int? duration,
}) =>
    GuestWatchlistEntry(
      animeId: id,
      title: 'Media $id',
      status: status,
      progress: progress,
      score: score,
      favourite: favourite,
      mediaType: mediaType,
      duration: duration,
    );

void main() {
  group('computeActivity', () {
    test('ne compte que les épisodes ajoutés', () {
      final item = computeActivity(
        before: entry(progress: 20),
        after: entry(progress: 24),
        inLibraryPhase: false,
      )!;
      expect(item.progressAdded, 4);
      expect(item.completed, isFalse);
    });

    test('rien de nouveau → pas d\'activité', () {
      expect(
        computeActivity(
          before: entry(progress: 5, score: 7),
          after: entry(progress: 5, score: 7),
          inLibraryPhase: false,
        ),
        isNull,
      );
    });

    test('ajout direct en Terminé : rattrapage pendant les 30 premiers jours',
        () {
      final completed =
          entry(status: ListStatus.completed, progress: 12, score: 9);
      expect(
        computeActivity(before: null, after: completed, inLibraryPhase: true),
        isNull,
      );

      final later =
          computeActivity(before: null, after: completed, inLibraryPhase: false)!;
      expect(later.progressAdded, 12);
      expect(later.completed, isTrue);
    });

    test('nouveau média en cours : compte même pendant la phase bibliothèque',
        () {
      final item = computeActivity(
        before: null,
        after: entry(progress: 3),
        inLibraryPhase: true,
      )!;
      expect(item.progressAdded, 3);
    });

    test('❤️ ajouté ou note posée comptent', () {
      expect(
        computeActivity(
          before: entry(progress: 5),
          after: entry(progress: 5, favourite: true),
          inLibraryPhase: false,
        )!
            .favourite,
        isTrue,
      );
      expect(
        computeActivity(
          before: entry(progress: 5),
          after: entry(progress: 5, score: 8),
          inLibraryPhase: false,
        )!
            .score,
        8,
      );
    });
  });

  test('MonthlyRecap : totaux et ordre des médias mis en avant', () {
    final recap = MonthlyRecap.fromItems('2026-09', const [
      ActivityItem(
          mediaId: 1, title: 'En cours', mediaType: 'ANIME', progressAdded: 6),
      ActivityItem(
          mediaId: 2,
          title: 'Aimé',
          mediaType: 'ANIME',
          progressAdded: 2,
          favourite: true,
          duration: 30),
      ActivityItem(
          mediaId: 3,
          title: 'Très bien noté',
          mediaType: 'ANIME',
          progressAdded: 12,
          completed: true,
          score: 9),
      ActivityItem(
          mediaId: 4, title: 'Manga', mediaType: 'MANGA', progressAdded: 20),
    ]);

    expect(recap.episodesWatched, 20);
    // 6 × 24 + 2 × 30 + 12 × 24
    expect(recap.watchTimeMinutes, 492);
    expect(recap.chaptersRead, 20);
    expect(recap.animeCompleted, 1);
    expect(recap.highlights.map((i) => i.mediaId), [3, 2, 4, 1]);
    expect(recap.isEmpty, isFalse);
    expect(MonthlyRecap.fromItems('2026-09', const []).isEmpty, isTrue);
  });

  test('clés de mois', () {
    expect(monthKey(DateTime(2026, 9, 14)), '2026-09');
    expect(previousMonthKey(DateTime(2026, 1, 3)), '2025-12');
  });
}
