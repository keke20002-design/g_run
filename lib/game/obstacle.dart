import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

enum ObstacleSide    { top, bottom }
enum ObstacleVariant { pillar, spike, gate, moving, popWall }

/// Per-variant color theme
class _Theme {
  final Color body;
  final Color edge;
  const _Theme(this.body, this.edge);
}

const _themes = {
  ObstacleVariant.pillar : _Theme(Color(0xFF1D3A58), Color(0xFF5BC8F0)), // blue-gray
  ObstacleVariant.spike  : _Theme(Color(0xFF3D0F0F), Color(0xFFFF4555)), // danger red
  ObstacleVariant.gate   : _Theme(Color(0xFF261A52), Color(0xFFBB88FF)), // warning purple
  ObstacleVariant.moving : _Theme(Color(0xFF0D3030), Color(0xFF00DEB5)), // active teal
  ObstacleVariant.popWall: _Theme(Color(0xFF3A1A00), Color(0xFFFF8C00)), // pop orange
};

class Obstacle extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  final ObstacleSide    side;
  final ObstacleVariant variant;
  final double obstacleHeight;
  final bool   isSlim;
  final bool   isMoving;
  final double oscillateAmplitude;

  bool passed          = false;
  bool nearMissChecked = false;

  double _oscillateTime = 0;
  final double _baseY;

  late double _spawnAge;
  static const double _fadeInDuration = 0.10;

  static double _widthFor(bool slim) => slim ? 14.0 : 28.0;

  Obstacle({
    required Vector2 pos,
    required this.side,
    required this.obstacleHeight,
    this.variant            = ObstacleVariant.pillar,
    this.isSlim             = false,
    this.isMoving           = false,
    this.oscillateAmplitude = 0,
    bool isInstant          = false,
  })  : _baseY    = pos.y,
        _spawnAge = isInstant ? _fadeInDuration : 0.0,
        super(
          position: pos,
          size: Vector2(_widthFor(isSlim), obstacleHeight),
        );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      size: Vector2(size.x - 3, obstacleHeight - 2),
      position: Vector2(1.5, 1),
    ));
  }

  @override
  void update(double dt) {
    if (_spawnAge < _fadeInDuration) _spawnAge += dt;
    position.x -= game.difficultyManager.speed * dt;
    if (position.x + size.x < 0) {
      removeFromParent();
      return;
    }
    if (isMoving) {
      _oscillateTime += dt;
      final newY = _baseY + sin(_oscillateTime * 1.5) * oscillateAmplitude;
      position.y = newY.clamp(0.0, game.size.y - obstacleHeight);
    }
  }

  @override
  void render(Canvas canvas) {
    final fa     = (_spawnAge / _fadeInDuration).clamp(0.0, 1.0);
    final theme  = _themes[variant]!;
    final radius = isSlim ? 4.0 : 12.0;
    final rrect  = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(radius),
    );

    // ── Outer neon glow ────────────────────────────────────────────
    canvas.drawRRect(
      rrect,
      Paint()
        ..color       = theme.edge.withValues(alpha: 0.50 * fa)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = isSlim ? 5.0 : 9.0
        ..maskFilter  = MaskFilter.blur(BlurStyle.normal, isSlim ? 6.0 : 11.0),
    );

    // ── Body ──────────────────────────────────────────────────────
    canvas.drawRRect(rrect, Paint()..color = theme.body.withValues(alpha: fa));

    // ── Moving variant: pulsing fill glow ─────────────────────────
    if (isMoving) {
      final pulse = sin(_oscillateTime * 1.5) * 0.5 + 0.5;
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = theme.edge.withValues(alpha: (0.08 + pulse * 0.12) * fa)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Spike variant: visible inner stroke ───────────────────────
    if (isSlim) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color       = theme.edge.withValues(alpha: 0.28 * fa)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Danger-tip bright edge (the exposed pointy end) ───────────
    // bottom obstacle → tip is at top (y=0); top obstacle → tip at bottom
    final tipY = side == ObstacleSide.bottom ? 0.5 : size.y - 0.5;

    // Glow behind the edge line
    canvas.drawLine(
      Offset(radius * 0.4, tipY),
      Offset(size.x - radius * 0.4, tipY),
      Paint()
        ..color       = theme.edge.withValues(alpha: 0.55 * fa)
        ..strokeWidth = isSlim ? 5.0 : 4.0
        ..style       = PaintingStyle.stroke
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Sharp edge line on top
    canvas.drawLine(
      Offset(radius * 0.4, tipY),
      Offset(size.x - radius * 0.4, tipY),
      Paint()
        ..color       = theme.edge.withValues(alpha: fa)
        ..strokeWidth = isSlim ? 2.0 : 1.5
        ..style       = PaintingStyle.stroke,
    );
  }
}
