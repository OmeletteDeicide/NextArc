import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/presentation/guest_watchlist_edit_sheet.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_edit_sheet.dart';

/// Ouvre le bon sheet (AniList ou invité) selon l'état de connexion.
void openWatchlistSheet(
  BuildContext context,
  WidgetRef ref, {
  required MediaModel anime,
  required bool isLoggedIn,
}) {
  final totalCount = anime.isManga ? anime.chapters : anime.episodes;

  if (isLoggedIn) {
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
