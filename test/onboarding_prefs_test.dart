import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/onboarding/domain/onboarding_prefs.dart';

void main() {
  group('shouldShowOnboarding', () {
    test('nouveau venu → affiché', () {
      expect(
        shouldShowOnboarding(
            done: false, isAuthenticated: false, hasLocalEntries: false),
        isTrue,
      );
    });

    test('déjà vu, connecté ou liste existante → jamais', () {
      expect(
        shouldShowOnboarding(
            done: true, isAuthenticated: false, hasLocalEntries: false),
        isFalse,
      );
      expect(
        shouldShowOnboarding(
            done: false, isAuthenticated: true, hasLocalEntries: false),
        isFalse,
      );
      expect(
        shouldShowOnboarding(
            done: false, isAuthenticated: false, hasLocalEntries: true),
        isFalse,
      );
    });
  });

  group('resolveContentPreference', () {
    test('la liste décide quand elle penche', () {
      expect(
        resolveContentPreference(
            animeCount: 2, mangaCount: 5, choice: ContentChoice.anime),
        'MANGA',
      );
      expect(
        resolveContentPreference(
            animeCount: 5, mangaCount: 2, choice: ContentChoice.manga),
        'ANIME',
      );
    });

    test('à égalité (liste vide) → réponse de l\'onboarding', () {
      expect(
        resolveContentPreference(
            animeCount: 0, mangaCount: 0, choice: ContentChoice.manga),
        'MANGA',
      );
      expect(
        resolveContentPreference(
            animeCount: 0, mangaCount: 0, choice: ContentChoice.both),
        'ANIME',
      );
      expect(resolveContentPreference(animeCount: 0, mangaCount: 0), 'ANIME');
    });
  });
}
