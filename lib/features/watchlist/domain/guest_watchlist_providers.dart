import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/watchlist/data/guest_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

final guestWatchlistRepositoryProvider =
    Provider((_) => GuestWatchlistRepository());

class GuestWatchlistNotifier
    extends AsyncNotifier<List<GuestWatchlistEntry>> {
  @override
  Future<List<GuestWatchlistEntry>> build() {
    return ref.read(guestWatchlistRepositoryProvider).getEntries();
  }

  Future<void> upsert(GuestWatchlistEntry entry) async {
    await ref.read(guestWatchlistRepositoryProvider).upsertEntry(entry);
    ref.invalidateSelf();
  }

  Future<void> remove(int animeId) async {
    await ref.read(guestWatchlistRepositoryProvider).removeEntry(animeId);
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
