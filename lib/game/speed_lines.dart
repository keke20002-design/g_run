import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

class _SLine {
  double x, y;
  final double len;
  final double speedMult;
  final double alpha;

  _SLine({
    required this.x,
    required this.y,
    required this.len,
    required this.speedMult,
    required this.alpha,
  });
}

class SpeedLinesComponent extends Component
    with HasGameReference<GravityFlipGame> {
  final List<_SLine> _lines = [];
  final Random _rng = Random(99);

  SpeedLinesComponent() : super(priority: -5);

  @override
  Future<void> onLoad() async => _populate();

  void _populate() {
    _lines.clear();
    final w = game.size.x;
    final h = game.size.y;
    for (int i = 0; i < 30; i++) {
      _lines.add(_SLine(
        x: _rng.nextDouble() * w * 1.5,
        y: _rng.nextDouble() * h,
        len: 40 + _rng.nextDouble() * 110,
        speedMult: 1.4 + _rng.nextDouble() * 1.2,
        alpha: 0.07 + _rng.nextDouble() * 0.11,
      ));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _populate();
  }

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;
    final gameSpeed = game.difficultyManager.speed;
    if (gameSpeed < 280) return;

    final w = game.size.x;
    final h = game.size.y;
    for (final l in _lines) {
      l.x -= gameSpeed * l.speedMult * dt;
      if (l.x + l.len < 0) {
        l.x = w + _rng.nextDouble() * 60;
        l.y = _rng.nextDouble() * h;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (game.state != GameState.playing) return;
    final gameSpeed = game.difficultyManager.speed;
    if (gameSpeed < 280) return;

    // Fade in: 0 at speed 280, full at speed 460
    final t = ((gameSpeed - 280) / 180.0).clamp(0.0, 1.0);

    for (final l in _lines) {
      canvas.drawLine(
        Offset(l.x, l.y),
        Offset(l.x - l.len, l.y),
        Paint()
          ..color       = const Color(0xFF00E5FF).withValues(alpha: l.alpha * t)
          ..strokeWidth = 0.8,
      );
    }
  }
}
