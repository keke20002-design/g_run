import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'obstacle.dart' show ObstacleSide;

// ── 에너지 장벽 (2000pts+) ─────────────────────────────────────────────────────
// 투명한 전기 빛 기둥. 깜빡이는 alpha + 수직 전기선.

class EnergyBarrier extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  final ObstacleSide side;
  final double barrierHeight;

  double _time    = 0;
  double _spawnAge = 0;
  static const double _fadeIn = 0.12;
  static const double _width  = 16.0;
  static const Color  _col    = Color(0xFF00EEFF);

  bool passed          = false;
  bool nearMissChecked = false;

  EnergyBarrier({
    required Vector2 pos,
    required this.side,
    required this.barrierHeight,
  }) : super(position: pos, size: Vector2(_width, barrierHeight));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size:     Vector2(_width - 4, barrierHeight - 2),
      position: Vector2(2, 1),
    ));
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    if (_spawnAge < _fadeIn) _spawnAge += dt;
    _time += dt;
    position.x -= game.difficultyManager.speed * dt;
    if (position.x + _width < 0) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    game.killPlayer();
  }

  @override
  void render(Canvas canvas) {
    final fa      = (_spawnAge / _fadeIn).clamp(0.0, 1.0);
    final flicker = 0.60 + 0.40 * sin(_time * 17.0 + sin(_time * 6.3) * 2.5);
    final alpha   = fa * flicker;
    final rect    = Rect.fromLTWH(0, 0, size.x, size.y);

    // 외부 글로우
    canvas.drawRect(
      rect,
      Paint()
        ..color       = _col.withValues(alpha: alpha * 0.55)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // 코어 채우기
    canvas.drawRect(
      rect,
      Paint()..color = _col.withValues(alpha: alpha * 0.14),
    );
    // 엣지 선
    canvas.drawRect(
      rect,
      Paint()
        ..color       = _col.withValues(alpha: alpha * 0.95)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 수직 전기선 (3개, 각각 다른 주파수로 흔들림)
    final rng = Random(99);
    for (int i = 0; i < 3; i++) {
      final x         = (i + 1) * _width / 4;
      final lineAlpha = alpha * (0.35 + 0.65 * sin(_time * (11.0 + i * 4.7) + i));
      final path      = Path();
      path.moveTo(x, 0);
      double y = 0;
      while (y < size.y) {
        y += 10 + rng.nextDouble() * 16;
        final jit = (rng.nextDouble() - 0.5) * 4.5;
        path.lineTo(x + jit, y.clamp(0, size.y));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color       = _col.withValues(alpha: lineAlpha)
          ..strokeWidth = 0.9
          ..style       = PaintingStyle.stroke
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // 위험 끝 엣지
    final tipY = side == ObstacleSide.bottom ? 0.5 : size.y - 0.5;
    canvas.drawLine(
      Offset(0, tipY), Offset(size.x, tipY),
      Paint()
        ..color       = _col.withValues(alpha: alpha)
        ..strokeWidth = 2.5
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}
