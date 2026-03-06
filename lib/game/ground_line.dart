import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

class GroundLineComponent extends Component
    with HasGameReference<GravityFlipGame> {
  double _offset = 0;

  static const _accent = Color(0xFF00F5FF);
  static const double _dashLen = 22;
  static const double _gapLen  = 12;
  static const double _pattern = _dashLen + _gapLen;

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;
    _offset += game.difficultyManager.speed * dt;
    if (_offset > _pattern * 10) _offset -= _pattern * 10;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    final paint = Paint()
      ..color = _accent.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = _accent.withValues(alpha: 0.12)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, w, 2,     paint, glowPaint); // ceiling
    _drawDashedLine(canvas, w, h - 2, paint, glowPaint); // floor
  }

  void _drawDashedLine(
      Canvas canvas, double w, double y, Paint paint, Paint glowPaint) {
    var x = -(_offset % _pattern);
    while (x < w) {
      final x2 = min(x + _dashLen, w);
      canvas.drawLine(Offset(x,  y), Offset(x2, y), glowPaint);
      canvas.drawLine(Offset(x,  y), Offset(x2, y), paint);
      x += _pattern;
    }
  }
}
