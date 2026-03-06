import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class PrismGlassSkin extends WheelSkin {
  double _time = 0;
  double _flipTimer = 0;
  static const _flipDuration = 0.20;

  PrismGlassSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _flipTimer = _flipDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_flipTimer > 0) _flipTimer -= dt;
  }

  static const List<Color> _rainbow = [
    Color(0xFFFF0000),
    Color(0xFFFF7700),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF0088FF),
    Color(0xFF8800FF),
  ];

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Hexagon outline (crystal shape)
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * pi / 3) - pi / 6;
      final x = cos(a) * radius;
      final y = sin(a) * radius;
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    // Glass fill (transparent tinted)
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = themeColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // Hexagon border with glow
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = themeColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Rainbow internal lines — intensity by speed
    final speedFactor = (currentSpeed / 400.0).clamp(0.0, 1.0);
    final lineCount = (3 + (speedFactor * 5)).round();
    for (int i = 0; i < lineCount; i++) {
      final frac = i / lineCount;
      final phase = _time * 1.5 + frac * 2 * pi;
      final x1 = cos(phase) * radius * 0.9;
      final y1 = sin(phase) * radius * 0.9;
      final x2 = cos(phase + pi * 0.6) * radius * 0.6;
      final y2 = sin(phase + pi * 0.6) * radius * 0.6;

      final colorIndex = (i + (_time * 1.2).round()) % _rainbow.length;
      final alpha = 0.35 + speedFactor * 0.5;
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = _rainbow[colorIndex].withValues(alpha: alpha.clamp(0, 1))
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Center crystal core
    final coreR = radius * 0.25;
    canvas.drawCircle(
      Offset.zero,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.7), themeColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: coreR))
        ..style = PaintingStyle.fill,
    );

    // Flip burst: rainbow flash
    if (_flipTimer > 0) {
      final bt = _flipTimer / _flipDuration;
      for (int i = 0; i < 6; i++) {
        final a = (i * pi / 3) - pi / 6;
        final x = cos(a) * radius * (1 + bt * 0.4);
        final y = sin(a) * radius * (1 + bt * 0.4);
        final col = _rainbow[i].withValues(alpha: bt * 0.8);
        canvas.drawLine(
          Offset.zero,
          Offset(x, y),
          Paint()..color = col..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    canvas.restore();
  }
}
