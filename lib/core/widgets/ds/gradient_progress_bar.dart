import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Barre de progression en dégradé accent (liste, fiche d'édition, titres).
/// Se remplit toujours de gauche à droite sur toute la largeur disponible.
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.animate = true,
    this.colors,
  });

  /// Progression de 0 à 1 (bornée).
  final double value;
  final double height;
  final bool animate;

  /// Couleurs du remplissage (par défaut accent → violet).
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // La piste prend toute la largeur : sans cela, dans un parent aux
        // contraintes lâches (Center…), elle se réduisait au remplissage et
        // grandissait depuis le centre.
        final width =
            constraints.hasBoundedWidth ? constraints.maxWidth : 120.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            width: width,
            height: height,
            child: ColoredBox(
              color: c.surface2,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: target),
                duration: animate ? AppMotion.progress : Duration.zero,
                curve: Curves.easeOutCubic,
                builder: (context, factor, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: width * factor,
                    height: height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors ?? [c.accent, c.violet],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
