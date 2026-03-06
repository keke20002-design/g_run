import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

class RotatingObstacle extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {

  final double _rotSpeed;
  final double _oscillateAmplitude;
  final double _oscillateSpeed;
  double _oscillateTime = 0;
  double _baseY         = 0;

  double _spawnAge = 0;
  static const double _fadeInDuration = 0.12;

  static const double barLength = 72.0;
  static const double barWidth  = 10.0;

  static const Color _body = Color(0xFF0A240A);
  static const Color _edge = Color(0xFF44FF44);

  RotatingObstacle({
    required Vector2 pos,
    required double rotSpeed,
    double oscillateAmplitude = 55.0,
    double oscillateSpeed     = 1.8,
  })  : _rotSpeed          = rotSpeed,
        _oscillateAmplitude = oscillateAmplitude,
        _oscillateSpeed     = oscillateSpeed,
        super(
          position: pos,
          size: Vector2(barLength, barWidth),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    _baseY = position.y;
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    if (_spawnAge < _fadeInDuration) _spawnAge += dt;
    position.x -= game.difficultyManager.speed * dt;
    angle += _rotSpeed * dt;

    // Vertical oscillation
    _oscillateTime += dt;
    final newY = _baseY + sin(_oscillateTime * _oscillateSpeed) * _oscillateAmplitude;
    position.y = newY.clamp(barLength / 2, game.size.y - barLength / 2);

    if (position.x + barLength < 0) removeFromParent();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    game.killPlayer();
  }

  @override
  void render(Canvas canvas) {
    final fa   = (_spawnAge / _fadeInDuration).clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(0, 0, barLength, barWidth);

    // Outer glow
    canvas.drawRect(rect,
        Paint()
          ..color       = _edge.withValues(alpha: 0.40 * fa)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 9));
    // Body
    canvas.drawRect(rect, Paint()..color = _body.withValues(alpha: fa));
    // Edge outline
    canvas.drawRect(rect,
        Paint()
          ..color       = _edge.withValues(alpha: 0.90 * fa)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Center pivot dot
    canvas.drawCircle(Offset(barLength / 2, barWidth / 2), 3,
        Paint()..color = _edge.withValues(alpha: fa));
  }
}
