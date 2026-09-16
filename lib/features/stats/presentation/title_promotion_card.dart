import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/stats/domain/title_promotion.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

/// Le moment du palier : carte plein écran annonçant le nouveau titre, avec
/// un seul appel à l'action « Partager » (ouvre le carrousel de cartes).
Future<void> showTitlePromotion(
  BuildContext context, {
  required UserTitle title,
  required TitlePromotionKind kind,
}) {
  HapticFeedback.heavyImpact();
  final router = GoRouter.of(context);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'title_promotion_close'.tr(),
    barrierColor: const Color(0xCC03050B),
    transitionDuration: AppMotion.transition,
    pageBuilder: (dialogContext, _, _) => _TitlePromotionCard(
      title: title,
      kind: kind,
      onShare: () {
        Navigator.of(dialogContext).pop();
        router.push(AppRoutes.shareStats);
      },
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _TitlePromotionCard extends StatelessWidget {
  const _TitlePromotionCard({
    required this.title,
    required this.kind,
    required this.onShare,
    required this.onClose,
  });

  final UserTitle title;
  final TitlePromotionKind kind;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Moment « événement » : toujours sombre, comme les cartes de partage
    const c = AppColors.dark;
    final text = Theme.of(context).textTheme;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final isArcer = kind == TitlePromotionKind.arcer;

    final reason = switch (kind) {
      TitlePromotionKind.arcer => 'title_promotion_arcer'.tr(),
      TitlePromotionKind.rank => 'title_promotion_rank'
          .tr(namedArgs: {'count': numbers.format(title.animeCompleted)}),
      TitlePromotionKind.qualifier => 'title_promotion_qualifier'
          .tr(namedArgs: {'hours': numbers.format(title.watchHours)}),
    };

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A2160), Color(0xFF0B1226)],
                    stops: [0, 0.8],
                  ),
                  border: Border.all(
                    color: isArcer
                        ? c.star.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -60,
                      child: IgnorePointer(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                (isArcer ? c.star : c.violet)
                                    .withValues(alpha: 0.45),
                                (isArcer ? c.star : c.violet)
                                    .withValues(alpha: 0),
                              ],
                              stops: const [0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 10, 10, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'title_promotion_overline'
                                      .tr()
                                      .toUpperCase(),
                                  style: AppTypography.overline(
                                      const Color(0xFFA99BE0)),
                                ),
                              ),
                              IconButton(
                                tooltip: 'title_promotion_close'.tr(),
                                onPressed: onClose,
                                icon: Icon(Icons.close_rounded,
                                    color: c.text2),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (isArcer) ...[
                            const Text('👑',
                                style: TextStyle(fontSize: 44, height: 1)),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              title.label,
                              style: text.displayLarge?.copyWith(
                                fontSize: 40,
                                height: 0.98,
                                letterSpacing: -1.2,
                                color: isArcer
                                    ? c.star
                                    : const Color(0xFFF7F9FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              reason,
                              style: text.bodyMedium?.copyWith(
                                color: const Color(0xFFA9B6D6),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Theme(
                              // Bouton aux couleurs sombres même en thème clair
                              data: Theme.of(context).copyWith(
                                extensions: const [AppColors.dark],
                              ),
                              child: AppButton(
                                label: 'share_stats_button'.tr(),
                                icon: Icons.ios_share_rounded,
                                expand: true,
                                onPressed: onShare,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
