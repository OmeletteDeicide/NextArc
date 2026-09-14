import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Un épisode à venir dans le calendrier.
class AiringEntry {
  final MediaModel media;
  final int episode;
  final DateTime airingAt;

  const AiringEntry({
    required this.media,
    required this.episode,
    required this.airingAt,
  });
}

/// Map jour (date tronquée) → liste d'épisodes à diffuser ce jour.
/// Filtre les 14 prochains jours, trié par heure de diffusion.
final airingCalendarProvider =
    FutureProvider<Map<DateTime, List<AiringEntry>>>((ref) async {
  final user = ref
      .watch(authProvider)
      .whenOrNull(data: (a) => a.user);

  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 14));
  final result = <DateTime, List<AiringEntry>>{};

  if (user?.usesAnilistList == true) {
    // ── Chemin AniList ────────────────────────────────────────────────────────
    final groups = await ref.watch(userListProvider.future);
    for (final group in groups) {
      if (group.status != ListStatus.current &&
          group.status != ListStatus.planning) {
        continue;
      }
      for (final entry in group.entries) {
        final next = entry.media.nextAiringEpisode;
        if (next == null) continue;
        if (next.airingAt.isBefore(now) || next.airingAt.isAfter(cutoff)) {
          continue;
        }
        final day = DateTime(
            next.airingAt.year, next.airingAt.month, next.airingAt.day);
        result.putIfAbsent(day, () => []).add(AiringEntry(
              media: entry.media,
              episode: next.episode,
              airingAt: next.airingAt,
            ));
      }
    }
  } else {
    // ── Chemin Firebase-only / Invité ─────────────────────────────────────────
    List<GuestWatchlistEntry> entries;
    if (user?.hasFirebase == true) {
      entries = await ref.watch(firestoreWatchlistProvider.future);
    } else {
      entries = await ref.watch(guestWatchlistProvider.future);
    }

    // Anime uniquement (pas les manga), en cours ou prévu
    final animeIds = entries
        .where((e) =>
            !e.isManga &&
            (e.status == ListStatus.current ||
                e.status == ListStatus.planning))
        .map((e) => e.animeId)
        .toList();

    if (animeIds.isNotEmpty) {
      final airingData = await _fetchAiringForIds(animeIds);
      for (final item in airingData) {
        final media = item.media;
        final next = media.nextAiringEpisode;
        if (next == null) continue;
        if (next.airingAt.isBefore(now) || next.airingAt.isAfter(cutoff)) {
          continue;
        }
        final day = DateTime(
            next.airingAt.year, next.airingAt.month, next.airingAt.day);
        result.putIfAbsent(day, () => []).add(AiringEntry(
              media: media,
              episode: next.episode,
              airingAt: next.airingAt,
            ));
      }
    }
  }

  for (final list in result.values) {
    list.sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }

  return result;
});

class _AiringQueryResult {
  final MediaModel media;
  _AiringQueryResult(this.media);
}

/// Requête AniList publique pour récupérer nextAiringEpisode d'une liste d'ids.
Future<List<_AiringQueryResult>> _fetchAiringForIds(
    List<int> ids) async {
  const query = r'''
    query AiringCalendar($ids: [Int]) {
      Page(perPage: 50) {
        media(id_in: $ids, type: ANIME) {
          id
          title { romaji english }
          coverImage { large medium }
          nextAiringEpisode { episode airingAt }
        }
      }
    }
  ''';

  try {
    final response = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query, 'variables': {'ids': ids}}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final mediaList =
        ((data['data'] as Map?)??{})['Page']?['media'] as List? ?? [];

    return mediaList
        .whereType<Map<String, dynamic>>()
        .where((m) => m['nextAiringEpisode'] != null)
        .map((m) => _AiringQueryResult(_mediaModelFromJson(m)))
        .toList();
  } catch (_) {
    return [];
  }
}

MediaModel _mediaModelFromJson(Map<String, dynamic> m) {
  final title = m['title'] as Map<String, dynamic>? ?? {};
  final cover = m['coverImage'] as Map<String, dynamic>? ?? {};
  final nextRaw = m['nextAiringEpisode'] as Map<String, dynamic>?;

  NextAiringEpisode? next;
  if (nextRaw != null) {
    next = NextAiringEpisode(
      episode: nextRaw['episode'] as int,
      airingAt: DateTime.fromMillisecondsSinceEpoch(
          (nextRaw['airingAt'] as int) * 1000),
    );
  }

  return MediaModel(
    id: m['id'] as int,
    titleRomaji: title['romaji'] as String? ?? '',
    titleEnglish: title['english'] as String?,
    coverImageLarge: cover['large'] as String?,
    coverImageMedium: cover['medium'] as String?,
    nextAiringEpisode: next,
  );
}
