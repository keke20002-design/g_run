import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../game/player.dart' show NearMissGrade;

class HUD extends StatefulWidget {
  final int score;
  final int bestScore;
  final double multiplier;
  final int combo;
  final NearMissGrade? nearMissGrade;
  final bool isPaused;
  final int gpPoints;
  final VoidCallback? onExit;
  final VoidCallback? onPause;

  const HUD({
    super.key,
    required this.score,
    required this.bestScore,
    required this.multiplier,
    required this.combo,
    required this.gpPoints,
    this.nearMissGrade,
    this.isPaused = false,
    this.onExit,
    this.onPause,
  });

  @override
  State<HUD> createState() => _HUDState();
}

class _HUDState extends State<HUD> with TickerProviderStateMixin {
  late final AnimationController _particleCtrl;
  late final AnimationController _lightningCtrl;
  late final AnimationController _rainbowCtrl;
  late final AnimationController _nearMissScoreCtrl;

  static const _accent = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _lightningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _rainbowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _nearMissScoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(HUD old) {
    super.didUpdateWidget(old);
    // Near miss → 파티클 + 점수 펄스
    if (widget.nearMissGrade != null && old.nearMissGrade == null) {
      _particleCtrl.forward(from: 0);
      _nearMissScoreCtrl.forward(from: 0);
    }
    // 1000점 마다 → 별 파티클
    if (widget.score ~/ 1000 > old.score ~/ 1000) {
      _particleCtrl.forward(from: 0);
    }
    // 15000+ → 번개 (2000점마다)
    if (widget.score >= 15000 &&
        widget.score ~/ 2000 > old.score ~/ 2000) {
      _lightningCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _lightningCtrl.dispose();
    _rainbowCtrl.dispose();
    _nearMissScoreCtrl.dispose();
    super.dispose();
  }

  // ── 1-2) 점수 색상 단계 ───────────────────────────────────────────────────
  Color _scoreColor(int s) {
    if (s < 1000) {
      return Color.lerp(Colors.white, const Color(0xFFCCF5FF), s / 1000)!;
    }
    if (s < 3000) {
      return Color.lerp(
        const Color(0xFF33E6FF),
        const Color(0xFFA855F7),
        (s - 1000) / 2000,
      )!;
    }
    if (s < 7000) {
      return Color.lerp(
        const Color(0xFFA855F7),
        const Color(0xFFFFD700),
        (s - 3000) / 4000,
      )!;
    }
    if (s < 15000) return const Color(0xFFFFD700);
    // 15000+ 무지개
    return HSVColor.fromAHSV(1.0, (_rainbowCtrl.value * 360) % 360, 1.0, 1.0)
        .toColor();
  }

  double _scoreGlow(int s) {
    if (s < 1000)  return 8;
    if (s < 3000)  return 14;
    if (s < 7000)  return 22;
    if (s < 15000) return 28;
    return 38;
  }

  // ── Near Miss 등급별 스타일 헬퍼 ──────────────────────────────────────────────
  String _nearMissLabel(NearMissGrade grade) {
    switch (grade) {
      case NearMissGrade.insane:    return '⚡ PERFECT ⚡';
      case NearMissGrade.superMiss: return 'GREAT';
      case NearMissGrade.near:      return 'GOOD';
      case NearMissGrade.close:     return 'NICE';
    }
  }

  String _nearMissBonus(NearMissGrade grade) {
    switch (grade) {
      case NearMissGrade.insane:    return '+100 BONUS';
      case NearMissGrade.superMiss: return '+75 BONUS';
      case NearMissGrade.near:      return '+50 BONUS';
      case NearMissGrade.close:     return '+25 BONUS';
    }
  }

  Color _nearMissColor(NearMissGrade grade) {
    switch (grade) {
      case NearMissGrade.insane:    return const Color(0xFFFFD700);
      case NearMissGrade.superMiss: return const Color(0xFF00E5FF);
      case NearMissGrade.near:      return const Color(0xFF00FFA3);
      case NearMissGrade.close:     return const Color(0xFFFF6EFF);
    }
  }

  double _nearMissFontSize(NearMissGrade grade) {
    switch (grade) {
      case NearMissGrade.insane:    return 38;
      case NearMissGrade.superMiss: return 32;
      case NearMissGrade.near:      return 30;
      case NearMissGrade.close:     return 24;
    }
  }

  List<Shadow> _nearMissShadows(NearMissGrade grade) {
    final c = _nearMissColor(grade);
    switch (grade) {
      case NearMissGrade.insane:
        return [
          Shadow(blurRadius: 20, color: c),
          Shadow(blurRadius: 45, color: c),
          const Shadow(blurRadius: 70, color: Color(0xFFFFAA00)),
        ];
      case NearMissGrade.superMiss:
        return [
          Shadow(blurRadius: 16, color: c),
          Shadow(blurRadius: 36, color: c),
        ];
      case NearMissGrade.near:
        return [
          Shadow(blurRadius: 14, color: c),
          Shadow(blurRadius: 30, color: c),
        ];
      case NearMissGrade.close:
        return [Shadow(blurRadius: 8, color: c)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final top        = MediaQuery.of(context).padding.top + 20;
    final scoreColor = _scoreColor(widget.score);
    final glow       = _scoreGlow(widget.score);

    return Stack(
      children: [

        // ── 점수 블록 (상단 중앙) ─────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: top, bottom: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // BEST
                Text(
                  'BEST  ${widget.bestScore}',
                  style: TextStyle(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.60),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 1),

                // 점수 + 파티클 + 번개 레이어
                SizedBox(
                  width: 220,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [

                      // 2-2) 별 파티클 ──────────────────────────
                      AnimatedBuilder(
                        animation: _particleCtrl,
                        builder: (_, __) => CustomPaint(
                          size: const Size(220, 90),
                          painter: _StarParticlePainter(
                            t: _particleCtrl.value,
                            color: scoreColor,
                          ),
                        ),
                      ),

                      // 3-1) 번개 (15000+) ─────────────────────
                      if (widget.score >= 15000)
                        AnimatedBuilder(
                          animation: _lightningCtrl,
                          builder: (_, __) => CustomPaint(
                            size: const Size(220, 90),
                            painter: _LightningPainter(
                              t: _lightningCtrl.value,
                              color: scoreColor,
                            ),
                          ),
                        ),

                      // 1-1) 점수 숫자 (bounce + shimmer) ──────
                      AnimatedBuilder(
                        animation: Listenable.merge([_rainbowCtrl, _nearMissScoreCtrl]),
                        builder: (_, __) {
                          final c = _scoreColor(widget.score);
                          final nmPulse = 1.0 + 0.20 * sin(_nearMissScoreCtrl.value * pi);
                          return Transform.scale(
                            scale: nmPulse,
                            child: Text(
                            '${widget.score}',
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1,
                              color: c,
                              shadows: [
                                Shadow(
                                  color: c.withValues(alpha: 0.80),
                                  blurRadius: glow,
                                ),
                                Shadow(
                                  color: c.withValues(alpha: 0.40),
                                  blurRadius: glow * 2,
                                ),
                              ],
                            ),
                          )
                          // 1-1) 1000점마다 팝 (1.0 → 1.6 → 1.0)
                          .animate(key: ValueKey(widget.score ~/ 1000))
                          .scaleXY(
                            begin: 1.2, end: 1.0,
                            duration: 280.ms,
                            curve: Curves.elasticOut,
                          )
                          // 소펄스 (8점마다)
                          .animate(key: ValueKey(widget.score ~/ 8))
                          .scaleXY(
                            begin: 1.2, end: 1.0,
                            duration: 80.ms,
                            curve: Curves.easeOut,
                          )
                          // shimmer (100점마다)
                          .animate(key: ValueKey(widget.score ~/ 100))
                          .shimmer(
                            delay: 0.ms,
                            duration: 400.ms,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          );  // Transform.scale 닫기
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 종료 버튼 (왼쪽 상단) ────────────────────────────────
        Positioned(
          top: top - 8, left: 12,
          child: GestureDetector(
            onTap: widget.onExit,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: _accent.withValues(alpha: 0.55),
                size: 18,
              ),
            ),
          ),
        ),

        // ── GP + 일시정지 (오른쪽 상단) ──────────────────────────
        Positioned(
          top: top - 8, right: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GP 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 11, height: 11,
                      child: CustomPaint(
                        painter: _GPRingPainter(),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.gpPoints} GP',
                      style: const TextStyle(
                        color: Color(0xFF9D5BFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 일시정지 버튼
              GestureDetector(
                onTap: widget.onPause,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.20),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    widget.isPaused ? Icons.play_arrow : Icons.pause,
                    color: _accent.withValues(alpha: 0.70),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 배율 ─────────────────────────────────────────────────
        if (widget.multiplier > 1.0)
          Positioned(
            top: top + 42, right: 20,
            child: Text(
              '×${widget.multiplier.toStringAsFixed(1)}',
              style: TextStyle(
                color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(blurRadius: 6, color: Color(0xFFFFD700)),
                ],
              ),
            ),
          ),

        // ── 콤보 ─────────────────────────────────────────────────
        if (widget.combo > 1)
          Positioned(
            top: top + 72, right: 20,
            child: Text(
              '${widget.combo} COMBO',
              style: TextStyle(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.85),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),

        // ── 2-1) Near Miss 팝업 텍스트 (흔들림 + 등장/퇴장) ─────
        if (widget.nearMissGrade != null)
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) {
              final t     = _particleCtrl.value;
              // 입장: 0~25% 구간에서 0.3→1.0 탄성 스케일
              final scaleT = (t / 0.25).clamp(0.0, 1.0);
              final scale  = 0.3 + 0.7 * Curves.elasticOut.transform(scaleT);
              // 흔들림: 감쇠 사인파
              final shake  = sin(t * pi * 10) * 9.0 * (1.0 - t);
              // 투명도: 65% 지점까지 불투명, 이후 서서히 퇴장
              final opacity = t < 0.65
                  ? 1.0
                  : ((1.0 - t) / 0.35).clamp(0.0, 1.0);
              final grade  = widget.nearMissGrade!;
              return Positioned(
                top: top + 112, left: 0, right: 0,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(shake, 0),
                      child: Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _nearMissLabel(grade),
                              style: TextStyle(
                                color: _nearMissColor(grade),
                                fontSize: _nearMissFontSize(grade),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                shadows: _nearMissShadows(grade),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _nearMissBonus(grade),
                              style: TextStyle(
                                color: _nearMissColor(grade).withValues(alpha: 0.85),
                                fontSize: _nearMissFontSize(grade) * 0.52,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: _nearMissColor(grade).withValues(alpha: 0.70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // ── 2-1) Near Miss 화면 번쩍 오버레이 ────────────────────
        if (widget.nearMissGrade != null)
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) {
              final t       = _particleCtrl.value;
              final opacity = t < 0.15
                  ? t / 0.15
                  : t < 0.30
                      ? 1.0
                      : ((0.50 - t) / 0.20).clamp(0.0, 1.0);
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: _nearMissColor(widget.nearMissGrade!)
                        .withValues(alpha: opacity * 0.14),
                  ),
                ),
              );
            },
          ),


        // ── 일시정지 오버레이 ─────────────────────────────────────
        if (widget.isPaused)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onPause,
              child: Container(
                color: Colors.black.withValues(alpha: 0.70),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PAUSED',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          shadows: [
                            Shadow(
                              color: _accent.withValues(alpha: 0.70),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      GestureDetector(
                        onTap: widget.onPause,
                        child: Container(
                          width: 160, height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _accent, width: 1.5),
                            color: _accent.withValues(alpha: 0.08),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.25),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'RESUME',
                              style: TextStyle(
                                color: _accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 2-2) 별 파티클 페인터 ─────────────────────────────────────────────────────

class _ParticleSeed {
  final double angle;
  final double speed;
  final double startT;
  final double size;
  const _ParticleSeed({
    required this.angle,
    required this.speed,
    required this.startT,
    required this.size,
  });
}

class _StarParticlePainter extends CustomPainter {
  final double t;
  final Color color;

  static const int _count = 22;
  static final List<_ParticleSeed> _seeds = List.generate(_count, (i) {
    final rng = Random(i * 37 + 7);
    return _ParticleSeed(
      angle:  rng.nextDouble() * 2 * pi,
      speed:  90.0 + rng.nextDouble() * 160.0,
      startT: rng.nextDouble() * 0.30,
      size:   2.5 + rng.nextDouble() * 4.0,
    );
  });

  const _StarParticlePainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final cx = size.width  / 2;
    final cy = size.height / 2;

    for (final s in _seeds) {
      if (t < s.startT) continue;
      final lt    = ((t - s.startT) / (1.0 - s.startT)).clamp(0.0, 1.0);
      final dist  = s.speed * lt;
      final alpha = (1.0 - lt).clamp(0.0, 1.0);
      final r     = s.size * (1.0 - lt * 0.6);

      canvas.drawCircle(
        Offset(cx + cos(s.angle) * dist, cy + sin(s.angle) * dist),
        r,
        Paint()
          ..color      = color.withValues(alpha: alpha * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_StarParticlePainter old) =>
      old.t != t || old.color != color;
}

// ── 3-1) 번개 페인터 ──────────────────────────────────────────────────────────

class _LightningPainter extends CustomPainter {
  final double t;
  final Color color;

  // 고정 경로 (앱 수명 동안 한 번만 생성)
  static final List<Offset> _bolt = _buildBolt();

  static List<Offset> _buildBolt() {
    final rng = Random(77);
    final pts = <Offset>[];
    double x = -10;
    pts.add(Offset(x, 45));
    while (x < 230) {
      x += 10 + rng.nextDouble() * 14;
      pts.add(Offset(x, 28 + rng.nextDouble() * 34));
    }
    return pts;
  }

  const _LightningPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final alpha = sin(t * pi).clamp(0.0, 1.0);
    if (alpha < 0.01) return;

    // 왼쪽 → 오른쪽으로 스윕
    final sweepX = t * (size.width + 40) - 10;

    final path = Path();
    bool started = false;
    for (final pt in _bolt) {
      if (pt.dx > sweepX) break;
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    if (!started) return;

    // 외부 글로우
    canvas.drawPath(
      path,
      Paint()
        ..color       = Colors.white.withValues(alpha: alpha * 0.28)
        ..strokeWidth = 6.0
        ..style       = PaintingStyle.stroke
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // 메인 선
    canvas.drawPath(
      path,
      Paint()
        ..color       = color.withValues(alpha: alpha * 0.90)
        ..strokeWidth = 1.8
        ..style       = PaintingStyle.stroke
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 1),
    );
  }

  @override
  bool shouldRepaint(_LightningPainter old) =>
      old.t != t || old.color != color;
}

// ── GP 링 아이콘 페인터 ────────────────────────────────────────────────────────

class _GPRingPainter extends CustomPainter {
  static const _color = Color(0xFF9D5BFF);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 0.5;

    canvas.drawCircle(
      c, r,
      Paint()
        ..color       = _color.withValues(alpha: 0.85)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      c, 2.0,
      Paint()..color = _color,
    );
  }

  @override
  bool shouldRepaint(_GPRingPainter old) => false;
}
