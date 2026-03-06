import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

class GravZone extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {

  bool   _triggered  = false;
  double _spawnAge   = 0;
  double _pulseTimer = 0;

  static const double _fadeInDuration = 0.18;
  static const double zoneWidth       = 52.0;

  static const Color _body = Color(0xFF1A0035);
  static const Color _edge = Color(0xFFCC44FF);

  GravZone({required Vector2 pos, required double height})
      : super(
          position: pos,
          size: Vector2(zoneWidth, height),
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < _fadeInDuration) _spawnAge += dt;
    _pulseTimer += dt;
    position.x -= game.difficultyManager.speed * dt;
    if (position.x + zoneWidth < 0) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (!_triggered) {
      _triggered = true;
      game.flipPlayer();
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    _triggered = false; // allow flip again on re-entry
  }

  @override
  void render(Canvas canvas) {
    final fa    = (_spawnAge / _fadeInDuration).clamp(0.0, 1.0);
    final pulse = 0.55 + 0.45 * sin(_pulseTimer * 3.2);
    final rect  = Rect.fromLTWH(0, 0, size.x, size.y);

    // Body fill
    canvas.drawRect(
      rect,
      Paint()..color = _body.withValues(alpha: (0.50 + pulse * 0.20) * fa),
    );

    // Inner glow
    canvas.drawRect(
      rect,
      Paint()
        ..color       = _edge.withValues(alpha: 0.28 * pulse * fa)
        ..style       = PaintingStyle.fill,
    );

    // Outer glow stroke
    canvas.drawRect(
      rect,
      Paint()
        ..color       = _edge.withValues(alpha: 0.40 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Edge outline
    canvas.drawRect(
      rect,
      Paint()
        ..color       = _edge.withValues(alpha: 0.90 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Gravity arrows — drawn vertically every 60px
    final arrowPaint = Paint()
      ..color       = _edge.withValues(alpha: 0.65 * fa)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final cx      = size.x / 2;
    final nArrows = (size.y / 60).ceil();
    for (int i = 0; i < nArrows; i++) {
      final y  = 30.0 + i * 60.0 + (_pulseTimer * 20) % 60;
      if (y > size.y) continue;
      // Up arrow
      final path = Path()
        ..moveTo(cx, y - 8)
        ..lineTo(cx, y + 8)
        ..moveTo(cx - 5, y - 3)
        ..lineTo(cx, y - 8)
        ..lineTo(cx + 5, y - 3);
      canvas.drawPath(path, arrowPaint);
    }
  }
}
