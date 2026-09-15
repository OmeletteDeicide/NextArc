import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

UserTitle _title({
  int anime = 0,
  int manga = 0,
  int watchHours = 0,
  int readHours = 0,
}) =>
    UserTitle.from(
      animeCompleted: anime,
      mangaCompleted: manga,
      watchMinutes: watchHours * 60,
      readMinutes: readHours * 60,
    );

void main() {
  group('Route vers Arcer', () {
    test('jauges : anime + manga et visionnage + lecture, bornées à 1', () {
      final t = _title(anime: 100, manga: 50, watchHours: 1000, readHours: 200);
      expect(t.arcerCompletedProgress, closeTo(150 / 1500, 1e-9));
      expect(t.arcerHoursProgress, closeTo(1200 / 12000, 1e-9));

      final max = _title(anime: 3000, watchHours: 20000);
      expect(max.arcerCompletedProgress, 1);
      expect(max.arcerHoursProgress, 1);
    });

    test('compte vide : jauges à 0, palier 1', () {
      final t = _title();
      expect(t.arcerCompletedProgress, 0);
      expect(t.arcerHoursProgress, 0);
      expect(t.tier, 1);
    });

    test('le palier suit le qualificatif (heures de visionnage)', () {
      expect(_title(watchHours: 99).tier, 1);
      expect(_title(watchHours: 100).tier, 2);
      expect(_title(watchHours: 400).tier, 3);
      expect(_title(watchHours: 10000).tier, UserTitle.tierCount);
    });

    test('un Arcer est au dernier palier', () {
      final t = _title(anime: 1000, manga: 500, watchHours: 9000, readHours: 3000);
      expect(t.isArcer, isTrue);
      expect(t.tier, UserTitle.tierCount);
    });
  });
}
