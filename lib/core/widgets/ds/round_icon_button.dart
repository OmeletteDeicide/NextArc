import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Bouton rond de 36 px (surface 2) dans une zone tactile de 44 px — actions
/// d'en-tête : recherche, filtres, calendrier…
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Couleur de l'icône (texte 2 par défaut).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: color ?? c.text2),
            ),
          ),
        ),
      ),
    );
  }
}
