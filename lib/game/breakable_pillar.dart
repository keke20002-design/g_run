import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'player.dart' show Player;

// ── 파편 ──────────────────────────────────────────────────────────────────────
class _Frag {
  double x, y, vx, vy, rot, rotV, age;
  final double size;
  _Frag(this.x, this.y, this.vx, this.vy, this.rot, this.rotV, this.size)
      : age = 0;
}

enum PillarSide { top, bottom }

// ── 깨지는 기둥 ───────────────────────────────────────────────────────────────
// 위/아래에 붙어있는 기둥. 플레이어가 같은 면에 있을 때 자연스럽게 충돌 → 산산조각.
// 죽지 않고 점수 보너스.

class BreakablePillar extends PositionComponent
    with HasGameReference<GravityFlipGame> {
  static const double _w    = 30.0;
  static const Color  _col  = Color(0xFFFF8F00); // 진한 앰버
  static const Color  _colLt = Color(0xFFFFD54F); // 밝은 앰버
  static const Color  _body  = Color(0xFF1E0D00);

  final PillarSide side;
  final double     pillarHeight;

  double _time     = 0;
  double _spawnAge = 0;
  bool   _broken   = false;
  double _breakAge = 0;

  // 플레이어 y 유예 추적
  bool   _playerNearY      = false;
  double _playerNearYTimer = 0.0;
  static const double _yGraceDuration = 0.45;

  final List<_Frag> _frags = [];
  final Random      _rng   = Random();

  bool get isBroken            => _broken;
  bool get playerPassedThroughY => _playerNearY;

  BreakablePillar({
    required Vector2   pos,
    required this.side,
    required this.pillarHeight,
  }) : super(position: pos, size: Vector2(_w, pillarHeight));

  bool tryBreak() {
    if (_broken) return false;
    _shatter();
    return true;
  }

  void _shatter() {
    if (_broken) return;
    _broken = true;
    // 기둥 파편: 위아래 방향 위주로 날아감
    for (int i = 0; i < 16; i++) {
      final isEdge = i < 6;
      final a  = isEdge
          ? (side == PillarSide.top ? 0.0 : pi) + (_rng.nextDouble() - 0.5) * pi
          : _rng.nextDouble() * 2 * pi;
      final sp = 60 + _rng.nextDouble() * 140;
      final sz = 3.0 + _rng.nextDouble() * 6;
      _frags.add(_Frag(
        _rng.nextDouble() * _w,
        _rng.nextDouble() * pillarHeight,
        cos(a) * sp,
        sin(a) * sp,
        _rng.nextDouble() * 2 * pi,
        (_rng.nextDouble() - 0.5) * 15,
        sz,
      ));
    }
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < 0.12) _spawnAge += dt;
    _time += dt;

    position.x -= game.difficultyManager.speed * dt;

    // 플레이어 y 추적 (유예)
    if (!_broken && !game.player.isDead) {
      const ps = Player.playerSize;
      final py = game.player.position.y;
      if (py < position.y + pillarHeight && py + ps > position.y) {
        _playerNearY      = true;
        _playerNearYTimer = _yGraceDuration;
      } else if (_playerNearYTimer > 0) {
        _playerNearYTimer -= dt;
        if (_playerNearYTimer <= 0) _playerNearY = false;
      }
    }

    if (_broken) {
      _breakAge += dt;
      for (final f in _frags) {
        f.x   += f.vx * dt;
        f.y   += f.vy * dt;
        f.vy  += 450 * dt;
        f.vx  *= 0.97;
        f.rot += f.rotV * dt;
        f.age += dt;
      }
      if (_breakAge > 0.60) removeFromParent();
      return;
    }

    if (position.x + _w < 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_broken) {
      for (final f in _frags) {
        final lifeT = (f.age / 0.60).clamp(0.0, 1.0);
        final alpha = (1.0 - lifeT) * (_spawnAge / 0.12).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(f.x, f.y);
        canvas.rotate(f.rot);
        final half = f.size / 2;
        canvas.drawRect(
          Rect.fromLTWH(-half, -half, f.size, f.size),
          Paint()..color = _col.withValues(alpha: alpha * 0.90),
        );
        canvas.drawRect(
          Rect.fromLTWH(-half, -half, f.size, f.size),
          Paint()
            ..color       = _colLt.withValues(alpha: alpha * 0.65)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
        canvas.restore();
      }
      return;
    }

    final fa    = (_spawnAge / 0.12).clamp(0.0, 1.0);
    final pulse = 0.50 + 0.50 * sin(_time * 4.5);
    final rect  = Rect.fromLTWH(0, 0, _w, pillarHeight);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // 외부 글로우
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = _col.withValues(alpha: pulse * 0.38 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // 본체
    canvas.drawRRect(rrect, Paint()..color = _body.withValues(alpha: fa));

    // 수직 균열선 (기둥 느낌)
    final crackPaint = Paint()
      ..color       = _colLt.withValues(alpha: 0.45 * fa)
      ..strokeWidth = 0.85
      ..style       = PaintingStyle.stroke;

    // 왼쪽 균열
    canvas.drawLine(Offset(_w * 0.28, 0),              Offset(_w * 0.20, pillarHeight * 0.38), crackPaint);
    canvas.drawLine(Offset(_w * 0.20, pillarHeight * 0.38), Offset(_w * 0.33, pillarHeight * 0.70), crackPaint);
    canvas.drawLine(Offset(_w * 0.33, pillarHeight * 0.70), Offset(_w * 0.26, pillarHeight), crackPaint);

    // 오른쪽 균열
    canvas.drawLine(Offset(_w * 0.70, 0),              Offset(_w * 0.78, pillarHeight * 0.45), crackPaint);
    canvas.drawLine(Offset(_w * 0.78, pillarHeight * 0.45), Offset(_w * 0.65, pillarHeight * 0.72), crackPaint);
    canvas.drawLine(Offset(_w * 0.65, pillarHeight * 0.72), Offset(_w * 0.74, pillarHeight), crackPaint);

    // 엣지
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = _colLt.withValues(alpha: 0.88 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // 중앙 ✕ 아이콘 (중간 위치)
    final cx = _w / 2;
    final cy = pillarHeight / 2;
    final ic = Paint()
      ..color       = _colLt.withValues(alpha: 0.48 * fa)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    canvas.drawLine(Offset(cx - 5, cy - 5), Offset(cx + 5, cy + 5), ic);
    canvas.drawLine(Offset(cx + 5, cy - 5), Offset(cx - 5, cy + 5), ic);

    // 상단/하단 강조 라인 (어느 면에 붙어있는지 시각적으로)
    final rootPaint = Paint()
      ..color       = _colLt.withValues(alpha: 0.70 * fa * pulse)
      ..strokeWidth = 2.0;
    if (side == PillarSide.top) {
      canvas.drawLine(const Offset(0, 0), Offset(_w, 0), rootPaint);
    } else {
      canvas.drawLine(Offset(0, pillarHeight), Offset(_w, pillarHeight), rootPaint);
    }
  }
}
