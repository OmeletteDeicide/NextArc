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
    // Coupé dans Paramètres → Notifications
    if (!repo.episodeReleasesEnabled) return;
    final List<NotifEntry> entries = repo.getAllEnabled();
    if (entries.isEmpty) return;

    for (final entry in entries) {
      try {
        final info = await _fetchMediaInfo(entry.mediaId, entry.isManga);
        if (info == null) continue;

        final last = repo.getLastCount(entry.mediaId);
        if (info.currentCount != null && info.currentCount! > last) {
          await NotificationService.instance.showNewContentNotification(
            mediaId: entry.mediaId,
            title: entry.title,
            count: info.currentCount!,
            isManga: entry.isManga,
          );
          await repo.updateLastCount(entry.mediaId, info.currentCount!);
        }

        // Programme une notification précise pour le prochain épisode
        if (!entry.isManga &&
            info.nextAiringAt != null &&
            info.nextEpisode != null) {
          await NotificationService.instance.scheduleNextEpisodeNotification(
            mediaId: entry.mediaId,
            title: entry.title,
            episode: info.nextEpisode!,
            airingAt: info.nextAiringAt!,
          );
        }
      } catch (_) {
        // Silencieux : on ne bloque pas les autres médias si l'un échoue
      }
    }
  }

  /// Requête AniList minimale pour un media.
  /// Retourne les infos du media : compteur actuel, prochain épisode et timestamp.
  static Future<_MediaInfo?> _fetchMediaInfo(int mediaId, bool isManga) async {
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
      return _MediaInfo(currentCount: media['chapters'] as int?);
    } else {
      final nextAiring = media['nextAiringEpisode'] as Map?;
      int? currentCount;
      int? nextEpisode;
      DateTime? nextAiringAt;

      if (nextAiring != null) {
        final nextEp = nextAiring['episode'] as int?;
        final airingAtSec = nextAiring['airingAt'] as int?;
        if (nextEp != null && nextEp > 1) currentCount = nextEp - 1;
        nextEpisode = nextEp;
        if (airingAtSec != null) {
          nextAiringAt =
              DateTime.fromMillisecondsSinceEpoch(airingAtSec * 1000);
        }
      }
      currentCount ??= media['episodes'] as int?;

      return _MediaInfo(
        currentCount: currentCount,
        nextEpisode: nextEpisode,
        nextAiringAt: nextAiringAt,
      );
    }
  }

  static const String _animeCountQuery = '''
    query MediaCount(\$id: Int) {
      Media(id: \$id) {
        episodes
        nextAiringEpisode { episode airingAt }
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

class _MediaInfo {
  final int? currentCount;
  final int? nextEpisode;
  final DateTime? nextAiringAt;

  const _MediaInfo({this.currentCount, this.nextEpisode, this.nextAiringAt});
}

extension _MapExt on Map {
  dynamic get(String key) => this[key];
}
