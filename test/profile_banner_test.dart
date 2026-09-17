import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/auth/domain/profile_banner.dart';

void main() {
  const anilist = 'https://s4.anilist.co/file/banner.jpg';
  const cover = 'https://s4.anilist.co/file/cover.jpg';

  group('resolveBannerUrl', () {
    test('bannière choisie > AniList > dégradé', () {
      expect(
        resolveBannerUrl(
            source: BannerSource.cover,
            chosenUrl: cover,
            anilistBanner: anilist),
        cover,
      );
      expect(
        resolveBannerUrl(
            source: null, chosenUrl: null, anilistBanner: anilist),
        anilist,
      );
      expect(
        resolveBannerUrl(source: null, chosenUrl: null, anilistBanner: null),
        isNull,
      );
    });

    test('dégradé choisi explicitement : AniList ignoré', () {
      expect(
        resolveBannerUrl(
            source: BannerSource.gradient,
            chosenUrl: null,
            anilistBanner: anilist),
        isNull,
      );
    });

    test('image choisie manquante ou AniList délié → repli', () {
      expect(
        resolveBannerUrl(
            source: BannerSource.device, chosenUrl: ' ', anilistBanner: null),
        isNull,
      );
      expect(
        resolveBannerUrl(
            source: BannerSource.anilist, chosenUrl: null, anilistBanner: null),
        isNull,
      );
    });
  });

  test('effectiveBannerSource coche la bonne option', () {
    expect(
      effectiveBannerSource(
          source: null, chosenUrl: null, anilistBanner: anilist),
      BannerSource.anilist,
    );
    expect(
      effectiveBannerSource(source: null, chosenUrl: null, anilistBanner: null),
      BannerSource.gradient,
    );
    expect(
      effectiveBannerSource(
          source: BannerSource.cover, chosenUrl: cover, anilistBanner: anilist),
      BannerSource.cover,
    );
    expect(
      effectiveBannerSource(
          source: BannerSource.anilist, chosenUrl: null, anilistBanner: null),
      BannerSource.gradient,
    );
  });

  test('BannerSource.fromValue', () {
    expect(BannerSource.fromValue('device'), BannerSource.device);
    expect(BannerSource.fromValue('autre'), isNull);
  });
}
