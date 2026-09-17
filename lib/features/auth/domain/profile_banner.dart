/// Origine de la bannière de profil choisie dans NextArc.
enum BannerSource {
  /// Jaquette d'un titre de la liste.
  cover('cover'),

  /// Image envoyée depuis l'appareil (Firebase Storage).
  device('device'),

  /// Bannière du compte AniList lié.
  anilist('anilist'),

  /// Dégradé NextArc, choisi explicitement.
  gradient('gradient');

  const BannerSource(this.value);

  /// Valeur stockée dans Firestore.
  final String value;

  static BannerSource? fromValue(String? value) {
    for (final source in values) {
      if (source.value == value) return source;
    }
    return null;
  }
}

/// Bannière réellement affichée : l'image choisie, sinon la bannière AniList,
/// sinon le dégradé (null). Un dégradé choisi explicitement l'emporte sur
/// AniList ; une bannière AniList choisie mais disparue retombe sur le dégradé.
String? resolveBannerUrl({
  required BannerSource? source,
  required String? chosenUrl,
  required String? anilistBanner,
}) {
  final chosen = chosenUrl?.trim();
  return switch (source) {
    BannerSource.cover || BannerSource.device =>
      (chosen == null || chosen.isEmpty) ? _anilist(anilistBanner) : chosen,
    BannerSource.gradient => null,
    BannerSource.anilist || null => _anilist(anilistBanner),
  };
}

/// Option cochée dans « Modifier le profil » pour une configuration donnée.
BannerSource effectiveBannerSource({
  required BannerSource? source,
  required String? chosenUrl,
  required String? anilistBanner,
}) {
  final url = resolveBannerUrl(
      source: source, chosenUrl: chosenUrl, anilistBanner: anilistBanner);
  if (url == null) return BannerSource.gradient;
  if (url == _anilist(anilistBanner) &&
      (source == null || source == BannerSource.anilist)) {
    return BannerSource.anilist;
  }
  return source ?? BannerSource.anilist;
}

String? _anilist(String? url) {
  final trimmed = url?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
