import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

/// The classic 4-spoke neon wheel — matches the main-screen demo wheel exactly.
class ClassicNeonSkin extends WheelSkin {
  double _rotation = 0;
  double _flipTimer = 0;
  static const _flipDuration = 0.12;

  ClassicNeonSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _flipTimer = _flipDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final rotSpeed = (currentSpeed / 15.0).clamp(7.0, 17.0);
    _rotation += dt * rotSpeed;
    if (_flipTimer > 0) _flipTimer -= dt;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 3;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Dark core fill
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFF0F1B2E),
    );

    // Glow ring
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = themeColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Rim circle
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 4 spokes (rotate with _rotation)
    canvas.rotate(_rotation);
    final spokePaint = Paint()
      ..color = themeColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(cos(a) * (radius - 4), sin(a) * (radius - 4)),
        spokePaint,
      );
    }

    // Flip pulse: brief bright flash on rim
    if (_flipTimer > 0) {
      final bt = _flipTimer / _flipDuration;
      canvas.drawCircle(
        Offset.zero,
        radius * (1 + bt * 0.12),
        Paint()
          ..color = themeColor.withValues(alpha: bt * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.restore();
  }
}
