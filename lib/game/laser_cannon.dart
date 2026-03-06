import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'player.dart';

enum _Phase { warning, charging, firing, done }

// ── 레이저 캐논 (8000pts+) ───────────────────────────────────────────────────
// 벽에 붙은 캐논. 0.8s 경고 → 1.0s 충전 → 0.35s 레이저 발사 → 제거.

class LaserCannon extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  static const double _cw         = 34.0;
  static const double _ch         = 20.0;
  static const double _warnDur    = 0.80;
  static const double _chargeDur  = 1.00;
  static const double _fireDur    = 0.35;
  static const double _doneDur    = 0.30;
  static const Color  _col        = Color(0xFFFF2222);
  static const Color  _colLt      = Color(0xFFFF8888);

  final bool isTop;   // true = 천장 캐논, false = 바닥 캐논
  _Phase _phase    = _Phase.warning;
  double _phaseT   = 0;
  RectangleHitbox? _beam;

  LaserCannon({required Vector2 pos, required this.isTop})
      : super(position: pos, size: Vector2(_cw, _ch));

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    position.x -= game.difficultyManager.speed * dt;
    if (position.x + _cw < 0) { removeFromParent(); return; }

    _phaseT += dt;
    switch (_phase) {
      case _Phase.warning:
        if (_phaseT >= _warnDur) { _phase = _Phase.charging; _phaseT = 0; }
      case _Phase.charging:
        if (_phaseT >= _chargeDur) { _fire(); }
      case _Phase.firing:
        if (_phaseT >= _fireDur)   { _endFire(); }
      case _Phase.done:
        if (_phaseT >= _doneDur)   { removeFromParent(); }
    }
  }

  void _fire() {
    _phase  = _Phase.firing;
    _phaseT = 0;
    game.triggerLaserFlash();

    // 레이저 히트박스: 캐논 면 기준 ±screenW 범위, 높이 50px
    final beamY = isTop ? _ch.toDouble() : -50.0;
    _beam = RectangleHitbox(
      position: Vector2(-game.size.x, beamY),
      size:     Vector2(game.size.x * 3, 50),
    );
    add(_beam!);
  }

  void _endFire() {
    _phase  = _Phase.done;
    _phaseT = 0;
    _beam?.removeFromParent();
    _beam = null;
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_phase == _Phase.firing && other is Player) {
      game.killPlayer();
    }
  }

  @override
  void render(Canvas canvas) {
    final bodyY  = isTop ? 0.0 : 2.0;
    final bodyH  = _ch - 2;
    final nozzleY = isTop ? _ch - 6.0 : 2.0;
    final nozzleH = 6.0;
    final cx     = _cw / 2;

    // 캐논 본체
    final bodyR = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, bodyY, _cw - 6, bodyH),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyR, Paint()..color = const Color(0xFF2A0000));
    canvas.drawRRect(
      bodyR,
      Paint()
        ..color       = _col.withValues(alpha: 0.70)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 노즐
    canvas.drawRect(
      Rect.fromLTWH(cx - 5, nozzleY, 10, nozzleH),
      Paint()..color = const Color(0xFF1A0000),
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - 5, nozzleY, 10, nozzleH),
      Paint()
        ..color       = _colLt.withValues(alpha: 0.85)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 경고 단계: 빠른 펄스
    if (_phase == _Phase.warning) {
      final p = sin(_phaseT * 18) * 0.5 + 0.5;
      canvas.drawRRect(
        bodyR,
        Paint()
          ..color      = _col.withValues(alpha: p * 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 충전 단계: 성장하는 glow
    if (_phase == _Phase.charging) {
      final progress = (_phaseT / _chargeDur).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, isTop ? _ch.toDouble() : 0.0),
        3 + progress * 14,
        Paint()
          ..color      = _col.withValues(alpha: progress * 0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + progress * 10),
      );
      // 충전 링 (2개)
      for (int r = 0; r < 2; r++) {
        final ring = progress * (8 + r * 6);
        canvas.drawCircle(
          Offset(cx, isTop ? _ch.toDouble() : 0.0),
          ring,
          Paint()
            ..color       = _colLt.withValues(alpha: (1 - progress) * 0.50)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // 발사 단계: 레이저 빔
    if (_phase == _Phase.firing) {
      final prog  = (_phaseT / _fireDur).clamp(0.0, 1.0);
      final alpha = 1.0 - prog * 0.45;
      final beamY = isTop ? _ch : -4.0;
      final sw    = game.size.x;

      // 외부 글로우
      canvas.drawRect(
        Rect.fromLTWH(-sw, beamY - 8, sw * 3, 16),
        Paint()
          ..color      = _col.withValues(alpha: 0.28 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // 코어 빔
      canvas.drawRect(
        Rect.fromLTWH(-sw, beamY - 2, sw * 3, 5),
        Paint()..color = Colors.white.withValues(alpha: 0.90 * alpha),
      );
      canvas.drawRect(
        Rect.fromLTWH(-sw, beamY - 4, sw * 3, 9),
        Paint()..color = _col.withValues(alpha: 0.80 * alpha),
      );
    }
  }
}
