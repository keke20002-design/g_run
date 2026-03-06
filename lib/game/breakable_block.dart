import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'player.dart';

// ── 파편 데이터 ────────────────────────────────────────────────────────────────
class _Frag {
  double x, y, vx, vy, rot, rotV, age;
  final double size;
  _Frag(this.x, this.y, this.vx, this.vy, this.rot, this.rotV, this.size)
      : age = 0;
}

// ── 깨지는 블록 (3000pts+) ────────────────────────────────────────────────────
// 플레이어가 닿으면 죽지 않고 블록이 산산조각 남. 점수 보너스.

class BreakableBlock extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  static const double _sz    = 36.0;
  static const Color  _col   = Color(0xFFFFB300);
  static const Color  _colLt = Color(0xFFFFE082);
  static const Color  _body  = Color(0xFF3A2000);

  double _time     = 0;
  double _spawnAge = 0;
  bool   _broken   = false;
  double _breakAge = 0;

  final List<_Frag> _frags = [];
  final Random _rng = Random();

  bool passed          = false;
  bool nearMissChecked = false;

  BreakableBlock({required Vector2 pos})
      : super(position: pos, size: Vector2.all(_sz));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  void _shatter() {
    if (_broken) return;
    _broken = true;
    // 점수 보너스 (near miss 등록)
    game.scoreSystem.registerNearMiss();
    // 히트박스 제거
    children.whereType<RectangleHitbox>().toList()
        .forEach((h) => h.removeFromParent());
    // 파편 생성
    final cx = _sz / 2;
    final cy = _sz / 2;
    for (int i = 0; i < 12; i++) {
      final a  = _rng.nextDouble() * 2 * pi;
      final sp = 80 + _rng.nextDouble() * 120;
      final sz = 4.0 + _rng.nextDouble() * 8;
      _frags.add(_Frag(
        cx, cy,
        cos(a) * sp, sin(a) * sp,
        _rng.nextDouble() * 2 * pi,
        (_rng.nextDouble() - 0.5) * 12,
        sz,
      ));
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player && !other.isDead && !_broken) {
      _shatter();
    }
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < 0.12) _spawnAge += dt;
    _time += dt;

    position.x -= game.difficultyManager.speed * dt;

    if (_broken) {
      _breakAge += dt;
      for (final f in _frags) {
        f.x   += f.vx * dt;
        f.y   += f.vy * dt;
        f.vy  += 500 * dt; // 중력
        f.vx  *= 0.96;
        f.rot += f.rotV * dt;
        f.age += dt;
      }
      if (_breakAge > 0.55) removeFromParent();
      return;
    }

    if (position.x + _sz < 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_broken) {
      // 파편 렌더
      for (final f in _frags) {
        final lifeT = (f.age / 0.55).clamp(0.0, 1.0);
        final alpha = (1.0 - lifeT) * (_spawnAge / 0.12).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(f.x, f.y);
        canvas.rotate(f.rot);
        final half = f.size / 2;
        canvas.drawRect(
          Rect.fromLTWH(-half, -half, f.size, f.size),
          Paint()..color = _col.withValues(alpha: alpha * 0.85),
        );
        canvas.drawRect(
          Rect.fromLTWH(-half, -half, f.size, f.size),
          Paint()
            ..color       = _colLt.withValues(alpha: alpha * 0.70)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        canvas.restore();
      }
      return;
    }

    final fa    = (_spawnAge / 0.12).clamp(0.0, 1.0);
    final pulse = 0.55 + 0.45 * sin(_time * 3.5);
    final rect  = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // 외부 글로우
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = _col.withValues(alpha: pulse * 0.40 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // 본체
    canvas.drawRRect(rrect, Paint()..color = _body.withValues(alpha: fa));

    // 균열선 (3개)
    final crackPaint = Paint()
      ..color       = _colLt.withValues(alpha: 0.50 * fa)
      ..strokeWidth = 0.9
      ..style       = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.x * 0.28, 0), Offset(size.x * 0.48, size.y * 0.55), crackPaint);
    canvas.drawLine(
      Offset(size.x * 0.48, size.y * 0.55), Offset(size.x * 0.72, size.y), crackPaint);
    canvas.drawLine(
      Offset(size.x * 0.62, 0), Offset(size.x * 0.38, size.y * 0.45), crackPaint);

    // 엣지
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = _colLt.withValues(alpha: 0.88 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 중앙 아이콘 (×)
    final cx = size.x / 2;
    final cy = size.y / 2;
    final ic = Paint()
      ..color       = _colLt.withValues(alpha: 0.50 * fa)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(Offset(cx - 5, cy - 5), Offset(cx + 5, cy + 5), ic);
    canvas.drawLine(Offset(cx + 5, cy - 5), Offset(cx - 5, cy + 5), ic);
  }
}
