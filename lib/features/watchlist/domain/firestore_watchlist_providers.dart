import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/features/activity/domain/activity_providers.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/data/firestore_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';
import 'package:nextarc/features/watchlist/domain/removed_history_providers.dart';

final firestoreWatchlistRepositoryProvider =
    Provider((_) => FirestoreWatchlistRepository());

/// Notifier temps-réel basé sur un stream Firestore.
class FirestoreWatchlistNotifier
    extends StreamNotifier<List<GuestWatchlistEntry>> {
  @override
  Stream<List<GuestWatchlistEntry>> build() {
    final uid =
        ref.watch(authProvider).whenOrNull(data: (a) => a.user?.firebaseUid);
    if (uid == null) return Stream.value([]);
    return ref
        .read(firestoreWatchlistRepositoryProvider)
        .watchEntries(uid);
  }

  String? get _uid =>
      ref.read(authProvider).whenOrNull(data: (a) => a.user?.firebaseUid);

  Future<void> upsert(GuestWatchlistEntry entry) async {
    final uid = _uid;
    if (uid == null) return;
    final before =
        state.value?.where((e) => e.animeId == entry.animeId).firstOrNull;
    await ref
        .read(firestoreWatchlistRepositoryProvider)
        .upsertEntry(uid, entry);
    await _recordActivity(() => ref
        .read(activityRepositoryProvider)
        .record(uid: uid, before: before, after: entry));
  }

  /// Le journal d'activité ne doit jamais faire échouer une modification.
  Future<void> _recordActivity(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(monthlyRecapProvider);
    } catch (_) {}
  }

  /// Retire un titre et le garde dans l'historique de l'appareil (le serveur
  /// n'en garde que la trace de suppression). Renvoie l'entrée retirée.
  Future<RemovedEntry?> remove(int mediaId) async {
    final uid = _uid;
    if (uid == null) return null;
    final entry =
        state.value?.where((e) => e.animeId == mediaId).firstOrNull;
    final removed = entry == null
        ? null
        : RemovedEntry(
            entry: entry,
            removedAt: DateTime.now(),
            notificationsEnabled:
                NotificationPrefsRepository.instance.isEnabled(mediaId),
          );
    if (removed != null) {
      await ref.read(removedHistoryRepositoryProvider).record(uid, removed);
    }
    await ref
        .read(firestoreWatchlistRepositoryProvider)
        .removeEntry(uid, mediaId);
    // Plus dans la liste → plus de notifications d'épisodes pour ce média
    await NotificationPrefsRepository.instance.disable(mediaId);
    // Un média supprimé n'apparaît pas dans le récap du mois
    await _recordActivity(() => ref
        .read(activityRepositoryProvider)
        .removeFromCurrentMonth(uid: uid, mediaId: mediaId));
    ref.invalidate(removedHistoryProvider);
    return removed;
  }

  /// Remet un titre retiré tel qu'il était (remplace l'entrée actuelle s'il
  /// a été réajouté entre-temps).
  Future<void> restore(RemovedEntry removed) async {
    final uid = _uid;
    if (uid == null) return;
    await upsert(restoredEntry(removed, now: DateTime.now()));
    await restoreRemovedNotifications(removed);
    await ref.read(removedHistoryRepositoryProvider).delete(uid, removed.mediaId);
    ref.invalidate(removedHistoryProvider);
  }
}

final firestoreWatchlistProvider = StreamNotifierProvider<
    FirestoreWatchlistNotifier, List<GuestWatchlistEntry>>(
  FirestoreWatchlistNotifier.new,
);

/// Retourne l'entrée Firestore pour un média donné (ou null).
final firestoreListEntryProvider =
    Provider.family<GuestWatchlistEntry?, int>((ref, mediaId) {
  return ref.watch(firestoreWatchlistProvider).whenOrNull(
        data: (entries) =>
            entries.where((e) => e.animeId == mediaId).firstOrNull,
      );
});
