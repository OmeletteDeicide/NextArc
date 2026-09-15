import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';

/// Couronne des Arcer, posée sur une photo de profil ou à côté d'un titre.
class ArcerCrown extends StatelessWidget {
  const ArcerCrown({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.35,
      child: Text('👑', style: TextStyle(fontSize: size, height: 1)),
    );
  }
}

/// Pastille du titre de profil : dégradé accent, dorée pour un Arcer.
/// La couronne n'apparaît que pour les Arcer.
class UserTitleBadge extends StatelessWidget {
  const UserTitleBadge({
    super.key,
    required this.title,
    this.showCrown = true,
    this.fontSize = 13,
    this.onAccent = false,
  });

  final UserTitle title;

  /// Affiche 👑 devant le titre (uniquement si Arcer).
  final bool showCrown;
  final double fontSize;

  /// Posée sur un fond déjà en dégradé accent (en-tête clair du profil) :
  /// pastille blanche au texte accent, ou sombre et dorée pour un Arcer.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final arcer = title.isArcer;

    final Color textColor;
    final BoxDecoration decoration;
    if (arcer) {
      textColor = c.star;
      decoration = BoxDecoration(
        color: onAccent
            ? const Color(0x59060A15)
            : c.star.withValues(alpha: 0.16),
        border: Border.all(color: c.star.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.full),
      );
    } else if (onAccent) {
      textColor = c.accent;
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
      );
    } else {
      textColor = Colors.white;
      decoration = BoxDecoration(
        gradient: c.accentGradient,
        borderRadius: BorderRadius.circular(AppRadius.full),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.15,
        vertical: fontSize * 0.6,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arcer && showCrown) ...[
            Text('👑', style: TextStyle(fontSize: fontSize, height: 1.2)),
            SizedBox(width: fontSize * 0.45),
          ],
          Flexible(
            child: Text(
              title.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
