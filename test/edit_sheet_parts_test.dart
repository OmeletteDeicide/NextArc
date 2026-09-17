import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/watchlist/presentation/edit_sheet_parts.dart';

void main() {
  group('scoreAfterTap', () {
    test('toucher une note la pose', () {
      expect(scoreAfterTap(0, 7), 7);
      expect(scoreAfterTap(4, 6.5), 6.5);
    });

    test("toucher la note actuelle l'efface", () {
      expect(scoreAfterTap(7.5, 7.5), 0);
    });
  });

  group('scoreFromPosition', () {
    // Barre de 200 px : 10 segments de 20 px (le 7e va de 120 à 140)
    test("moitié gauche d'un segment → demi-point, moitié droite → entier", () {
      expect(scoreFromPosition(1, 200), 0.5);
      expect(scoreFromPosition(9, 200), 0.5);
      expect(scoreFromPosition(11, 200), 1);
      expect(scoreFromPosition(125, 200), 6.5);
      expect(scoreFromPosition(131, 200), 7);
      expect(scoreFromPosition(122, 200), 6.5);
    });

    test('bornée entre 0,5 et 10', () {
      expect(scoreFromPosition(0, 200), 0.5);
      expect(scoreFromPosition(-20, 200), 0.5);
      expect(scoreFromPosition(250, 200), 10);
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
