import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'player.dart';

// ── 전기 구체 (9000pts+) ──────────────────────────────────────────────────────
// 둥근 장애물. 주변 전기 스파크 + 파티클. 상하로 이동.

class ElectricSphere extends PositionComponent
    with HasGameReference<GravityFlipGame> {
  static const double _r        = 20.0;
  static const double _bobAmp   = 38.0; // 상하 진폭 (px)
  static const double _bobSpeed = 1.6;  // 상하 속도 (rad/s)
  static const Color  _col = Color(0xFF00AAFF); // 파란 계열
  static const Color  _wht = Colors.white;

  double _time     = 0;
  double _spawnAge = 0;
  double _startY   = 0;
  final Random _rng;

  ElectricSphere({required Vector2 pos})
      : _rng = Random(pos.y.toInt() * 31 + 7),
        super(
          position: pos,
          size:     Vector2.all(_r * 2),
          anchor:   Anchor.center,
        ) {
    _startY = pos.y;
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < 0.15) _spawnAge += dt;
    _time += dt;

    // 좌측 이동
    position.x -= game.difficultyManager.speed * dt;
    // 상하 이동
    position.y = _startY + sin(_time * _bobSpeed) * _bobAmp;

    if (position.x < -_r * 4) { removeFromParent(); return; }

    // 직접 거리 계산으로 플레이어 충돌 체크
    if (!game.player.isDead && !game.ghostModeActive) {
      final px   = game.player.position.x + Player.playerSize / 2;
      final py   = game.player.position.y + Player.playerSize / 2;
      final dx   = position.x - px;
      final dy   = position.y - py;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < _r + Player.playerSize / 2 - 2) {
        game.killPlayer();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final fa  = (_spawnAge / 0.15).clamp(0.0, 1.0);
    final cx  = _r;
    final cy  = _r;
    final pls = 0.65 + 0.35 * sin(_time * 4.2);

    // 외부 헤일로 글로우
    canvas.drawCircle(
      Offset(cx, cy), _r + 6,
      Paint()
        ..color      = _col.withValues(alpha: pls * 0.35 * fa)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // 본체 (어두운 내부)
    canvas.drawCircle(
      Offset(cx, cy), _r,
      Paint()..color = const Color(0xFF00101A).withValues(alpha: fa),
    );
    // 내부 glow fill
    canvas.drawCircle(
      Offset(cx, cy), _r,
      Paint()..color = _col.withValues(alpha: pls * 0.20 * fa),
    );
    // 엣지 링
    canvas.drawCircle(
      Offset(cx, cy), _r,
      Paint()
        ..color       = _col.withValues(alpha: 0.90 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      Offset(cx, cy), _r,
      Paint()
        ..color       = _col.withValues(alpha: pls * 0.50 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 전기 스파크 (8개, 표면에서 바깥으로)
    final sp = Paint()
      ..strokeWidth = 0.9
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final baseA = (i / 8) * 2 * pi + _time * 2.5;
      final len   = 7 + 7 * sin(_time * 9 + i * 1.9).abs();
      final alpha = fa * (0.4 + 0.6 * sin(_time * 12 + i * 2.1).abs());
      final sx    = cx + cos(baseA) * (_r - 1);
      final sy    = cy + sin(baseA) * (_r - 1);
      final midA  = baseA + (_rng.nextDouble() - 0.5) * 0.7;
      final midD  = _r + len * 0.45;
      final mx    = cx + cos(midA) * midD;
      final my    = cy + sin(midA) * midD;
      final endA  = baseA + (_rng.nextDouble() - 0.5) * 0.5;
      final ex    = cx + cos(endA) * (_r + len);
      final ey    = cy + sin(endA) * (_r + len);

      final path = Path()
        ..moveTo(sx, sy)
        ..lineTo(mx, my)
        ..lineTo(ex, ey);

      sp.color      = _col.withValues(alpha: alpha * 0.90);
      sp.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawPath(path, sp);

      sp.maskFilter = null;
      sp.color      = _wht.withValues(alpha: alpha * 0.55);
      canvas.drawPath(path, sp);
    }
  }
}
