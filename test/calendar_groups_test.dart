import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/calendar/domain/calendar_groups.dart';

typedef _Release = ({String title, DateTime at});

void main() {
  // Mercredi 16 septembre 2026, 15 h
  final now = DateTime(2026, 9, 16, 15);

  CalendarLayout<_Release> layout(List<_Release> items) =>
      buildCalendarLayout(items, airingAt: (r) => r.at, now: now);

  test('la prochaine sortie du jour est mise en avant, pas répétée', () {
    final l = layout([
      (title: 'B', at: DateTime(2026, 9, 16, 20)),
      (title: 'A', at: DateTime(2026, 9, 16, 17)),
    ]);
    expect(l.pinned!.title, 'A');
    expect(l.weeks.single.week, CalendarWeek.thisWeek);
    expect(l.weeks.single.days.single.items.single.title, 'B');
  });

  test('semaines lundi → dimanche, seulement les jours avec sorties', () {
    final l = layout([
      (title: 'Jeudi', at: DateTime(2026, 9, 17, 17)),
      (title: 'Dimanche', at: DateTime(2026, 9, 20, 9)),
      (title: 'Lundi', at: DateTime(2026, 9, 21, 23)),
      (title: 'Lundi +7', at: DateTime(2026, 9, 28, 12)),
    ]);
    expect(l.pinned, isNull);
    expect(l.weeks.map((w) => w.week), [
      CalendarWeek.thisWeek,
      CalendarWeek.nextWeek,
      CalendarWeek.later,
    ]);
    expect(l.weeks.first.days.length, 2);
    expect(l.weeks.first.count, 2);
    expect(l.weeks[1].days.single.date, DateTime(2026, 9, 21));
  });

  test('plusieurs sorties le même jour, par heure', () {
    final l = layout([
      (title: 'Soir', at: DateTime(2026, 9, 19, 18)),
      (title: 'Matin', at: DateTime(2026, 9, 19, 9)),
    ]);
    expect(
      l.weeks.single.days.single.items.map((r) => r.title),
      ['Matin', 'Soir'],
    );
  });

  test('rien à venir → vide', () {
    expect(layout(const []).isEmpty, isTrue);
  });
}
