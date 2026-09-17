import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Prochain épisode des anime non terminés d'une liste NextArc ou invité
/// (la liste AniList le contient déjà). Sert au nombre d'épisodes sortis des
/// séries en cours et à la ligne « Ép. N · jour » de Ma liste.
final listAiringProvider =
    FutureProvider<Map<int, NextAiringEpisode>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull?.user;
  if (user?.usesAnilistList == true) return const {};

  final entries = user?.hasFirebase == true
      ? await ref.watch(firestoreWatchlistProvider.future)
      : await ref.watch(guestWatchlistProvider.future);

  final ids = entries
      .where((e) =>
          !e.isManga &&
          e.status != ListStatus.completed &&
          e.status != ListStatus.dropped)
      .map((e) => e.animeId)
      .toList()
    ..sort();
  if (ids.isEmpty) return const {};
  return fetchNextAiring(ids);
});

/// Requête AniList publique, par lots de 50 identifiants. Hors ligne ou en
/// cas d'erreur, les lots concernés sont simplement ignorés.
Future<Map<int, NextAiringEpisode>> fetchNextAiring(List<int> ids) async {
  const query = r'''
    query NextAiring($ids: [Int], $page: Int) {
      Page(page: $page, perPage: 50) {
        media(id_in: $ids, type: ANIME) {
          id
          nextAiringEpisode { episode airingAt }
        }
      }
    }
  ''';

  final result = <int, NextAiringEpisode>{};
  for (var i = 0; i < ids.length; i += 50) {
    final chunk = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
    try {
      final response = await http
          .post(
            Uri.parse('https://graphql.anilist.co'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'variables': {'ids': chunk, 'page': 1},
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) continue;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final media =
          (((data['data'] as Map?)?['Page'] as Map?)?['media'] as List?) ?? [];
      for (final m in media.whereType<Map<String, dynamic>>()) {
        final id = m['id'] as int?;
        final next = NextAiringEpisode.fromJson(
            m['nextAiringEpisode'] as Map<String, dynamic>?);
        if (id != null && next != null) result[id] = next;
      }
    } catch (_) {
      // Lot ignoré : l'affichage retombe sur « ? »
    }
  }
  return result;
}
