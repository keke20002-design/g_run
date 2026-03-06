import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class PhaseRingSkin extends WheelSkin {
  static const int segmentCount = 6;
  static const double arcAngle = (40 * pi / 180);

  double _rotation = 0;
  double _flipAnimTimer = 0;
  final double _flipDuration = 0.120; // 120ms

  PhaseRingSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _flipAnimTimer = _flipDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Rotate relative to speed
    final rotationSpeed = (currentSpeed / 35.0).clamp(5.0, 15.0);
    _rotation += dt * rotationSpeed;

    if (_flipAnimTimer > 0) {
      _flipAnimTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final radius = size.x / 2 - 4;
    final center = (size / 2).toOffset();
    
    // Speed-based gap increase
    final baseGap = (2 * pi / segmentCount);
    double gapFactor = 1.0;
    if (currentSpeed > 600) {
      gapFactor += (currentSpeed - 600) / 1000.0 * 0.3;
    }

    // Flip-based gap decrease (merge)
    if (_flipAnimTimer > 0) {
      final t = _flipAnimTimer / _flipDuration;
      gapFactor *= (1.0 - t * 0.6); // Shrink gaps significantly
    }

    final paint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = _rotation + (i * baseGap * gapFactor);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle,
        false,
        paint,
      );
    }
  }
}
