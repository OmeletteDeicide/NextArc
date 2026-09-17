import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Ligne de « Ma liste », quelle que soit la source (AniList, NextArc, invité).
class ListItem {
  const ListItem({
    required this.mediaId,
    required this.title,
    required this.status,
    required this.isManga,
    this.coverImage,
    this.progress = 0,
    this.total,
    this.score,
    this.favourite = false,
    this.nextAiring,
    this.countryOfOrigin,
    this.anilist,
    this.local,
  });

  factory ListItem.fromAnilist(MediaListEntry entry) {
    final media = entry.media;
    return ListItem(
      mediaId: media.id,
      title: media.displayTitle,
      coverImage: media.coverImage,
      status: entry.status ?? ListStatus.planning,
      isManga: media.isManga,
      progress: entry.progress ?? 0,
      total: media.isManga ? media.chapters : media.episodes,
      score: entry.score,
      // Pas de ❤️ côté AniList seul : les notes ≥ 8 font office de favoris
      favourite: (entry.score ?? 0) >= GuestWatchlistEntry.autoFavouriteScore,
      nextAiring: media.nextAiringEpisode,
      countryOfOrigin: media.countryOfOrigin,
      anilist: entry,
    );
  }

  factory ListItem.fromLocal(
    GuestWatchlistEntry entry, {
    NextAiringEpisode? nextAiring,
  }) =>
      ListItem(
        mediaId: entry.animeId,
        title: entry.title,
        coverImage: entry.coverImage,
        status: entry.status,
        isManga: entry.isManga,
        progress: entry.progress ?? 0,
        total: entry.episodes,
        score: entry.score,
        favourite: entry.favourite,
        nextAiring: entry.isManga ? null : nextAiring,
        local: entry,
      );

  final int mediaId;
  final String title;
  final String? coverImage;
  final ListStatus status;
  final bool isManga;
  final int progress;

  /// Nombre total d'épisodes / chapitres (null = inconnu ou en cours).
  final int? total;
  final double? score;
  final bool favourite;
  final NextAiringEpisode? nextAiring;
  final String? countryOfOrigin;

  /// Entrée d'origine (une seule des deux est renseignée).
  final MediaListEntry? anilist;
  final GuestWatchlistEntry? local;

  bool get hasKnownTotal => total != null && total! > 0;

  /// Épisodes déjà diffusés quand la série est en cours.
  int? get airedEpisodes {
    final next = nextAiring;
    if (isManga || next == null) return null;
    return next.episode > 1 ? next.episode - 1 : 0;
  }

  /// « 12/24 », « 1150/1178 » (sortis) ou « 12/? ».
  String get progressLabel =>
      formatProgress(progress, total: total, aired: airedEpisodes);

  /// Le bouton +1 n'apparaît que sur « En cours » tant que ce n'est pas fini.
  bool get canPlusOne =>
      status == ListStatus.current && (!hasKnownTotal || progress < total!);

  /// Média minimal pour ouvrir la fiche d'édition.
  MediaModel toMedia() =>
      anilist?.media ??
      MediaModel(
        id: mediaId,
        titleRomaji: title,
        coverImageLarge: coverImage,
        mediaType: isManga ? 'MANGA' : 'ANIME',
        episodes: isManga ? null : total,
        chapters: isManga ? total : null,
        genres: local?.genres,
        duration: local?.duration,
        nextAiringEpisode: nextAiring,
      );
}

/// Repère de progression : le total s'il est connu, sinon le nombre
/// d'épisodes déjà sortis (série en cours), sinon null.
int? progressCeiling({int? total, int? aired}) {
  if (total != null && total > 0) return total;
  if (aired != null && aired > 0) return aired;
  return null;
}

/// « 12/24 », « 1150/1178 » ou « 12/? » quand rien n'est connu.
String formatProgress(int progress, {int? total, int? aired}) =>
    '$progress/${progressCeiling(total: total, aired: aired) ?? '?'}';

/// Résultat d'un appui sur +1 : atteindre le total passe le média en Terminé.
({int progress, ListStatus status}) plusOne({
  required int progress,
  required int? total,
  required ListStatus status,
}) {
  final knownTotal = total != null && total > 0;
  if (knownTotal && progress >= total) {
    return (progress: total, status: ListStatus.completed);
  }
  final next = progress + 1;
  if (knownTotal && next >= total) {
    return (progress: total, status: ListStatus.completed);
  }
  return (
    progress: next,
    status: status == ListStatus.planning ? ListStatus.current : status,
  );
}

/// Onglet de « Ma liste » : un statut, ou les favoris quand [status] est null.
class ListTab {
  const ListTab({required this.status, required this.items});

  final ListStatus? status;
  final List<ListItem> items;

  bool get isFavourites => status == null;

  /// Clé stable pour mémoriser l'onglet choisi.
  String get key => status?.anilistValue ?? 'FAVOURITES';
}

/// Onglets dans l'ordre de l'app : En cours, Prévu, Favoris, En pause,
/// Terminé, Abandonné. Les statuts vides sont masqués, Favoris reste toujours.
List<ListTab> buildListTabs(List<ListItem> items) {
  ListTab? statusTab(ListStatus status) {
    final group = items.where((i) => i.status == status).toList();
    return group.isEmpty ? null : ListTab(status: status, items: group);
  }

  final favourites = items.where((i) => i.favourite).toList()
    ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

  return [
    ?statusTab(ListStatus.current),
    ?statusTab(ListStatus.planning),
    ListTab(status: null, items: favourites),
    ?statusTab(ListStatus.paused),
    ?statusTab(ListStatus.completed),
    ?statusTab(ListStatus.dropped),
  ];
}

/// Nombre de diffusions entre maintenant et [days] jours.
int countReleasesWithin(
  Iterable<DateTime> airingTimes, {
  required DateTime now,
  int days = 7,
}) {
  final end = now.add(Duration(days: days));
  return airingTimes.where((t) => !t.isBefore(now) && !t.isAfter(end)).length;
}
