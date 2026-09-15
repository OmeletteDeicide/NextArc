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
  });

  final UserTitle title;

  /// Affiche 👑 devant le titre (uniquement si Arcer).
  final bool showCrown;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final arcer = title.isArcer;
    final textColor = arcer ? c.star : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.15,
        vertical: fontSize * 0.6,
      ),
      decoration: BoxDecoration(
        gradient: arcer ? null : c.accentGradient,
        color: arcer ? c.star.withValues(alpha: 0.16) : null,
        border: arcer
            ? Border.all(color: c.star.withValues(alpha: 0.4))
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
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
