import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Réglages du motif zigzag, regroupés ici pour être ajustés sur téléphone.
/// Tracé repris du design : `M0 9 L4.5 3 L9 9 L13.5 3 L18 9` (tuile 18×12).
abstract final class ZigzagConfig {
  /// Inclinaison de la bande de zigzags (25° dans le design — à juger).
  static const double angleDegrees = 25;

  /// Distance entre deux creux d'une même rangée.
  static const double period = 9;

  /// Hauteur creux → sommet.
  static const double amplitude = 6;

  /// Distance entre deux rangées.
  static const double rowSpacing = 12;

  static const double strokeWidth = 1;

  /// Opacités par défaut (les surfaces accentuées peuvent monter plus haut).
  static const double darkOpacity = 0.20;
  static const double lightOpacity = 0.18;

  /// En clair, le design ne met le motif que sur les fonds accentués ; mettre
  /// à `false` pour le retirer complètement du thème clair.
  static const bool enabledInLight = true;
}

/// Pose le motif zigzag derrière [child].
class ZigzagBackground extends StatelessWidget {
  const ZigzagBackground({
    super.key,
    required this.child,
    this.color,
    this.opacity,
    this.alwaysVisible = false,
    this.showInLight = true,
  });

  final Widget child;

  /// Couleur du trait (par défaut `AppColors.zigzag`).
  final Color? color;

  /// Opacité du trait (par défaut selon le thème, voir [ZigzagConfig]).
  final double? opacity;

  /// Ignore [ZigzagConfig.enabledInLight] — pour les cartes de partage,
  /// toujours sombres quel que soit le thème de l'app.
  final bool alwaysVisible;

  /// `false` : motif masqué en thème clair pour cet écran (le design ne le met
  /// en clair que sur les fonds accentués).
  final bool showInLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hiddenInLight = !ZigzagConfig.enabledInLight || !showInLight;
    if (!isDark && hiddenInLight && !alwaysVisible) {
      return child;
    }

    final alpha = opacity ??
        (isDark ? ZigzagConfig.darkOpacity : ZigzagConfig.lightOpacity);
    final strokeColor =
        (color ?? AppColors.of(context).zigzag).withValues(alpha: alpha);

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: ZigzagPainter(color: strokeColor)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Peint des rangées de zigzags inclinées de [angleDegrees], découpées à la
/// taille du widget.
class ZigzagPainter extends CustomPainter {
  const ZigzagPainter({
    required this.color,
    this.angleDegrees = ZigzagConfig.angleDegrees,
    this.period = ZigzagConfig.period,
    this.amplitude = ZigzagConfig.amplitude,
    this.rowSpacing = ZigzagConfig.rowSpacing,
    this.strokeWidth = ZigzagConfig.strokeWidth,
  })  : assert(period > 0),
        assert(rowSpacing > 0);

  final Color color;
  final double angleDegrees;
  final double period;
  final double amplitude;
  final double rowSpacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angleDegrees * math.pi / 180);

    // Couvre toute la zone quelle que soit la rotation.
    final half = math.sqrt(size.width * size.width +
                size.height * size.height) /
            2 +
        period;
    final halfAmplitude = amplitude / 2;
    final step = period / 2;

    final path = Path();
    for (var y = -half; y <= half; y += rowSpacing) {
      path.moveTo(-half, y + halfAmplitude);
      var toPeak = true;
      for (var x = -half + step; x <= half + period; x += step) {
        path.lineTo(x, toPeak ? y - halfAmplitude : y + halfAmplitude);
        toPeak = !toPeak;
      }
    }

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ZigzagPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.period != period ||
      oldDelegate.amplitude != amplitude ||
      oldDelegate.rowSpacing != rowSpacing ||
      oldDelegate.strokeWidth != strokeWidth;
}
