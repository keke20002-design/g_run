import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class ArcBladeSkin extends WheelSkin {
  double _rotation = 0;
  double _flipBoost = 0;

  ArcBladeSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _flipBoost = 0.3; // Radians
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speedMult = (currentSpeed / 35.0).clamp(5.0, 15.0);
    _rotation += dt * speedMult + _flipBoost;
    
    if (_flipBoost > 0) {
      _flipBoost = ((_flipBoost - dt * 2)).clamp(0.0, 0.3);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = 26.0;

    double sweepAngle = (120 * pi / 180);
    if (currentSpeed > 800) {
      sweepAngle = (120 + (currentSpeed - 800) / 400.0 * 40).clamp(120, 160) * pi / 180;
    }

    final paint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _rotation,
      sweepAngle,
      false,
      paint,
    );

    // Subtle ghost trailing arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _rotation - 0.2,
      sweepAngle,
      false,
      paint..strokeWidth = 8..color = themeColor.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}
