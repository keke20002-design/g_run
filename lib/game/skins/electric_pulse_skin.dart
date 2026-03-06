import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class ElectricPulseSkin extends WheelSkin {
  double _time = 0;
  double _sparkTimer = 0;
  static const _sparkDuration = 0.18;
  final _rng = Random();

  // Cached lightning bolt points
  final List<List<Offset>> _bolts = [];
  double _boltRefreshTimer = 0;
  static const _boltRefresh = 0.06;

  ElectricPulseSkin({required super.themeColor}) : super(size: Vector2.all(64));

  @override
  void triggerGravityFlip() {
    _sparkTimer = _sparkDuration;
    _regenerateBolts(force: true);
  }

  void _regenerateBolts({bool force = false}) {
    _bolts.clear();
    final radius = 22.0;
    final boltCount = force ? 8 : 4;
    for (int b = 0; b < boltCount; b++) {
      final startAngle = _rng.nextDouble() * 2 * pi;
      final endAngle = startAngle + pi * (0.4 + _rng.nextDouble() * 0.8);
      final List<Offset> bolt = [];
      final segments = 5;
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final a = startAngle + (endAngle - startAngle) * t;
        final r = radius * (0.5 + _rng.nextDouble() * 0.5);
        final jitterX = _rng.nextDouble() * 5 - 2.5;
        final jitterY = _rng.nextDouble() * 5 - 2.5;
        bolt.add(Offset(cos(a) * r + jitterX, sin(a) * r + jitterY));
      }
      _bolts.add(bolt);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_sparkTimer > 0) _sparkTimer -= dt;

    _boltRefreshTimer += dt;
    if (_boltRefreshTimer >= _boltRefresh) {
      _boltRefreshTimer = 0;
      _regenerateBolts();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Unstable core — pulsing circle
    final pulse = 0.7 + sin(_time * 12) * 0.15;
    canvas.drawCircle(
      Offset.zero,
      radius * 0.3 * pulse,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Outer ring (dim)
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = themeColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Lightning bolts
    final boltPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final bolt in _bolts) {
      if (bolt.length < 2) continue;
      final path = Path()..moveTo(bolt[0].dx, bolt[0].dy);
      for (int i = 1; i < bolt.length; i++) {
        path.lineTo(bolt[i].dx, bolt[i].dy);
      }
      canvas.drawPath(path, boltPaint);
    }

    // Spark burst on flip
    if (_sparkTimer > 0) {
      final bt = _sparkTimer / _sparkDuration;
      final sparkPaint = Paint()
        ..color = Colors.white.withValues(alpha: bt * 0.9)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final sparkCount = 12;
      for (int i = 0; i < sparkCount; i++) {
        final a = i * 2 * pi / sparkCount + _time;
        final r0 = radius * 0.4;
        final r1 = radius * (0.9 + bt * 0.4);
        canvas.drawLine(
          Offset(cos(a) * r0, sin(a) * r0),
          Offset(cos(a) * r1, sin(a) * r1),
          sparkPaint,
        );
      }
      // White flash ring
      canvas.drawCircle(
        Offset.zero,
        radius * (1 + bt * 0.3),
        Paint()
          ..color = themeColor.withValues(alpha: bt * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.restore();
  }
}
