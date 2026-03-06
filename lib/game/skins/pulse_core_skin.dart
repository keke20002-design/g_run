import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class PulseCoreSkin extends WheelSkin {
  final Color baseColor = const Color(0xFF0F1B2E);
  double _pulseTimer = 0;
  double _intensity = 0.5;

  PulseCoreSkin({required super.themeColor}) : super(size: Vector2.all(64));

  void setPulseIntensity(double intensity) {
    _intensity = intensity.clamp(0.0, 1.0);
  }

  @override
  void triggerGravityFlip() {
    // Quick brightness flash on flip
    _pulseTimer = 0.8; 
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer = (_pulseTimer + dt) % (2 * pi);
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = 28.0;

    // Pulse value (0.0 to 1.0)
    final pulseVal = (sin(_pulseTimer * 3.0) + 1) / 2;
    final scale = 1.0 + (pulseVal * 0.04 * _intensity);
    
    // Outer thin ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = themeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner filled circle
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()..color = baseColor..style = PaintingStyle.fill,
    );

    // Center bright core
    final coreAlpha = 0.3 + (pulseVal * 0.7 * _intensity);
    canvas.drawCircle(
      center,
      8 * scale,
      Paint()
        ..color = themeColor.withValues(alpha: coreAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    
    canvas.drawCircle(
      center,
      4 * scale,
      Paint()..color = Colors.white.withValues(alpha: coreAlpha * 0.8),
    );
  }
}
