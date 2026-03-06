import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'wheel_skin.dart';

class CyberpunkWheelSkin extends WheelSkin {
  double _rotation = 0;
  double _binaryScroll = 0;
  double _flipTimer = 0;
  static const _flipDuration = 0.15;
  final _rng = Random();

  // Pre-generated binary digit positions
  final List<_BinaryDigit> _digits = [];

  CyberpunkWheelSkin({required super.themeColor}) : super(size: Vector2.all(64)) {
    _generateDigits();
  }

  void _generateDigits() {
    _digits.clear();
    final radius = 20.0;
    for (int i = 0; i < 20; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final r = radius * (0.2 + _rng.nextDouble() * 0.8);
      _digits.add(_BinaryDigit(
        angle: a,
        dist: r,
        bit: _rng.nextBool() ? '1' : '0',
        speed: 0.3 + _rng.nextDouble() * 0.7,
      ));
    }
  }

  @override
  void triggerGravityFlip() {
    _flipTimer = _flipDuration;
    // Scramble digits on flip
    for (final d in _digits) {
      d.bit = _rng.nextBool() ? '1' : '0';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final rotSpeed = (currentSpeed / 35.0).clamp(5.0, 15.0);
    _rotation += dt * rotSpeed;
    _binaryScroll += dt * 2.5;
    if (_flipTimer > 0) _flipTimer -= dt;

    // Randomly flip bits
    for (final d in _digits) {
      if (_rng.nextDouble() < dt * 1.5) {
        d.bit = _rng.nextBool() ? '1' : '0';
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final center = (size / 2).toOffset();
    final radius = size.x / 2 - 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Outer ring with spokes (classic wheel)
    canvas.rotate(_rotation);

    // Main ring
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 4 spokes
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(
        Offset(cos(a) * radius * 0.2, sin(a) * radius * 0.2),
        Offset(cos(a) * radius * 0.9, sin(a) * radius * 0.9),
        Paint()
          ..color = themeColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
    }

    // Hub
    canvas.drawCircle(
      Offset.zero,
      radius * 0.2,
      Paint()
        ..color = themeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    canvas.rotate(-_rotation); // un-rotate for text

    // Binary digits flowing in the wheel
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final d in _digits) {
      final a = d.angle + _binaryScroll * d.speed;
      final x = cos(a) * d.dist;
      final y = sin(a) * d.dist;

      final alpha = 0.5 + sin(_binaryScroll * d.speed + d.angle) * 0.4;

      textPainter.text = TextSpan(
        text: d.bit,
        style: TextStyle(
          color: themeColor.withValues(alpha: alpha.clamp(0.15, 0.95)),
          fontSize: 7,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(x - textPainter.width / 2, y - textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Flip: data glitch burst
    if (_flipTimer > 0) {
      final bt = _flipTimer / _flipDuration;
      canvas.drawCircle(
        Offset.zero,
        radius * (1 + bt * 0.25),
        Paint()
          ..color = themeColor.withValues(alpha: bt * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.restore();
  }
}

class _BinaryDigit {
  double angle;
  double dist;
  String bit;
  double speed;
  _BinaryDigit({required this.angle, required this.dist, required this.bit, required this.speed});
}
