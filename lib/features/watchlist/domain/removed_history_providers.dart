import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/services/notification_prefs_repository.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/data/removed_history_repository.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';

final removedHistoryRepositoryProvider =
    Provider((_) => RemovedHistoryRepository());

/// Liste concernée par l'historique : le compte NextArc, sinon la liste
/// invité. Null pour une session AniList seule (la suppression y passe par
/// AniList et n'est pas historisée).
final removedHistoryOwnerProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).valueOrNull?.user;
  if (user?.hasFirebase == true) return user!.firebaseUid;
  if (user?.usesAnilistList == true) return null;
  return 'guest';
});

/// Réactive le rappel de sortie s'il était actif avant le retrait.
Future<void> restoreRemovedNotifications(RemovedEntry removed) async {
  if (!removed.notificationsEnabled) return;
  await NotificationPrefsRepository.instance.enable(
    removed.mediaId,
    title: removed.entry.title,
    isManga: removed.entry.isManga,
  );
}

/// Titres retirés restaurables de la liste affichée.
final removedHistoryProvider = FutureProvider<List<RemovedEntry>>((ref) async {
  final owner = ref.watch(removedHistoryOwnerProvider);
  if (owner == null) return const [];
  return ref.read(removedHistoryRepositoryProvider).list(owner);
});
