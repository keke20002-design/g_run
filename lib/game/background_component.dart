import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';

class _Star {
  double x, y;
  final double radius;
  final double baseAlpha;
  final double speedMult;
  final bool isSurge;

  _Star(this.x, this.y, this.radius, this.baseAlpha, this.speedMult,
      {this.isSurge = false});
}

class _WarpStar {
  final double angle;
  double dist;
  final double speed;
  final double brightness;

  _WarpStar({
    required this.angle,
    required this.dist,
    required this.speed,
    required this.brightness,
  });
}

class _EnergyStreak {
  double x, y;
  final double length;
  final double baseAlpha;
  final double speedFrac;

  _EnergyStreak(this.x, this.y, this.length, this.baseAlpha, this.speedFrac);
}

class BackgroundComponent extends Component
    with HasGameReference<GravityFlipGame> {
  final List<_Star>         _stars         = [];
  final List<_WarpStar>     _warpStars     = [];
  final List<_EnergyStreak> _energyStreaks  = [];
  final Random _rng = Random();

  double _ringAngle  = 0;
  double _surgeTimer = 0;

  // Score-driven intensities (0.0~1.0, smooth easeIn curves)
  double _energyIntensity     = 0;
  double _distortionIntensity = 0;
  double _surgeIntensity      = 0;
  double _insaneIntensity     = 0;
  int    _currentScore        = 0;

  BackgroundComponent() : super(priority: -10);

  @override
  Future<void> onLoad() async {
    _generateStars();
    _generateWarpStars();
    _generateEnergyStreaks();
  }

  void _generateStars() {
    _stars.clear();
    final rng = Random(7);
    final w = game.size.x;
    final h = game.size.y;

    // Layer 1 – small, very slow
    for (int i = 0; i < 10; i++) {
      _stars.add(_Star(
        rng.nextDouble() * w, rng.nextDouble() * h,
        0.7 + rng.nextDouble() * 0.4,
        0.20 + rng.nextDouble() * 0.18,
        0.018,
      ));
    }
    // Layer 2 – medium
    for (int i = 0; i < 6; i++) {
      _stars.add(_Star(
        rng.nextDouble() * w, rng.nextDouble() * h,
        1.2 + rng.nextDouble() * 0.4,
        0.32 + rng.nextDouble() * 0.18,
        0.10,
      ));
    }
    // Layer 3 – large
    for (int i = 0; i < 4; i++) {
      _stars.add(_Star(
        rng.nextDouble() * w, rng.nextDouble() * h,
        1.8 + rng.nextDouble() * 0.7,
        0.42 + rng.nextDouble() * 0.18,
        0.20,
      ));
    }
    // Layer 4 – closest, large bright particles, fastest
    for (int i = 0; i < 3; i++) {
      _stars.add(_Star(
        rng.nextDouble() * w, rng.nextDouble() * h,
        2.5 + rng.nextDouble() * 1.0,
        0.60 + rng.nextDouble() * 0.25,
        0.35,
      ));
    }
    // Surge stars – extra density at 5000+ (only rendered when surgeIntensity > 0)
    for (int i = 0; i < 12; i++) {
      _stars.add(_Star(
        rng.nextDouble() * w, rng.nextDouble() * h,
        0.9 + rng.nextDouble() * 0.8,
        0.45 + rng.nextDouble() * 0.30,
        0.15,
        isSurge: true,
      ));
    }
  }

  void _generateWarpStars() {
    _warpStars.clear();
    final rng = Random(17);
    for (int i = 0; i < 22; i++) {
      _warpStars.add(_WarpStar(
        angle:      rng.nextDouble() * 2 * pi,
        dist:       rng.nextDouble() * 180,
        speed:      0.6 + rng.nextDouble() * 0.9,
        brightness: 0.35 + rng.nextDouble() * 0.35,
      ));
    }
  }

  void _generateEnergyStreaks() {
    _energyStreaks.clear();
    final rng = Random(31);
    final sw = game.size.x > 0 ? game.size.x : 400.0;
    final sh = game.size.y > 0 ? game.size.y : 600.0;
    for (int i = 0; i < 8; i++) {
      _energyStreaks.add(_EnergyStreak(
        rng.nextDouble() * sw,
        30 + rng.nextDouble() * (sh - 60),
        40 + rng.nextDouble() * 60,        // 40~100 px length
        0.08 + rng.nextDouble() * 0.10,    // 0.08~0.18 max alpha
        0.8  + rng.nextDouble() * 0.4,     // speed fraction
      ));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _generateStars();
    _generateWarpStars();
    _generateEnergyStreaks();
  }

  double _screenDiag(double w, double h) => sqrt(w * w + h * h) / 2 + 30;

  // easeIn (x²) for smooth intensity ramp-up
  double _ease(double t) => t * t;

  void _updateIntensities(int score) {
    _currentScore        = score;
    _energyIntensity     = _ease(((score - 800)  / 1200.0).clamp(0.0, 1.0));
    _distortionIntensity = _ease(((score - 2500) / 2000.0).clamp(0.0, 1.0));
    _surgeIntensity      = _ease(((score - 5000) / 2000.0).clamp(0.0, 1.0));
    _insaneIntensity     = _ease(((score - 8000) / 1500.0).clamp(0.0, 1.0));
  }

  // ── Background color: deep blue → blue → purple → magenta → red ──────────
  static Color _bgColor(int score) {
    const c0 = Color(0xFF071B34);
    const c1 = Color(0xFF0A254A);
    const c2 = Color(0xFF1A0F3D);
    const c3 = Color(0xFF2B0B35);
    const c4 = Color(0xFF3A0A1A);
    if (score < 1000) return c0;
    if (score < 2000) return Color.lerp(c0, c1, (score - 1000) / 1000.0)!;
    if (score < 4000) return Color.lerp(c1, c2, (score - 2000) / 2000.0)!;
    if (score < 7000) return Color.lerp(c2, c3, (score - 4000) / 3000.0)!;
    return Color.lerp(c3, c4, ((score - 7000) / 2000.0).clamp(0.0, 1.0))!;
  }

  // ── Star speed multiplier: slow at start, fast at 8000+ ──────────────────
  static double _starSpeedMult(int score) {
    if (score < 2000) return 1.0;
    if (score < 5000) return 1.0 + ((score - 2000) / 3000.0) * 1.5;
    if (score < 8000) return 2.5 + ((score - 5000) / 3000.0) * 1.5;
    return 4.0;
  }

  @override
  void update(double dt) {
    _ringAngle  += dt * 0.08;
    _surgeTimer += dt;

    final gameSpeed = game.state == GameState.playing
        ? game.difficultyManager.speed
        : 40.0;

    final w = game.size.x;
    final h = game.size.y;

    final score = game.state == GameState.playing
        ? game.scoreSystem.score
        : 0;
    final boostMult = _starSpeedMult(score) * (1.0 + game.milestoneBoostIntensity * 4.0);

    _updateIntensities(score);

    // Parallax star drift (left)
    for (final s in _stars) {
      s.x -= gameSpeed * s.speedMult * boostMult * dt;
      if (s.x < -4) s.x += w + 8;
    }

    // Energy streaks scroll left (1.2x speed per spec)
    if (_energyIntensity > 0) {
      for (final e in _energyStreaks) {
        e.x -= gameSpeed * e.speedFrac * 1.2 * boostMult * dt;
        if (e.x + e.length < 0) e.x += w + e.length + 20;
      }
    }

    // Warp stars move radially outward
    final warpThreshold = (260.0 - (score / 40.0).clamp(0.0, 120.0));
    if (game.state == GameState.playing && gameSpeed > warpThreshold) {
      final maxD = _screenDiag(w, h);
      for (final ws in _warpStars) {
        ws.dist += gameSpeed * ws.speed * 0.28 * boostMult * dt;
        if (ws.dist > maxD) {
          ws.dist = 8 + _rng.nextDouble() * 25;
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final cx = w / 2;
    final cy = h / 2;

    // ── Base gradient (score-driven color) ───────────────────────
    final bgBase = _bgColor(_currentScore);
    final bgDark = Color.lerp(bgBase, Colors.black, 0.55)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgBase, bgDark],
        ).createShader(rect),
    );

    // ── Central radial glow ───────────────────────────────────────
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [bgBase.withValues(alpha: 0.6), Colors.black.withValues(alpha: 0.4)],
        ).createShader(rect),
    );

    // ── Rotating background rings ─────────────────────────────────
    final ringR = h * 0.36;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(_ringAngle);
    canvas.drawCircle(
      Offset.zero, ringR,
      Paint()
        ..color       = const Color(0xFF00E5FF).withValues(alpha: 0.05)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset.zero, ringR * 0.68,
      Paint()
        ..color       = const Color(0xFF00E5FF).withValues(alpha: 0.03)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();

    // ── Warp star streaks ─────────────────────────────────────────
    if (game.state == GameState.playing) {
      final gameSpeed = game.difficultyManager.speed;
      if (gameSpeed > 260) {
        final t = ((gameSpeed - 260) / 200.0).clamp(0.0, 1.0);
        final boostI = game.milestoneBoostIntensity;
        for (final ws in _warpStars) {
          final trailLen = (t * 60.0 + boostI * 120.0) * ws.speed;
          final hx = cx + cos(ws.angle) * ws.dist;
          final hy = cy + sin(ws.angle) * ws.dist;
          final td = (ws.dist - trailLen).clamp(0.0, ws.dist);
          final tx = cx + cos(ws.angle) * td;
          final ty = cy + sin(ws.angle) * td;
          canvas.drawLine(
            Offset(tx, ty),
            Offset(hx, hy),
            Paint()
              ..color       = Colors.white.withValues(alpha: ws.brightness * t * 0.32)
              ..strokeWidth = 0.85,
          );
        }
      }
    }

    // ── Stars ─────────────────────────────────────────────────────
    for (final s in _stars) {
      if (s.isSurge && _surgeIntensity <= 0) continue;
      final alphaMult = s.isSurge ? _surgeIntensity : 1.0;
      canvas.drawCircle(
        Offset(s.x, s.y),
        s.radius,
        Paint()..color = Colors.white.withValues(alpha: s.baseAlpha * alphaMult),
      );
    }

    // ── Energy Layer: thin cyan streaks (score 800~2000) ──────────
    if (_energyIntensity > 0) {
      final streakPaint = Paint()
        ..strokeWidth = 1.0
        ..strokeCap   = StrokeCap.round;
      for (final e in _energyStreaks) {
        streakPaint.color = const Color(0xFF00E5FF)
            .withValues(alpha: e.baseAlpha * _energyIntensity);
        canvas.drawLine(
          Offset(e.x, e.y),
          Offset(e.x + e.length, e.y),
          streakPaint,
        );
      }
    }

    // ── Distortion Layer: vignette + purple tint (score 2500~4500) ─
    if (_distortionIntensity > 0) {
      // Vignette (dark edges)
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.85,
            colors: [
              Colors.transparent,
              const Color(0xFF050810)
                  .withValues(alpha: 0.55 * _distortionIntensity),
            ],
          ).createShader(rect),
      );
      // Subtle purple center tint
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.6,
            colors: [
              const Color(0xFF4B0082)
                  .withValues(alpha: 0.08 * _distortionIntensity),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }

    // ── Insane Layer: edge energy ring (score 8000+) ─────────────
    if (_insaneIntensity > 0) {
      const edgeColor = Color(0xFFFF2E88);
      final pulse     = sin(_surgeTimer * 4.5) * 0.5 + 0.5;
      final edgeAlpha = (0.18 + pulse * 0.14) * _insaneIntensity;
      final edgePaint = Paint()
        ..color      = edgeColor.withValues(alpha: edgeAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRect(Rect.fromLTWH(0, 0,      w, 10), edgePaint); // top
      canvas.drawRect(Rect.fromLTWH(0, h - 10, w, 10), edgePaint); // bottom
      canvas.drawRect(Rect.fromLTWH(0, 0,      6, h),  edgePaint); // left
      canvas.drawRect(Rect.fromLTWH(w - 6, 0,  6, h),  edgePaint); // right
      // Subtle full-screen pink vignette
      canvas.drawRect(
        rect,
        Paint()..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.4,
          colors: [
            Colors.transparent,
            edgeColor.withValues(alpha: 0.10 * _insaneIntensity * pulse),
          ],
        ).createShader(rect),
      );
    }

    // ── Surge Layer: pulsing cyan radial glow (score 5000+) ───────
    if (_surgeIntensity > 0) {
      final pulse      = sin(_surgeTimer * 2.2) * 0.5 + 0.5; // 0~1
      final pulseAlpha = (0.07 + pulse * 0.06) * _surgeIntensity;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              const Color(0xFF00E5FF).withValues(alpha: pulseAlpha),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
      // Soft edge glow
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Colors.transparent,
              const Color(0xFF00E5FF)
                  .withValues(alpha: 0.04 * _surgeIntensity),
            ],
          ).createShader(rect),
      );
    }
  }
}
