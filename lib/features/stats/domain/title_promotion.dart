import 'dart:math' as math;

import 'package:nextarc/features/stats/domain/user_title.dart';

/// Ce qui a fait monter le titre.
enum TitlePromotionKind {
  /// Titre ultime atteint.
  arcer,

  /// Nouveau nom (anime terminés).
  rank,

  /// Nouveau qualificatif (heures de visionnage).
  qualifier,
}

/// Palier d'un titre, mémorisable (le plus haut jamais célébré par compte).
class TitleLevel {
  const TitleLevel({
    required this.rank,
    required this.qualifier,
    required this.arcer,
  });

  factory TitleLevel.of(UserTitle title) => TitleLevel(
        rank: title.rankIndex,
        qualifier: title.qualifierIndex,
        arcer: title.isArcer,
      );

  final int rank;
  final int qualifier;
  final bool arcer;

  /// Tout premier palier (« Petit Curieux ») : rien à célébrer.
  bool get isLowest => rank == 0 && qualifier == 0 && !arcer;

  /// Palier le plus haut des deux, composante par composante : une baisse
  /// passagère (média retiré, liste en cours de chargement) ne fait jamais
  /// oublier un palier déjà fêté.
  TitleLevel upTo(TitleLevel other) => TitleLevel(
        rank: math.max(rank, other.rank),
        qualifier: math.max(qualifier, other.qualifier),
        arcer: arcer || other.arcer,
      );

  String encode() => '$rank:$qualifier:${arcer ? 1 : 0}';

  static TitleLevel? decode(String? raw) {
    final parts = raw?.split(':');
    if (parts == null || parts.length != 3) return null;
    final rank = int.tryParse(parts[0]);
    final qualifier = int.tryParse(parts[1]);
    if (rank == null || qualifier == null) return null;
    return TitleLevel(rank: rank, qualifier: qualifier, arcer: parts[2] == '1');
  }
}

/// Passage de palier entre deux niveaux, ou null. Une baisse n'est jamais
/// célébrée, et un Arcer n'a plus de palier à franchir.
TitlePromotionKind? promotionBetween(TitleLevel before, TitleLevel after) {
  if (before.arcer) return null;
  if (after.arcer) return TitlePromotionKind.arcer;
  if (after.rank > before.rank) return TitlePromotionKind.rank;
  if (after.qualifier > before.qualifier) return TitlePromotionKind.qualifier;
  return null;
}

/// Passage de palier entre deux titres du même compte, ou null.
TitlePromotionKind? titlePromotion({
  required UserTitle before,
  required UserTitle after,
}) =>
    promotionBetween(TitleLevel.of(before), TitleLevel.of(after));

/// Décide s'il faut célébrer le titre [current] d'un compte, sachant le
/// palier déjà mémorisé ([stored], null s'il n'y en a jamais eu), et ce qu'il
/// faut mémoriser ensuite.
///
/// - Jamais rien de mémorisé (nouveau compte, ou utilisateur existant après
///   la mise à jour) : une seule carte pour le titre actuel, sauf s'il est au
///   tout premier palier. Pas une carte par palier déjà franchi.
/// - Sinon : une carte seulement si le titre dépasse le palier mémorisé, donc
///   jamais deux fois le même titre, même après une reconnexion.
({TitlePromotionKind? celebrate, TitleLevel store}) evaluateTitleLevel({
  required TitleLevel? stored,
  required TitleLevel current,
}) {
  if (stored == null) {
    const lowest = TitleLevel(rank: 0, qualifier: 0, arcer: false);
    return (
      celebrate: current.isLowest ? null : promotionBetween(lowest, current),
      store: current,
    );
  }
  return (
    celebrate: promotionBetween(stored, current),
    store: stored.upTo(current),
  );
}
