import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/watchlist/data/guest_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';
import 'package:nextarc/features/watchlist/domain/removed_history_providers.dart';

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

  /// Retire un titre et le garde dans l'historique pour pouvoir l'annuler.
  /// Renvoie l'entrée retirée (null si elle n'était pas dans la liste).
  Future<RemovedEntry?> remove(int animeId) async {
    final repo = ref.read(guestWatchlistRepositoryProvider);
    final entry =
        (await repo.getEntries()).where((e) => e.animeId == animeId).firstOrNull;
    final removed = entry == null
        ? null
        : RemovedEntry(
            entry: entry,
            removedAt: DateTime.now(),
            notificationsEnabled:
                NotificationPrefsRepository.instance.isEnabled(animeId),
          );
    if (removed != null) {
      await ref.read(removedHistoryRepositoryProvider).record('guest', removed);
    }
    await repo.removeEntry(animeId);
    // Plus dans la liste → plus de notifications d'épisodes pour ce média
    await NotificationPrefsRepository.instance.disable(animeId);
    // Un média supprimé n'apparaît pas dans le récap du mois
    await _recordActivity(() => ref
        .read(activityRepositoryProvider)
        .removeFromCurrentMonth(uid: null, mediaId: animeId));
    ref.invalidateSelf();
    ref.invalidate(removedHistoryProvider);
    return removed;
  }

  /// Remet un titre retiré tel qu'il était (remplace l'entrée actuelle s'il
  /// a été réajouté entre-temps).
  Future<void> restore(RemovedEntry removed) async {
    await upsert(restoredEntry(removed, now: DateTime.now()));
    await restoreRemovedNotifications(removed);
    await ref
        .read(removedHistoryRepositoryProvider)
        .delete('guest', removed.mediaId);
    ref.invalidate(removedHistoryProvider);
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
