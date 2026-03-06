import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class GuardianShieldSkin extends WheelSkin {
  double _outerAngle = 0;
  double _innerAngle = 0;
  double _flipTimer = 0;
  static const _flipDuration = 0.22;
  double _pulseTime = 0;

  GuardianShieldSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _flipTimer = _flipDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speedFactor = (currentSpeed / 60.0).clamp(2.0, 7.0);
    _outerAngle += dt * speedFactor * 1.8;
    _innerAngle -= dt * speedFactor * 2.5; // counter-rotate
    _pulseTime += dt;
    if (_flipTimer > 0) _flipTimer -= dt;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Core orb
    final pulse = 0.85 + sin(_pulseTime * 4) * 0.12;
    canvas.drawCircle(
      Offset.zero,
      radius * 0.28 * pulse,
      Paint()
        ..color = themeColor.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Inner orbit semicircles (faster, counter-rotate)
    canvas.save();
    canvas.rotate(_innerAngle);
    _drawShieldArc(canvas, radius * 0.58, 0, pi, themeColor, 3.0, 4);
    _drawShieldArc(canvas, radius * 0.58, pi, pi, themeColor.withValues(alpha: 0.5), 3.0, 4);
    canvas.restore();

    // Outer orbit semicircles (slower)
    canvas.save();
    canvas.rotate(_outerAngle);
    _drawShieldArc(canvas, radius, 0, pi, themeColor, 2.5, 6);
    _drawShieldArc(canvas, radius, pi, pi, themeColor.withValues(alpha: 0.4), 2.5, 6);
    canvas.restore();

    // Small orbiting dots on outer ring
    for (int i = 0; i < 4; i++) {
      final a = _outerAngle + i * pi / 2;
      final x = cos(a) * radius;
      final y = sin(a) * radius;
      canvas.drawCircle(
        Offset(x, y),
        2.5,
        Paint()
          ..color = themeColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Flip activation: shield flare
    if (_flipTimer > 0) {
      final bt = _flipTimer / _flipDuration;
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset.zero,
          radius * (0.7 + i * 0.2) * (1 + bt * 0.25),
          Paint()
            ..color = themeColor.withValues(alpha: bt * (0.35 - i * 0.08))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 - i * 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

    canvas.restore();
  }

  void _drawShieldArc(Canvas canvas, double r, double startAngle, double sweep,
      Color color, double strokeW, double blurRadius) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius),
    );
  }
}
