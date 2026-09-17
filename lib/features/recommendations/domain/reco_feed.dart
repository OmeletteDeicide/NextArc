import 'package:nextarc/features/discover/domain/media_model.dart';

/// Pourquoi un titre sert de source de recommandations.
enum RecoSourceKind {
  /// ❤️ posé par l'utilisateur (ou favori AniList).
  favourite,

  /// Bien noté (≥ 8) sans ❤️.
  rated,
}

/// Titre aimé ou bien noté à partir duquel on recommande.
class RecoSource {
  const RecoSource({
    required this.id,
    required this.title,
    required this.kind,
    this.score,
  });

  final int id;
  final String title;
  final RecoSourceKind kind;
  final double? score;

  /// Force du signal : ❤️ > note 10 > note ≥ 8.
  int get strength => switch (kind) {
    RecoSourceKind.favourite => 2,
    RecoSourceKind.rated => (score ?? 0) >= 10 ? 1 : 0,
  };
}

/// Un rail « Parce que tu as aimé / noté X ».
class RecoRail {
  const RecoRail({required this.source, required this.items});

  final RecoSource source;
  final List<MediaModel> items;
}

/// La reco mise en avant en haut de l'écran, avec sa raison.
typedef RecoPick = ({MediaModel media, RecoSource source});

/// Écran « Pour toi » calculé.
class RecoFeed {
  const RecoFeed({
    this.pick,
    this.rails = const [],
    this.genres = const [],
    this.genreItems = const [],
    this.trending = const [],
  });

  final RecoPick? pick;
  final List<RecoRail> rails;

  /// Genres dominants et titres du rail « Dans tes genres ».
  final List<String> genres;
  final List<MediaModel> genreItems;

  /// Tendances affichées quand il n'y a pas encore de recos.
  final List<MediaModel> trending;

  bool get isPersonalised => pick != null || rails.isNotEmpty;
}

/// Nombre maximum de rails de source et de titres par rail.
const int maxRecoRails = 4;
const int maxRecoPerRail = 6;

/// Sources retenues pour aujourd'hui : ordonnées par force du signal, avec
/// une rotation quotidienne à l'intérieur de chaque niveau pour que l'écran
/// ne se réduise pas toujours aux mêmes titres. Le tirage est stable sur la
/// journée (graine = date + [seed], typiquement l'identifiant utilisateur).
List<RecoSource> selectRecoSources(
  List<RecoSource> sources, {
  required DateTime now,
  String seed = '',
  int max = maxRecoRails,
}) {
  final day =
      DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime.utc(2026)).inDays.abs() +
      stableHash(seed);
  final unique = <int, RecoSource>{};
  for (final s in sources) {
    unique.putIfAbsent(s.id, () => s);
  }

  final selected = <RecoSource>[];
  for (final strength in const [2, 1, 0]) {
    final tier = unique.values.where((s) => s.strength == strength).toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    if (tier.isEmpty) continue;
    final offset = day % tier.length;
    selected.addAll([...tier.skip(offset), ...tier.take(offset)]);
  }
  return selected.take(max).toList();
}

/// Hash déterministe (String.hashCode peut varier d'une exécution à l'autre).
int stableHash(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x3fffffff;
  }
  return hash;
}

/// Construit le fil : dédoublonnage global (jamais un titre de la liste,
/// jamais deux fois le même titre), reco du jour tirée du premier rail, puis
/// rail « Dans tes genres ».
RecoFeed buildRecoFeed({
  required List<RecoSource> sources,
  required Map<int, List<MediaModel>> recosBySource,
  required Set<int> excludeIds,
  List<String> genres = const [],
  List<MediaModel> genrePool = const [],
  List<MediaModel> trending = const [],
}) {
  final used = <int>{...excludeIds};
  final rails = <RecoRail>[];

  for (final source in sources) {
    final items = <MediaModel>[];
    for (final media in recosBySource[source.id] ?? const <MediaModel>[]) {
      if (used.contains(media.id)) continue;
      used.add(media.id);
      items.add(media);
      if (items.length >= maxRecoPerRail) break;
    }
    if (items.isNotEmpty) rails.add(RecoRail(source: source, items: items));
  }

  // Reco du jour : le titre le mieux noté du rail le plus fort
  RecoPick? pick;
  if (rails.isNotEmpty) {
    final first = rails.first;
    final best = first.items.reduce(
      (a, b) => (b.averageScore ?? 0) > (a.averageScore ?? 0) ? b : a,
    );
    pick = (media: best, source: first.source);
    final rest = first.items.where((m) => m.id != best.id).toList();
    if (rest.isEmpty) {
      rails.removeAt(0);
    } else {
      rails[0] = RecoRail(source: first.source, items: rest);
    }
  }

  final genreItems = <MediaModel>[];
  if (pick != null || rails.isNotEmpty) {
    for (final media in genrePool) {
      if (used.contains(media.id)) continue;
      used.add(media.id);
      genreItems.add(media);
      if (genreItems.length >= maxRecoPerRail) break;
    }
  }

  return RecoFeed(
    pick: pick,
    rails: rails,
    genres: genreItems.isEmpty ? const [] : genres,
    genreItems: genreItems,
    trending: pick == null && rails.isEmpty
        ? trending.where((m) => !excludeIds.contains(m.id)).toList()
        : const [],
  );
}

/// Les [count] genres les plus présents dans des titres terminés / aimés.
List<String> dominantGenres(
  Iterable<List<String>?> genreLists, {
  int count = 2,
}) {
  final tally = <String, int>{};
  for (final list in genreLists) {
    for (final g in list ?? const <String>[]) {
      tally[g] = (tally[g] ?? 0) + 1;
    }
  }
  final sorted = tally.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return sorted.take(count).map((e) => e.key).toList();
}
