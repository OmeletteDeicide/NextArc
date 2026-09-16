/// Regroupement des sorties du calendrier : une sortie mise en avant
/// aujourd'hui, puis des semaines (« Cette semaine », « Semaine prochaine »,
/// « Plus tard ») contenant uniquement les jours qui ont des sorties.
library;

enum CalendarWeek { thisWeek, nextWeek, later }

/// Jour et ses sorties (heure croissante).
class CalendarDay<T> {
  const CalendarDay({required this.date, required this.items});

  /// Date à minuit.
  final DateTime date;
  final List<T> items;
}

class CalendarWeekGroup<T> {
  const CalendarWeekGroup({required this.week, required this.days});

  final CalendarWeek week;
  final List<CalendarDay<T>> days;

  int get count => days.fold(0, (sum, d) => sum + d.items.length);
}

class CalendarLayout<T> {
  const CalendarLayout({required this.pinned, required this.weeks});

  /// Prochaine sortie du jour, mise en avant (null s'il n'y en a pas).
  final T? pinned;
  final List<CalendarWeekGroup<T>> weeks;

  bool get isEmpty => pinned == null && weeks.isEmpty;
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Construit la mise en page du calendrier. Les semaines commencent le lundi.
CalendarLayout<T> buildCalendarLayout<T>(
  Iterable<T> items, {
  required DateTime Function(T) airingAt,
  required DateTime now,
}) {
  final sorted = items.toList()
    ..sort((a, b) => airingAt(a).compareTo(airingAt(b)));

  final today = _midnight(now);
  final todayItems =
      sorted.where((i) => _midnight(airingAt(i)) == today).toList();
  final pinned = todayItems.isEmpty ? null : todayItems.first;

  // Lundi de la semaine prochaine, puis celui d'après
  final nextWeekStart = today.add(Duration(days: 8 - today.weekday));
  final laterStart = nextWeekStart.add(const Duration(days: 7));

  CalendarWeek weekOf(DateTime date) {
    if (date.isBefore(nextWeekStart)) return CalendarWeek.thisWeek;
    if (date.isBefore(laterStart)) return CalendarWeek.nextWeek;
    return CalendarWeek.later;
  }

  final weeks = <CalendarWeekGroup<T>>[];
  for (final week in CalendarWeek.values) {
    final byDay = <DateTime, List<T>>{};
    for (final item in sorted) {
      if (identical(item, pinned)) continue;
      final day = _midnight(airingAt(item));
      if (weekOf(day) != week) continue;
      byDay.putIfAbsent(day, () => []).add(item);
    }
    if (byDay.isEmpty) continue;
    weeks.add(CalendarWeekGroup(
      week: week,
      days: [
        for (final entry in byDay.entries)
          CalendarDay(date: entry.key, items: entry.value),
      ],
    ));
  }

  return CalendarLayout(pinned: pinned, weeks: weeks);
}
