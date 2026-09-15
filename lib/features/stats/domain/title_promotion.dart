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

/// Passage de palier entre deux titres du même compte, ou null.
/// Une baisse (retrait d'un média) n'est jamais célébrée, et un Arcer n'a
/// plus de palier à franchir.
TitlePromotionKind? titlePromotion({
  required UserTitle before,
  required UserTitle after,
}) {
  if (before.isArcer) return null;
  if (after.isArcer) return TitlePromotionKind.arcer;
  if (after.rankIndex > before.rankIndex) return TitlePromotionKind.rank;
  if (after.qualifierIndex > before.qualifierIndex) {
    return TitlePromotionKind.qualifier;
  }
  return null;
}
