import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/title_promotion.dart';
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
  test('un anime de plus sans franchir de seuil → rien', () {
    expect(
      titlePromotion(before: _title(anime: 3), after: _title(anime: 4)),
      isNull,
    );
  });

  test('passage de Curieux à Spectateur → nouveau nom', () {
    expect(
      titlePromotion(before: _title(anime: 9), after: _title(anime: 10)),
      TitlePromotionKind.rank,
    );
  });

  test('passage à 100 h → nouveau qualificatif', () {
    expect(
      titlePromotion(
          before: _title(watchHours: 99), after: _title(watchHours: 100)),
      TitlePromotionKind.qualifier,
    );
  });

  test('nom et qualificatif en même temps → le nom l\'emporte', () {
    expect(
      titlePromotion(
        before: _title(anime: 9, watchHours: 99),
        after: _title(anime: 10, watchHours: 100),
      ),
      TitlePromotionKind.rank,
    );
  });

  test('une baisse n\'est jamais célébrée', () {
    expect(
      titlePromotion(before: _title(anime: 10), after: _title(anime: 9)),
      isNull,
    );
  });

  test('devenir Arcer → titre ultime, et plus rien ensuite', () {
    final almost =
        _title(anime: 1000, manga: 499, watchHours: 9000, readHours: 3000);
    final arcer =
        _title(anime: 1000, manga: 500, watchHours: 9000, readHours: 3000);
    expect(titlePromotion(before: almost, after: arcer),
        TitlePromotionKind.arcer);

    final more =
        _title(anime: 1100, manga: 500, watchHours: 10000, readHours: 3000);
    expect(titlePromotion(before: arcer, after: more), isNull);
  });
}
