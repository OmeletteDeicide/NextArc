import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/discover/domain/discover_hero.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';

final now = DateTime(2026, 9, 15, 12);

MediaModel media(int id, {Duration? airsIn, String? banner}) => MediaModel(
      id: id,
      titleRomaji: 'Media $id',
      bannerImage: banner,
      nextAiringEpisode: airsIn == null
          ? null
          : NextAiringEpisode(episode: 5, airingAt: now.add(airsIn)),
    );

void main() {
  group('pickDiscoverHero', () {
    test('aucun candidat → rien', () {
      expect(
        pickDiscoverHero(candidates: const [], listIds: const {}, now: now),
        isNull,
      );
    });

    test('un média de la liste passe avant un épisode plus proche', () {
      final hero = pickDiscoverHero(
        candidates: [
          media(1, airsIn: const Duration(hours: 2)),
          media(2, airsIn: const Duration(days: 3)),
        ],
        listIds: {2},
        now: now,
      )!;
      expect(hero.media.id, 2);
      expect(hero.kind, DiscoverHeroKind.upcoming);
    });

    test('sans liste : l\'épisode le plus proche, « du jour » sous 24 h', () {
      final hero = pickDiscoverHero(
        candidates: [
          media(1, airsIn: const Duration(days: 2)),
          media(2, airsIn: const Duration(hours: 5)),
        ],
        listIds: const {},
        now: now,
      )!;
      expect(hero.media.id, 2);
      expect(hero.kind, DiscoverHeroKind.today);
    });

    test('à délai égal, le média avec bannière est préféré', () {
      final hero = pickDiscoverHero(
        candidates: [
          media(1, airsIn: const Duration(hours: 5)),
          media(2, airsIn: const Duration(hours: 5), banner: 'https://b'),
        ],
        listIds: const {},
        now: now,
      )!;
      expect(hero.media.id, 2);
    });

    test('épisodes passés ou trop lointains ignorés → n°1 des tendances', () {
      final hero = pickDiscoverHero(
        candidates: [
          media(1),
          media(2, airsIn: const Duration(days: 12)),
          media(3, airsIn: const Duration(hours: -3)),
        ],
        listIds: const {},
        now: now,
      )!;
      expect(hero.media.id, 1);
      expect(hero.kind, DiscoverHeroKind.trending);
    });
  });

  test('airingCountdown choisit l\'unité', () {
    expect(airingCountdown(const Duration(seconds: 20)),
        (key: 'airing_in_minutes', count: 1));
    expect(airingCountdown(const Duration(minutes: 42)),
        (key: 'airing_in_minutes', count: 42));
    expect(airingCountdown(const Duration(hours: 2, minutes: 30)),
        (key: 'airing_in_hours', count: 2));
    expect(airingCountdown(const Duration(hours: 50)),
        (key: 'airing_in_days', count: 3));
  });
}
