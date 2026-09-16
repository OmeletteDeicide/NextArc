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

  group('evaluateTitleLevel (palier mémorisé par compte)', () {
    TitleLevel level(UserTitle t) => TitleLevel.of(t);

    test('nouveau compte au tout premier palier → rien, palier mémorisé', () {
      final r = evaluateTitleLevel(stored: null, current: level(_title()));
      expect(r.celebrate, isNull);
      expect(r.store.isLowest, isTrue);
    });

    test('utilisateur existant sans palier mémorisé → une seule carte', () {
      final current = level(_title(anime: 120, watchHours: 1200));
      final r = evaluateTitleLevel(stored: null, current: current);
      expect(r.celebrate, TitlePromotionKind.rank);
      expect(r.store.encode(), current.encode());

      // Relancé ensuite avec le même titre : plus rien
      final again = evaluateTitleLevel(stored: r.store, current: current);
      expect(again.celebrate, isNull);
    });

    test('reconnexion : liste vide le temps du chargement puis complète', () {
      final stored = level(_title(anime: 30));
      final empty =
          evaluateTitleLevel(stored: stored, current: level(_title()));
      expect(empty.celebrate, isNull);
      // La baisse passagère n'efface pas le palier mémorisé
      expect(empty.store.encode(), stored.encode());

      final full =
          evaluateTitleLevel(stored: empty.store, current: stored);
      expect(full.celebrate, isNull);
    });

    test('vrai nouveau palier → célébré une fois', () {
      final stored = level(_title(anime: 9));
      final r = evaluateTitleLevel(
          stored: stored, current: level(_title(anime: 10)));
      expect(r.celebrate, TitlePromotionKind.rank);
      expect(
        evaluateTitleLevel(stored: r.store, current: level(_title(anime: 10)))
            .celebrate,
        isNull,
      );
    });

    test('encode / decode', () {
      const l = TitleLevel(rank: 3, qualifier: 2, arcer: true);
      final back = TitleLevel.decode(l.encode())!;
      expect(back.rank, 3);
      expect(back.qualifier, 2);
      expect(back.arcer, isTrue);
      expect(TitleLevel.decode('abc'), isNull);
      expect(TitleLevel.decode(null), isNull);
    });
  });
}
