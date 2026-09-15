import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

enum AppButtonVariant {
  /// Dégradé accent — une seule action principale par écran.
  primary,

  /// Fond surface/2.
  secondary,

  /// Contour rouge (Retirer, Déconnexion…).
  destructive,
}

/// Bouton du design system (hauteur ≥ 44, rayon 14).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;

  /// Affiche un indicateur et désactive le bouton.
  final bool loading;

  /// Occupe toute la largeur disponible.
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final textStyle = Theme.of(context).textTheme.labelLarge;

    final (foreground, decoration) = switch (variant) {
      AppButtonVariant.primary => (
          Colors.white,
          BoxDecoration(
            gradient: c.accentGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      AppButtonVariant.secondary => (
          c.text1,
          BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      AppButtonVariant.destructive => (
          c.favourite,
          BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.favourite.withValues(alpha: 0.45)),
          ),
        ),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: foreground),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: foreground),
        if (loading || icon != null) const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle?.copyWith(color: foreground),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      child: AnimatedOpacity(
        duration: AppMotion.press,
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: decoration,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: _enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppSpacing.minTouch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: AppSpacing.sm),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
