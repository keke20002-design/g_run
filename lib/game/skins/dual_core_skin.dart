import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class DualCoreSkin extends WheelSkin {
  final Color innerColor;
  double _outerRot = 0;
  double _innerRot = 0;
  double _pulseTimer = 0;

  DualCoreSkin({
    required super.themeColor,
    Color? innerColor,
  }) : innerColor = innerColor ?? themeColor.withValues(alpha: 0.7),
       super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    // Optional: add a quick jolt to rotation on flip
    _outerRot += 0.2;
    _innerRot -= 0.2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    final speedMult = (currentSpeed / 15.0).clamp(5.0, 15.0);
    _outerRot += dt * speedMult;
    _innerRot -= dt * speedMult * 0.8;

    _pulseTimer = (_pulseTimer + dt) % 1.5;
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final outerRadius = 28.0;
    final innerRadius = 16.0;

    // Outer Ring
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_outerRot);
    canvas.drawCircle(
      Offset.zero,
      outerRadius,
      Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Outer dots
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(cos(i * pi / 2) * outerRadius, sin(i * pi / 2) * outerRadius),
        3,
        Paint()..color = themeColor,
      );
    }
    canvas.restore();

    // Inner Ring & Core
    final pulse = 1.0 + (sin((_pulseTimer / 1.5) * 2 * pi) * 0.05);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_innerRot);
    canvas.scale(pulse);
    
    canvas.drawCircle(
      Offset.zero,
      innerRadius,
      Paint()
        ..color = innerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    
    // Core glow
    canvas.drawCircle(
      Offset.zero,
      6,
      Paint()..color = innerColor.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }
}
