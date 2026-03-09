import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class GlitchFrameSkin extends WheelSkin {
  double _rotation = 0;
  double _glitchTimer = 0;
  double _burstTimer = 0;
  final _rng = Random();

  GlitchFrameSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _burstTimer = 0.150; // 150ms glitch burst
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rotation += dt * (currentSpeed / 15.0).clamp(5.0, 15.0);
    _glitchTimer += dt;
    
    if (_burstTimer > 0) {
      _burstTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = 26.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_rotation);

    // Jitter / Glitch Jitter
    bool isGlitching = (_burstTimer > 0) || (_glitchTimer % 2.0 < 0.08);
    if (isGlitching) {
      canvas.translate(_rng.nextDouble() * 4 - 2, _rng.nextDouble() * 2 - 1);
    }

    final paint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Distorted ring using arcs with varying offsets
    for (int i = 0; i < 8; i++) {
        final start = i * pi / 4;
        final distortion = isGlitching ? _rng.nextDouble() * 0.2 : sin(_glitchTimer * 10 + i) * 0.05;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius + distortion * 10),
          start,
          pi / 5,
          false,
          paint,
        );
    }

    // Erratic spokes if glitching
    if (isGlitching) {
       for (int i = 0; i < 3; i++) {
         final a = _rng.nextDouble() * 2 * pi;
         canvas.drawLine(Offset.zero, Offset(cos(a) * radius, sin(a) * radius), paint..strokeWidth = 1.0);
       }
    }

    canvas.restore();
  }
}
