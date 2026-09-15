import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

UserTitle _title({int anime = 0, int watchHours = 0}) => UserTitle.from(
      animeCompleted: anime,
      mangaCompleted: 0,
      watchMinutes: watchHours * 60,
      readMinutes: 0,
    );

void main() {
  group('jauge du nom', () {
    test('Curieux avec 2 anime → prochain Spectateur à 10', () {
      final t = _title(anime: 2);
      expect(t.rankIndex, 0);
      expect(t.nextRankThreshold, 10);
      expect(t.rankProgress, closeTo(0.2, 1e-9));
    });

    test('pile sur un seuil → palier atteint', () {
      final t = _title(anime: 25);
      expect(t.rankKey, 'title_rank_explorer');
      expect(t.nextRankThreshold, 50);
    });

    test('Légende → plus de seuil, jauge pleine', () {
      final t = _title(anime: 1200);
      expect(t.nextRankThreshold, isNull);
      expect(t.rankProgress, 1);
    });
  });

  group('jauge du qualificatif', () {
    test('Petit à 9 h → 100 h fait perdre le mot', () {
      final t = _title(watchHours: 9);
      expect(t.nextQualifierThreshold, 100);
      expect(t.nextQualifierKey, isNull);
      expect(t.nextQualifierDropsWord, isTrue);
      expect(t.qualifierProgress, closeTo(0.09, 1e-9));
    });

    test('sans qualificatif à 150 h → prochain Grand à 400 h', () {
      final t = _title(watchHours: 150);
      expect(t.qualifierKey, isNull);
      expect(t.nextQualifierKey, 'title_qual_great');
      expect(t.nextQualifierDropsWord, isFalse);
    });

    test('Divin → plus de seuil, jauge pleine', () {
      final t = _title(watchHours: 12000);
      expect(t.nextQualifierThreshold, isNull);
      expect(t.qualifierProgress, 1);
      expect(t.nextQualifierDropsWord, isFalse);
    });
  });
}
