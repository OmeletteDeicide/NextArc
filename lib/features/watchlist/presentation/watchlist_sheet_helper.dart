import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/presentation/firestore_watchlist_edit_sheet.dart';
import 'package:nextarc/features/watchlist/presentation/guest_watchlist_edit_sheet.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_edit_sheet.dart';

/// Ouvre le bon sheet selon l'état de connexion :
/// - AniList sans compte NextArc (usesAnilistList) → sheet AniList
/// - Compte NextArc (hasFirebase, AniList lié ou non) → sheet Firestore
/// - Invité → sheet local
void openWatchlistSheet(
  BuildContext context,
  WidgetRef ref, {
  required MediaModel anime,
  required UserModel? user,
}) {
  HapticFeedback.lightImpact();
  final totalCount = anime.isManga ? anime.chapters : anime.episodes;

  if (user?.usesAnilistList == true) {
    showWatchlistEditSheet(
      context,
      ref,
      animeId: anime.id,
      animeTitle: anime.displayTitle,
      totalEpisodes: totalCount,
      startDate: anime.startDate,
      existing: ref.read(userListEntryProvider(anime.id)),
      isManga: anime.isManga,
    );
  } else if (user?.hasFirebase == true) {
    showFirestoreWatchlistEditSheet(
      context,
      ref,
      animeId: anime.id,
      animeTitle: anime.displayTitle,
      coverImage: anime.coverImage,
      totalEpisodes: totalCount,
      existing: ref.read(firestoreListEntryProvider(anime.id)),
      isManga: anime.isManga,
    );
  } else {
    showGuestWatchlistEditSheet(
      context,
      ref,
      animeId: anime.id,
      animeTitle: anime.displayTitle,
      coverImage: anime.coverImage,
      totalEpisodes: totalCount,
      existing: ref.read(guestListEntryProvider(anime.id)),
      isManga: anime.isManga,
    );
  }
}
