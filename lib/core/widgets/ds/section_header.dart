import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';

/// En-tête de section.
/// - par défaut : titre h2 (Sora) + lien d'action optionnel (« Tout voir ») ;
/// - [overline] : sur-titre en capitales mono (« GENRES FAVORIS »).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.overline = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool overline;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final titleWidget = Text(
      overline ? title.toUpperCase() : title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: overline
          ? (text.labelSmall ?? AppTypography.overline(c.text3))
              .copyWith(color: c.text3)
          : text.titleLarge?.copyWith(color: c.text1),
    );

    if (actionLabel == null) return titleWidget;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: titleWidget),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            foregroundColor: c.accentText,
          ),
          child: Text(actionLabel!),
        ),
      ],
    );
  }
}
