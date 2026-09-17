import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/watchlist/data/guest_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

final guestWatchlistRepositoryProvider =
    Provider((_) => GuestWatchlistRepository());

class GuestWatchlistNotifier
    extends AsyncNotifier<List<GuestWatchlistEntry>> {
  @override
  Future<List<GuestWatchlistEntry>> build() async {
    final repo = ref.read(guestWatchlistRepositoryProvider);
    await repo.migrateFavouritesFromScores();
    return repo.getEntries();
  }

  Future<void> upsert(GuestWatchlistEntry entry) async {
    final repo = ref.read(guestWatchlistRepositoryProvider);
    final before = (await repo.getEntries())
        .where((e) => e.animeId == entry.animeId)
        .firstOrNull;
    await repo.upsertEntry(entry);
    await _recordActivity(() => ref
        .read(activityRepositoryProvider)
        .record(uid: null, before: before, after: entry));
    ref.invalidateSelf();
  }

  /// Le journal d'activité ne doit jamais faire échouer une modification.
  Future<void> _recordActivity(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(monthlyRecapProvider);
    } catch (_) {}
  }

  Future<void> remove(int animeId) async {
    await ref.read(guestWatchlistRepositoryProvider).removeEntry(animeId);
    // Plus dans la liste → plus de notifications d'épisodes pour ce média
    await NotificationPrefsRepository.instance.disable(animeId);
    // Un média supprimé n'apparaît pas dans le récap du mois
    await _recordActivity(() => ref
        .read(activityRepositoryProvider)
        .removeFromCurrentMonth(uid: null, mediaId: animeId));
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    await ref.read(guestWatchlistRepositoryProvider).clearAll();
    ref.invalidateSelf();
  }
}

final guestWatchlistProvider =
    AsyncNotifierProvider<GuestWatchlistNotifier, List<GuestWatchlistEntry>>(
  GuestWatchlistNotifier.new,
);
