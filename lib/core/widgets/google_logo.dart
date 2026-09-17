import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo « G » multicolore de Google, dessiné (pas d'asset à embarquer),
/// posé sur une pastille blanche comme le demandent les règles de marque.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final stroke = s * 0.22;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (s - stroke) / 2,
    );
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double rad(double deg) => deg * math.pi / 180;

    // Angles en degrés, 0° = 3 h, sens horaire (repère Flutter)
    canvas
      ..drawArc(rect, rad(-45), rad(-95), false, arc(_red)) // haut
      ..drawArc(rect, rad(-140), rad(-85), false, arc(_yellow)) // gauche
      ..drawArc(rect, rad(135), rad(-90), false, arc(_green)) // bas
      ..drawArc(rect, rad(45), rad(-45), false, arc(_blue)); // droite

    // Barre horizontale bleue du G
    final center = rect.center;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        rect.right + stroke / 2,
        center.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
