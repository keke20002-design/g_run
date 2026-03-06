import 'dart:math';
import 'package:flutter/material.dart';

/// Shared skin preview painter used in both the main screen demo wheel
/// and the skin shop preview panel / card icons.
///
/// Pass an [AnimationController] as [repaint] so the painter self-ticks
/// at 60 fps and computes wall-clock time internally — guaranteeing that
/// the card icons and the preview panel always show the same frame.
class SkinPreviewPainter extends CustomPainter {
  final Color color;
  final double glowT;
  final String? skinId;

  SkinPreviewPainter({
    required this.color,
    required this.glowT,
    this.skinId,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = (size.width / 2) * 0.82;

    // Wall-clock time — computed inside paint() so both preview and card
    // always show an identical frame regardless of rebuild timing.
    final pTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    canvas.translate(cx, cy);

    if (skinId == 'glitch_ghost') {
      if ((pTime * 1000).toInt() % 24 < 6) {
        canvas.translate(
          Random().nextDouble() * 2 - 1.0,
          Random().nextDouble() * 2 - 1.0,
        );
      }
    }

    // Inner core fill
    if (skinId == 'solar_flare') {
      canvas.drawCircle(
        Offset.zero, radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.yellow, color, const Color(0xFF0F1B2E)],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius))
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawCircle(
        Offset.zero, radius,
        Paint()..color = const Color(0xFF0F1B2E)..style = PaintingStyle.fill,
      );
    }

    switch (skinId) {
      case 'classic_neon':
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.stroke
              ..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
        final sP = Paint()..color = color.withValues(alpha: 0.75)
          ..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
        final sA = pTime * (2 * pi / 1.6);
        for (int i = 0; i < 4; i++) {
          final a = sA + i * pi / 2;
          canvas.drawLine(Offset.zero,
              Offset(cos(a) * (radius - 4), sin(a) * (radius - 4)), sP);
        }

      case 'dual_core':
        // Outer ring: rotating with 4 orbit dots
        canvas.save();
        canvas.rotate(pTime * 2.0);
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3);
        for (int i = 0; i < 4; i++) {
          final a = i * pi / 2;
          canvas.drawCircle(Offset(cos(a) * radius, sin(a) * radius), 3.0,
              Paint()..color = color);
        }
        canvas.restore();
        // Inner ring: counter-rotating with visible pulse
        final pulse = 1.0 + sin(pTime * 5) * 0.18;
        canvas.save();
        canvas.rotate(-pTime * 3.0);
        canvas.drawCircle(Offset.zero, radius * 0.6 * pulse,
            Paint()..color = color.withValues(alpha: 0.7)..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        canvas.restore();

      case 'pulse_core':
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color.withValues(alpha: 0.3)..style = PaintingStyle.stroke);
        final pulse = 0.4 + (sin(pTime * 4) + 1) / 2 * 0.6;
        canvas.drawCircle(Offset.zero, radius * 0.4 * pulse,
            Paint()..color = color);

