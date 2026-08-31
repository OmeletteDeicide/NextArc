import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nextarc/core/services/notification_prefs_repository.dart' show NotificationPrefsRepository, NotifEntry;
import 'package:nextarc/core/services/notification_service.dart';

/// Tâche de vérification des nouveaux épisodes/chapitres.
///
/// Conçue pour s'exécuter depuis un isolate workmanager (pas de Riverpod,
/// pas de BuildContext) ou directement depuis l'app au foreground.
///
/// Algorithme :
///  1. Lit les medias avec notifications activées (Hive)
///  2. Requête AniList pour le compteur actuel (nextAiringEpisode ou chapters)
///  3. Si le compteur a augmenté → notification locale + mise à jour du cache
class EpisodeCheckerTask {
  static const String taskName = 'episode_check';

  /// Point d'entrée pour workmanager (isolate séparé).
  static Future<bool> runInBackground() async {
    try {
      await Hive.initFlutter();
      final repo = await NotificationPrefsRepository.openInBackground();
      await NotificationService.instance.init();
      await _checkAll(repo);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Point d'entrée depuis l'app (foreground) — repo déjà initialisé.
  static Future<void> runInForeground() async {
    await _checkAll(NotificationPrefsRepository.instance);
  }

  static Future<void> _checkAll(NotificationPrefsRepository repo) async {
    final List<NotifEntry> entries = repo.getAllEnabled();
    if (entries.isEmpty) return;

    for (final entry in entries) {
      try {
        final current = await _fetchCurrentCount(entry.mediaId, entry.isManga);
        if (current == null) continue;

        final last = repo.getLastCount(entry.mediaId);
        if (current > last) {
          await NotificationService.instance.showNewContentNotification(
            mediaId: entry.mediaId,
            title: entry.title,
            count: current,
            isManga: entry.isManga,
          );
          await repo.updateLastCount(entry.mediaId, current);
        }
      } catch (_) {
        // Silencieux : on ne bloque pas les autres médias si l'un échoue
      }
    }
  }

  /// Requête AniList minimale pour un media.
  /// Retourne le nombre d'épisodes/chapitres publiés, ou null si inconnu.
  static Future<int?> _fetchCurrentCount(int mediaId, bool isManga) async {
    const endpoint = 'https://graphql.anilist.co';
    final query = isManga ? _mangaCountQuery : _animeCountQuery;

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'variables': {'id': mediaId},
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final media = (data['data'] as Map?)?.get('Media') as Map?;
    if (media == null) return null;

    if (isManga) {
      return media['chapters'] as int?;
    } else {
      // nextAiringEpisode.episode − 1 = dernier épisode sorti
      final nextAiring = media['nextAiringEpisode'] as Map?;
      if (nextAiring != null) {
        final nextEp = nextAiring['episode'] as int?;
        if (nextEp != null && nextEp > 1) return nextEp - 1;
      }
      return media['episodes'] as int?;
    }
  }

  static const String _animeCountQuery = '''
    query MediaCount(\$id: Int) {
      Media(id: \$id) {
        episodes
        nextAiringEpisode { episode }
        status
      }
    }
  ''';

  static const String _mangaCountQuery = '''
    query MediaCount(\$id: Int) {
      Media(id: \$id) {
        chapters
        status
      }
    }
  ''';
}

extension _MapExt on Map {
  dynamic get(String key) => this[key];
}
