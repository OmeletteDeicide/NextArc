import 'package:nextarc/features/discover/domain/media_model.dart';

/// Une recommandation : anime suggéré + anime source ("parce que tu as aimé X").
class RecommendationItem {
  const RecommendationItem({
    required this.sourceTitle,
    required this.recommended,
    this.rating,
  });

  /// Titre de l'anime à l'origine de la reco.
  final String sourceTitle;

  /// Anime recommandé.
  final MediaModel recommended;

  /// Score de pertinence donné par la communauté AniList.
  final int? rating;
}