      case 'black_hole_core':
        canvas.drawCircle(Offset.zero, radius * 0.35, Paint()..color = Colors.black);
        canvas.drawCircle(Offset.zero, radius * 0.38,
            Paint()..color = const Color(0xFF4A0080)..style = PaintingStyle.stroke
              ..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        for (int i = 0; i < 12; i++) {
          final frac = i / 12;
          final a = pTime * 2.5 + frac * 2 * pi;
          final d = radius * (0.55 + frac * 0.45);
          canvas.drawCircle(Offset(cos(a) * d, sin(a) * d * 0.45),
              1.5 + frac * 1.5,
              Paint()..color = color.withValues(alpha: 0.3 + frac * 0.6));
        }
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color.withValues(alpha: 0.3)..style = PaintingStyle.stroke
              ..strokeWidth = 1.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

      case 'prism_glass':
        final hexPath = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i * pi / 3) - pi / 6;
          final x = cos(a) * radius;
          final y = sin(a) * radius;
          if (i == 0) { hexPath.moveTo(x, y); } else { hexPath.lineTo(x, y); }
        }
        hexPath.close();
        canvas.drawPath(hexPath, Paint()..color = color.withValues(alpha: 0.08));
        canvas.drawPath(hexPath,
            Paint()..color = color.withValues(alpha: 0.7)..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        const rbow = [Color(0xFFFF0000), Color(0xFFFF7700), Color(0xFFFFFF00),
                      Color(0xFF00FF00), Color(0xFF0088FF), Color(0xFF8800FF)];
        for (int i = 0; i < 5; i++) {
          final phase = pTime * 1.5 + i * 2 * pi / 5;
          canvas.drawLine(
              Offset(cos(phase) * radius * 0.8, sin(phase) * radius * 0.8),
              Offset(cos(phase + pi * 0.6) * radius * 0.5,
                  sin(phase + pi * 0.6) * radius * 0.5),
              Paint()..color = rbow[i % rbow.length].withValues(alpha: 0.6)
                ..strokeWidth = 1.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        }

      case 'electric_pulse':
        final epPulse = 0.7 + sin(pTime * 12) * 0.15;
        canvas.drawCircle(Offset.zero, radius * 0.3 * epPulse,
            Paint()..color = Colors.white.withValues(alpha: 0.85)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color.withValues(alpha: 0.18)
              ..style = PaintingStyle.stroke..strokeWidth = 1.5);
        final bRng = Random(42);
        for (int b = 0; b < 4; b++) {
          final sA = bRng.nextDouble() * 2 * pi + pTime * 2.5;
          final eA = sA + pi * (0.4 + bRng.nextDouble() * 0.6);
          final path = Path();
          for (int s = 0; s <= 4; s++) {
            final t = s / 4;
            final a = sA + (eA - sA) * t;
            final r = radius * (0.4 + bRng.nextDouble() * 0.5);
            if (s == 0) {
              path.moveTo(cos(a) * r, sin(a) * r);
            } else {
              path.lineTo(cos(a) * r + bRng.nextDouble() * 4 - 2,
                  sin(a) * r + bRng.nextDouble() * 4 - 2);
            }
          }
          canvas.drawPath(path,
              Paint()..color = color..style = PaintingStyle.stroke
                ..strokeWidth = 1.8..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        }

      case 'cyberpunk_wheel':
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color..style = PaintingStyle.stroke
              ..strokeWidth = 2.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        for (int i = 0; i < 4; i++) {
          final a = pTime * 1.5 + i * pi / 2;
          canvas.drawLine(
              Offset(cos(a) * radius * 0.2, sin(a) * radius * 0.2),
              Offset(cos(a) * radius * 0.88, sin(a) * radius * 0.88),
              Paint()..color = color.withValues(alpha: 0.6)..strokeWidth = 1.5);
        }
        canvas.drawCircle(Offset.zero, radius * 0.2,
            Paint()..color = color.withValues(alpha: 0.5));

      case 'guardian_shield':
        final gPulse = 0.85 + sin(pTime * 4) * 0.12;
        canvas.drawCircle(Offset.zero, radius * 0.28 * gPulse,
            Paint()..color = color.withValues(alpha: 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: radius * 0.58),
            pTime * -2.5, pi, false,
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: radius),
            pTime * 1.8, pi, false,
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      default:
        canvas.drawCircle(Offset.zero, radius,
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }

    if (skinId == 'violet_gravity') {
      final gP = (pTime * 0.8) % 1.0;
      canvas.drawCircle(Offset.zero, radius * (1.6 + gP * 1.2),
          Paint()
            ..color = color.withValues(alpha: (1.0 - gP) * 0.3)
            ..style = PaintingStyle.stroke..strokeWidth = 1.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  @override
  bool shouldRepaint(SkinPreviewPainter old) =>
      old.color != color || old.glowT != glowT || old.skinId != skinId;
}
