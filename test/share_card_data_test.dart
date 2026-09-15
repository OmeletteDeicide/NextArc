import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/share/domain/share_card_data.dart';

void main() {
  group('meanScoreOf', () {
    test('ignore les notes absentes ou à 0', () {
      expect(meanScoreOf([8, null, 0, 9]), 8.5);
    });

    test('aucune note → null', () {
      expect(meanScoreOf([null, 0]), isNull);
      expect(meanScoreOf(const []), isNull);
    });
  });

  group('formatCardScore', () {
    test('virgule hors anglais, tiret sans note', () {
      expect(formatCardScore(8.26, languageCode: 'fr'), '8,3');
      expect(formatCardScore(8.26, languageCode: 'en'), '8.3');
      expect(formatCardScore(null, languageCode: 'fr'), '—');
    });
  });

  test('coverRank sur deux chiffres', () {
    expect(coverRank(0), '01');
    expect(coverRank(9), '10');
  });
}
