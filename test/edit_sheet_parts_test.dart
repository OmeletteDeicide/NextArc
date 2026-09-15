import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';

void main() {
  group('scoreAfterSegmentTap', () {
    test('toucher un segment donne son numéro', () {
      expect(scoreAfterSegmentTap(0, 6), 7);
      expect(scoreAfterSegmentTap(4, 9), 10);
    });

    test('toucher la note actuelle l\'efface', () {
      expect(scoreAfterSegmentTap(7, 6), 0);
    });

    test('un demi-point AniList est remplacé par le segment touché', () {
      expect(scoreAfterSegmentTap(7.5, 6), 7);
    });
  });

  group('scoreFromPosition', () {
    test('le glissé arrondit au segment supérieur et reste borné', () {
      expect(scoreFromPosition(0, 200), 0);
      expect(scoreFromPosition(1, 200), 1);
      expect(scoreFromPosition(100, 200), 5);
      expect(scoreFromPosition(250, 200), 10);
      expect(scoreFromPosition(-20, 200), 0);
    });

    test('largeur nulle → 0', () {
      expect(scoreFromPosition(50, 0), 0);
    });
  });

  group('progressFromPosition', () {
    test('proportionnel au total et borné', () {
      expect(progressFromPosition(0, 300, 12), 0);
      expect(progressFromPosition(150, 300, 12), 6);
      expect(progressFromPosition(400, 300, 12), 12);
      expect(progressFromPosition(-5, 300, 12), 0);
    });

    test('total inconnu ou largeur nulle → 0', () {
      expect(progressFromPosition(100, 300, 0), 0);
      expect(progressFromPosition(100, 0, 12), 0);
    });
  });
}
