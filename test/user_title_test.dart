import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

UserTitle title({
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
  test('débutant : Petit Curieux', () {
    final t = title();
    expect(t.rankKey, 'title_rank_curious');
    expect(t.qualifierKey, 'title_qual_little');
    expect(t.isArcer, isFalse);
  });

  test('paliers atteints exactement', () {
    final t = title(anime: 150, watchHours: 400);
    expect(t.rankKey, 'title_rank_achiever');
    expect(t.qualifierKey, 'title_qual_great');
  });

  test('entre 100 h et 400 h : pas de qualificatif', () {
    expect(title(anime: 30, watchHours: 150).qualifierKey, isNull);
  });

  test('maximum hors Arcer : Légende Divin', () {
    final t = title(anime: 1200, watchHours: 10000);
    expect(t.rankKey, 'title_rank_legend');
    expect(t.qualifierKey, 'title_qual_divine');
    expect(t.isArcer, isFalse);
  });

  test('Arcer cumule anime + manga et visionnage + lecture', () {
    expect(
      title(anime: 1000, manga: 500, watchHours: 9000, readHours: 3000).isArcer,
      isTrue,
    );
    expect(
      title(anime: 1000, manga: 499, watchHours: 9000, readHours: 3000).isArcer,
      isFalse,
    );
    expect(
      title(anime: 1000, manga: 500, watchHours: 9000, readHours: 2999).isArcer,
      isFalse,
    );
  });
}
