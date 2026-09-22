import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';

/// Bandeau « Titre retiré de ta liste · Annuler » affiché après un retrait.
/// [context] est lu tout de suite : l'écran d'origine (une fiche d'édition)
/// peut être fermé avant que l'utilisateur n'appuie sur « Annuler ».
void showRemovedSnackBar(BuildContext context, RemovedEntry removed) {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        // Avec une action, Flutter garde le bandeau affiché par défaut
        persist: false,
        content: Text(
          'removed_snackbar'.tr(namedArgs: {'title': removed.entry.title}),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'removed_undo'.tr(),
          onPressed: () => _restore(container, removed),
        ),
      ),
    );
}

/// Restaure un titre depuis l'historique. S'il a été réajouté entre-temps,
/// demande d'abord confirmation : ce qui a été saisi depuis sera remplacé.
/// Renvoie true si le titre a été restauré.
Future<bool> restoreRemovedEntry(
  BuildContext context,
  RemovedEntry removed,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final current = _currentList(container);
  if (restoreWouldOverwrite(removed, current)) {
    final confirmed = await showConfirmDialog(
      context,
      title: 'removed_conflict_title'.tr(),
      message: 'removed_conflict_body'
          .tr(namedArgs: {'title': removed.entry.title}),
      confirmLabel: 'removed_conflict_confirm'.tr(),
    );
    if (!confirmed) return false;
  }
  await _restore(container, removed);
  return true;
}

Future<void> _restore(ProviderContainer container, RemovedEntry removed) async {
  final user = container.read(authProvider).valueOrNull?.user;
  if (user?.hasFirebase == true) {
    await container.read(firestoreWatchlistProvider.notifier).restore(removed);
  } else {
    await container.read(guestWatchlistProvider.notifier).restore(removed);
  }
}

List<GuestWatchlistEntry> _currentList(ProviderContainer container) {
  final user = container.read(authProvider).valueOrNull?.user;
  return user?.hasFirebase == true
      ? container.read(firestoreWatchlistProvider).valueOrNull ?? const []
      : container.read(guestWatchlistProvider).valueOrNull ?? const [];
}
