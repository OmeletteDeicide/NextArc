import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:nextarc/core/services/episode_checker_task.dart';
import 'package:nextarc/core/services/notification_service.dart';

/// Stocke les préférences de notification par media (anime ou manga).
///
/// Persiste dans Hive pour être accessible depuis la tâche de fond (workmanager)
/// sans dépendre de Riverpod ou du contexte Flutter.
class NotificationPrefsRepository {
  static const _boxName = 'notif_prefs';
  static const _titlesBoxName = 'notif_titles';
  static const _countsBoxName = 'notif_counts';
  static const _isMangaBoxName = 'notif_is_manga';
  static const _settingsBoxName = 'notif_settings';
  static const _scheduledBoxName = 'notif_scheduled';
  static const _episodeReleasesKey = 'episode_releases';
  static const _monthlyRecapKey = 'monthly_recap';

  static NotificationPrefsRepository? _instance;
  static NotificationPrefsRepository get instance =>
      _instance ??= NotificationPrefsRepository._();
  NotificationPrefsRepository._();

  late Box<bool> _prefsBox;
  late Box<String> _titlesBox;
  late Box<int> _countsBox;
  late Box<bool> _isMangaBox;
  late Box<bool> _settingsBox;

  /// Épisode dont la notification est programmée à l'heure de sortie, pour
  /// ne pas l'annoncer une seconde fois lors de la vérification périodique.
  late Box<int> _scheduledBox;

  Future<void> init() async {
    _prefsBox = await Hive.openBox<bool>(_boxName);
    _titlesBox = await Hive.openBox<String>(_titlesBoxName);
    _countsBox = await Hive.openBox<int>(_countsBoxName);
    _isMangaBox = await Hive.openBox<bool>(_isMangaBoxName);
    _settingsBox = await Hive.openBox<bool>(_settingsBoxName);
    _scheduledBox = await Hive.openBox<int>(_scheduledBoxName);
  }

  // ── Réglages généraux (Paramètres → Notifications) ────────────────────────

  /// Notifications de sortie d'épisodes / chapitres, tous médias confondus.
  /// Désactivé : les rappels par média sont conservés mais rien n'est envoyé.
  bool get episodeReleasesEnabled =>
      _settingsBox.get(_episodeReleasesKey) ?? true;

  Future<void> setEpisodeReleasesEnabled(bool enabled) async {
    await _settingsBox.put(_episodeReleasesKey, enabled);
    for (final entry in getAllEnabled()) {
      if (enabled) {
        unawaited(EpisodeCheckerTask.checkMedia(entry.mediaId));
      } else {
        await _cancelScheduled(entry.mediaId);
      }
    }
  }

  /// Proposition du récap du mois précédent en début de mois.
  bool get monthlyRecapEnabled => _settingsBox.get(_monthlyRecapKey) ?? true;

  Future<void> setMonthlyRecapEnabled(bool enabled) =>
      _settingsBox.put(_monthlyRecapKey, enabled);

  bool isEnabled(int mediaId) => _prefsBox.get(mediaId.toString()) ?? false;

  Future<void> enable(int mediaId, {
    required String title,
    required bool isManga,
    int? currentCount,
  }) async {
    await _prefsBox.put(mediaId.toString(), true);
    await _titlesBox.put(mediaId.toString(), title);
    await _isMangaBox.put(mediaId.toString(), isManga);
    if (currentCount != null) {
      await _countsBox.put(mediaId.toString(), currentCount);
    }
    // Relève le dernier épisode réellement sorti et programme tout de suite le
    // suivant, sans attendre la prochaine vérification en arrière-plan
    unawaited(EpisodeCheckerTask.checkMedia(mediaId));
  }

  Future<void> disable(int mediaId) async {
    await _prefsBox.delete(mediaId.toString());
    await _cancelScheduled(mediaId);
  }

  Future<void> _cancelScheduled(int mediaId) async {
    await _scheduledBox.delete(mediaId.toString());
    try {
      await NotificationService.instance.cancelNextEpisodeNotification(mediaId);
    } catch (_) {
      // Plugin indisponible : rien de programmé à annuler
    }
  }

  int? getScheduledEpisode(int mediaId) =>
      _scheduledBox.get(mediaId.toString());

  Future<void> setScheduledEpisode(int mediaId, int episode) =>
      _scheduledBox.put(mediaId.toString(), episode);

  Future<void> toggle(int mediaId, {
    required String title,
    required bool isManga,
    int? currentCount,
  }) async {
    if (isEnabled(mediaId)) {
      await disable(mediaId);
    } else {
      await enable(mediaId, title: title, isManga: isManga, currentCount: currentCount);
    }
  }

  /// Retourne toutes les entrées avec notifications activées.
  List<NotifEntry> getAllEnabled() {
    return _prefsBox.keys
        .where((k) => _prefsBox.get(k) == true)
        .map((k) => NotifEntry(
              mediaId: int.tryParse(k.toString()) ?? 0,
              title: _titlesBox.get(k.toString()) ?? '',
              isManga: _isMangaBox.get(k.toString()) ?? false,
              lastCount: _countsBox.get(k.toString()) ?? 0,
            ))
        .where((e) => e.mediaId != 0)
        .toList();
  }

  Future<void> updateLastCount(int mediaId, int count) async {
    await _countsBox.put(mediaId.toString(), count);
  }

  int getLastCount(int mediaId) => _countsBox.get(mediaId.toString()) ?? 0;

  /// Ouvre les boxes dans un isolate de fond (workmanager).
  static Future<NotificationPrefsRepository> openInBackground() async {
    final repo = NotificationPrefsRepository._();
    repo._prefsBox = await Hive.openBox<bool>(_boxName);
    repo._titlesBox = await Hive.openBox<String>(_titlesBoxName);
    repo._countsBox = await Hive.openBox<int>(_countsBoxName);
    repo._isMangaBox = await Hive.openBox<bool>(_isMangaBoxName);
    repo._settingsBox = await Hive.openBox<bool>(_settingsBoxName);
    repo._scheduledBox = await Hive.openBox<int>(_scheduledBoxName);
    return repo;
  }
}

class NotifEntry {
  final int mediaId;
  final String title;
  final bool isManga;
  final int lastCount;

  const NotifEntry({
    required this.mediaId,
    required this.title,
    required this.isManga,
    required this.lastCount,
  });
}
