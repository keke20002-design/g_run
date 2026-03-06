import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class BlackHoleCoreSkin extends WheelSkin {
  double _angle = 0;
  bool _reversed = false;
  double _flipTimer = 0;
  static const _flipDuration = 0.25;

  BlackHoleCoreSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _reversed = !_reversed;
    _flipTimer = _flipDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speed = (currentSpeed / 60.0).clamp(2.0, 7.0);
    _angle += dt * speed * (_reversed ? -1 : 1) * 2.5;
    if (_flipTimer > 0) _flipTimer -= dt;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Black core
    canvas.drawCircle(
      Offset.zero,
      radius * 0.35,
      Paint()..color = Colors.black,
    );

    // Event horizon ring (dark purple)
    canvas.drawCircle(
      Offset.zero,
      radius * 0.38,
      Paint()
        ..color = const Color(0xFF4A0080)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Swirling particles (accretion disk)
    final particleCount = 14;
    final t = _angle;
    for (int i = 0; i < particleCount; i++) {
      final fraction = i / particleCount;
      final spiralAngle = t + fraction * 2 * pi;
      // Spiral inward: outer particles further out
      final dist = radius * (0.55 + fraction * 0.45);
      final px = cos(spiralAngle) * dist;
      final py = sin(spiralAngle) * dist * 0.45; // flatten to ellipse

      final alpha = (0.3 + fraction * 0.7) * 0.9;
      final r = 1.5 + fraction * 1.5;
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()..color = themeColor.withValues(alpha: alpha),
      );
    }

    // Outer glow ring
    final glowAlpha = 0.3 + (_flipTimer > 0 ? (_flipTimer / _flipDuration) * 0.5 : 0);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = themeColor.withValues(alpha: glowAlpha.clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Flip burst: extra swirling arcs
    if (_flipTimer > 0) {
      final bt = _flipTimer / _flipDuration;
      for (int i = 0; i < 3; i++) {
        final startAngle = _angle + i * 2 * pi / 3;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius * (1.0 + bt * 0.3)),
          startAngle,
          pi * 0.6,
          false,
          Paint()
            ..color = themeColor.withValues(alpha: bt * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    canvas.restore();
  }
}
