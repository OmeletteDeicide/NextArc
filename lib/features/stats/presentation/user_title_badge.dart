import 'package:flutter/material.dart';
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

/// Pastille du titre de profil (dorée pour un Arcer).
class UserTitleBadge extends StatelessWidget {
  const UserTitleBadge({
    super.key,
    required this.title,
    this.showCrown = true,
    this.fontSize = 13,
  });

  final UserTitle title;

  /// Affiche 👑 devant le titre d'un Arcer.
  final bool showCrown;
  final double fontSize;

  static const _arcerGradient = [Color(0xFFFFC107), Color(0xFFFF8F00)];
  static const _defaultGradient = [Color(0xFF4F6EF5), Color(0xFF7C4DFF)];

  @override
  Widget build(BuildContext context) {
    final arcer = title.isArcer;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.8, vertical: fontSize * 0.3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: arcer ? _arcerGradient : _defaultGradient,
        ),
        borderRadius: BorderRadius.circular(fontSize * 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arcer && showCrown) ...[
            Text('👑', style: TextStyle(fontSize: fontSize, height: 1.2)),
            SizedBox(width: fontSize * 0.35),
          ],
          Text(
            title.label,
            style: TextStyle(
              color: arcer ? const Color(0xFF3E2723) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
