import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service de notifications locales pour les sorties d'anime.
///
/// Deux notifications sont programmées quand un anime "Prévu" a une date connue :
///  - J-7 : "sort dans une semaine"
///  - J-0 : "sort aujourd'hui"
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'anime_releases';
  static const _channelName = 'Sorties d\'anime';
  static const _channelDesc = 'Notifications de sortie des anime prévus';

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
  }

  /// Demande la permission de notifications (Android 13+).
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Programme les notifications J-7 et J-0 pour un anime.
  ///
  /// [animeId]    — utilisé comme base pour les ids de notif (animeId*2 et animeId*2+1)
  /// [title]      — titre de l'anime
  /// [startDate]  — date de sortie
  Future<void> scheduleReleaseNotifications({
    required int animeId,
    required String title,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();
    final releaseDay = DateTime(startDate.year, startDate.month, startDate.day);
    final weekBefore = releaseDay.subtract(const Duration(days: 7));

    // Notification J-7 (seulement si dans le futur)
    if (weekBefore.isAfter(now)) {
      await _scheduleNotif(
        id: animeId * 2,
        title: '📅 Sortie dans une semaine',
        body: '$title sort le ${_formatDate(releaseDay)}',
        scheduledDate: weekBefore.copyWith(hour: 9, minute: 0, second: 0),
      );
    }

    // Notification J-0 (seulement si dans le futur)
    if (releaseDay.isAfter(now)) {
      await _scheduleNotif(
        id: animeId * 2 + 1,
        title: '🎉 Sortie aujourd\'hui !',
        body: '$title est disponible !',
        scheduledDate: releaseDay.copyWith(hour: 9, minute: 0, second: 0),
      );
    }
  }

  /// Annule les notifications d'un anime (utile si retiré de la liste "Prévu").
  Future<void> cancelReleaseNotifications(int animeId) async {
    await _plugin.cancel(animeId * 2);
    await _plugin.cancel(animeId * 2 + 1);
  }

  Future<void> _scheduleNotif({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
