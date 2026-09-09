import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/data/firestore_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

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
    await ref
        .read(firestoreWatchlistRepositoryProvider)
        .upsertEntry(uid, entry);
  }

  Future<void> remove(int mediaId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref
        .read(firestoreWatchlistRepositoryProvider)
        .removeEntry(uid, mediaId);
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
