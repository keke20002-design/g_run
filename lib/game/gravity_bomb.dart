import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

// ── 중력 폭탄 (3000pts+) ───────────────────────────────────────────────────────
// 화면 우측 상단에서 왼쪽으로 이동하면서 아래로 낙하하는 장애물.
// 플레이어가 바닥에 있을 때 위협적이며 반중력 플립으로 회피 가능.

class GravityBomb extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  static const double radius = 18.0;

  static const Color _col  = Color(0xFFFF6B00); // 주황
  static const Color _hot  = Color(0xFFFFCC00); // 노란 코어
  static const Color _body = Color(0xFF1A0800);

  double _time     = 0;
  double _spawnAge = 0;
  static const double _fadeInDuration = 0.12;

  final double _fallSpeed; // px/s (아래 방향)

  GravityBomb({required Vector2 pos, required double fallSpeed})
      : _fallSpeed = fallSpeed,
        super(
          position: pos,
          size:     Vector2.all(radius * 2),
          anchor:   Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: radius - 5, collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < _fadeInDuration) _spawnAge += dt;
    _time += dt;
    position.x -= game.difficultyManager.speed * dt;
    position.y += _fallSpeed * dt;
    if (position.x < -radius * 4 || position.y > game.size.y + radius * 4) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (game.ghostModeActive) return;
    game.killPlayer();
  }

  @override
  void render(Canvas canvas) {
    final fa  = (_spawnAge / _fadeInDuration).clamp(0.0, 1.0);
    final cx  = radius;
    final cy  = radius;
    final pls = 0.60 + 0.40 * sin(_time * 5.2);

    // ── 낙하 불꽃 트레일 (위쪽) ─────────────────────────────────────────────
    for (int i = 0; i < 4; i++) {
      final t  = (_time * 2.8 + i * 0.25) % 1.0;
      final ty = cy - radius * 0.6 - t * radius * 2.4;
      final ta = (1.0 - t) * 0.70 * fa;
      final tr = (2.8 - t * 1.8).clamp(0.5, 3.0);
      final ox = (i % 2 == 0 ? 1 : -1) * 3.5 * sin(t * pi);
      canvas.drawCircle(
        Offset(cx + ox, ty),
        tr,
        Paint()
          ..color      = Color.lerp(_hot, _col, t)!.withValues(alpha: ta)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── 외부 헤일로 글로우 ───────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 7,
      Paint()
        ..color      = _col.withValues(alpha: pls * 0.38 * fa)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // ── 본체 ─────────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = _body.withValues(alpha: fa),
    );

    // ── 내부 글로우 필 ────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = _col.withValues(alpha: pls * 0.22 * fa),
    );

    // ── 엣지 링 ───────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color       = _col.withValues(alpha: 0.92 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color       = _col.withValues(alpha: pls * 0.55 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── 코어 열점 ─────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.32,
      Paint()
        ..color      = _hot.withValues(alpha: pls * 0.85 * fa)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pls * 5),
    );
  }
}
