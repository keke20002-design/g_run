import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

// ── Item Types ────────────────────────────────────────────────────────────────

enum ItemType { slowField, ghostMode, secondChance, precisionCore }

extension ItemTypeInfo on ItemType {
  String get label {
    switch (this) {
      case ItemType.slowField:     return 'SLOW FIELD';
      case ItemType.ghostMode:     return 'GHOST MODE';
      case ItemType.secondChance:  return 'SHIELD CORE';
      case ItemType.precisionCore: return 'PRECISION CORE';
    }
  }

  Color get color {
    switch (this) {
      case ItemType.slowField:     return const Color(0xFF00E5FF);
      case ItemType.ghostMode:     return const Color(0xFF9B30FF);
      case ItemType.secondChance:  return const Color(0xFFFFD700);
      case ItemType.precisionCore: return const Color(0xFFFF2D87);
    }
  }
}

// ── Item Component ────────────────────────────────────────────────────────────

class ItemComponent extends PositionComponent
    with HasGameReference<GravityFlipGame> {
  final ItemType type;

  double _age       = 0;
  bool   collected  = false;   // read by GravityFlipGame for manual pickup check
  final double _centerY;
  final double _bobOffset;

  static const double itemSize  = 42.0;
  static const double _bobAmp   = 6.0;
  static const double _bobSpeed = 2.2;

  ItemComponent({required Vector2 pos, required this.type})
      : _centerY   = pos.y,
        _bobOffset = Random().nextDouble() * 2 * pi,
        super(
          position: pos,
          size:     Vector2.all(itemSize),
          anchor:   Anchor.center,
        );

  @override
  void update(double dt) {
    _age       += dt;
    position.x -= game.difficultyManager.speed * dt;
    position.y  = _centerY + sin(_age * _bobSpeed + _bobOffset) * _bobAmp;
    if (position.x < -itemSize * 2) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final cx    = itemSize / 2;
    final cy    = itemSize / 2;
    final pulse = 0.55 + 0.45 * sin(_age * 2.8);

    switch (type) {
      case ItemType.slowField:
        _drawSlowField(canvas, cx, cy, pulse);
      case ItemType.ghostMode:
        _drawGhostMode(canvas, cx, cy, pulse);
      case ItemType.secondChance:
        _drawSecondChance(canvas, cx, cy, pulse);
      case ItemType.precisionCore:
        _drawPrecisionCore(canvas, cx, cy, pulse);
    }
  }

  // ── SLOW FIELD: Cyan circle, time-wave rings ──────────────────────────────
  void _drawSlowField(Canvas canvas, double cx, double cy, double pulse) {
    const c = Color(0xFF00E5FF);
    const r = itemSize / 2 - 2;

    // Outer glow
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color      = c.withValues(alpha: 0.08 + pulse * 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Background
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF001A28));

    // Border
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color       = c.withValues(alpha: 0.80 + pulse * 0.20)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, pulse * 3));

    // Three wave rings animating inward
    for (int i = 0; i < 3; i++) {
      final t  = ((_age * 1.1 + i / 3.0) % 1.0);
      final wr = r * 0.18 + t * r * 0.68;
      final wa = (1.0 - t) * 0.55;
      canvas.drawCircle(Offset(cx, cy), wr,
          Paint()
            ..color       = c.withValues(alpha: wa)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 3.2,
        Paint()
          ..color      = c
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pulse * 4));
  }

  // ── GHOST MODE: Diamond, purple + cyan, flicker ───────────────────────────
  void _drawGhostMode(Canvas canvas, double cx, double cy, double pulse) {
    const c1 = Color(0xFF9B30FF);
    const c2 = Color(0xFF00E5FF);
    final flicker = 0.60 + 0.40 * sin(_age * 9.0);
    const r = itemSize / 2 - 3;

    // Diamond path
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.78, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.78, cy)
      ..close();

    // Outer glow
    canvas.drawPath(path,
        Paint()
          ..color      = c1.withValues(alpha: 0.12 + pulse * 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Background fill (gradient via two layers)
    canvas.drawPath(path,
        Paint()..color = c1.withValues(alpha: 0.16 * flicker));
    canvas.drawPath(path,
        Paint()..color = c2.withValues(alpha: 0.08 * flicker));

    // Border
    canvas.drawPath(path,
        Paint()
          ..color       = c1.withValues(alpha: (0.80 + pulse * 0.20) * flicker)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, pulse * 2));

    // Inner smaller diamond
    final ir = r * 0.44;
    final inner = Path()
      ..moveTo(cx, cy - ir)
      ..lineTo(cx + ir * 0.78, cy)
      ..lineTo(cx, cy + ir)
      ..lineTo(cx - ir * 0.78, cy)
      ..close();
    canvas.drawPath(inner,
        Paint()
          ..color       = c2.withValues(alpha: 0.35 * flicker)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 2.6,
        Paint()..color = c2.withValues(alpha: flicker));
  }

  // ── SECOND CHANCE: Hexagon shield, gold ───────────────────────────────────
  void _drawSecondChance(Canvas canvas, double cx, double cy, double pulse) {
    const c = Color(0xFFFFD700);
    const r = itemSize / 2 - 2;

    // Hexagon path
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 - pi / 6;
      final x = cx + cos(a) * r;
      final y = cy + sin(a) * r;
      if (i == 0) hex.moveTo(x, y); else hex.lineTo(x, y);
    }
    hex.close();

    // Outer glow
    canvas.drawPath(hex,
        Paint()
          ..color      = c.withValues(alpha: 0.10 + pulse * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Background
    canvas.drawPath(hex, Paint()..color = const Color(0xFF1A1200));

    // Border
    canvas.drawPath(hex,
        Paint()
          ..color       = c.withValues(alpha: 0.80 + pulse * 0.20)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, pulse * 3));

    // Shield icon inside
    final sh = r * 0.60;
    final shield = Path();
    shield.moveTo(cx - sh * 0.52, cy - sh * 0.52);
    shield.lineTo(cx + sh * 0.52, cy - sh * 0.52);
    shield.lineTo(cx + sh * 0.52, cy + sh * 0.08);
    shield.quadraticBezierTo(cx + sh * 0.52, cy + sh * 0.65, cx, cy + sh * 0.90);
    shield.quadraticBezierTo(cx - sh * 0.52, cy + sh * 0.65, cx - sh * 0.52, cy + sh * 0.08);
    shield.close();
    canvas.drawPath(shield,
        Paint()
          ..color       = c.withValues(alpha: 0.40 + pulse * 0.20)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.3);

    // Shine stripe
    canvas.drawLine(
      Offset(cx - sh * 0.25, cy - sh * 0.12),
      Offset(cx + sh * 0.25, cy + sh * 0.35),
      Paint()
        ..color       = Colors.white.withValues(alpha: 0.28 + pulse * 0.18)
        ..strokeWidth = 1.5
        ..strokeCap   = StrokeCap.round,
    );
  }

  // ── PRECISION CORE: Circle, targeting reticle, pink ──────────────────────
  void _drawPrecisionCore(Canvas canvas, double cx, double cy, double pulse) {
    const c = Color(0xFFFF2D87);
    const r = itemSize / 2 - 2;

    // Outer glow
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color      = c.withValues(alpha: 0.08 + pulse * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Background
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF1A0010));

    // Rotating arc rings
    final rot  = _age * 1.2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2);
    canvas.drawArc(rect, rot, pi * 0.80, false,
        Paint()
          ..color       = c.withValues(alpha: 0.80 + pulse * 0.20)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap   = StrokeCap.round);
    canvas.drawArc(rect, rot + pi, pi * 0.80, false,
        Paint()
          ..color       = c.withValues(alpha: 0.45 + pulse * 0.15)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap   = StrokeCap.round);

    // Border circle
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color       = c.withValues(alpha: 0.55)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.0);

    // Crosshair ticks
    const gap    = 5.0;
    final tPaint = Paint()
      ..color       = c.withValues(alpha: 0.90)
      ..strokeWidth = 1.3
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - r + 2), Offset(cx, cy - gap), tPaint);
    canvas.drawLine(Offset(cx, cy + gap),   Offset(cx, cy + r - 2), tPaint);
    canvas.drawLine(Offset(cx - r + 2, cy), Offset(cx - gap, cy), tPaint);
    canvas.drawLine(Offset(cx + gap, cy),   Offset(cx + r - 2, cy), tPaint);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 3.0,
        Paint()
          ..color      = c
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pulse * 4));
  }
}
