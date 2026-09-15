import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/core/theme/zigzag_background.dart';

void main() {
  void paintOnce(ZigzagPainter painter, Size size) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording();
  }

  test('le motif se peint sans erreur, y compris sur une taille nulle', () {
    const painter = ZigzagPainter(color: Colors.blue);
    expect(() => paintOnce(painter, Size.zero), returnsNormally);
    expect(() => paintOnce(painter, const Size(392, 850)), returnsNormally);
    expect(
      () => paintOnce(
        const ZigzagPainter(color: Colors.blue, angleDegrees: 115),
        const Size(1080, 1920),
      ),
      returnsNormally,
    );
  });

  test('ne se repeint que si un réglage change', () {
    const base = ZigzagPainter(color: Colors.blue);
    expect(base.shouldRepaint(const ZigzagPainter(color: Colors.blue)), isFalse);
    expect(base.shouldRepaint(const ZigzagPainter(color: Colors.red)), isTrue);
    expect(
      base.shouldRepaint(
          const ZigzagPainter(color: Colors.blue, angleDegrees: 115)),
      isTrue,
    );
  });
}
