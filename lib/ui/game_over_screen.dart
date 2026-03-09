import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int bestScore;
  final bool isNewBest;
  final int gpEarned;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.gpEarned,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  late AnimationController _glitchCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _glitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _glitchCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = (widget.score * 0.08).toStringAsFixed(0);

    return FadeTransition(
      opacity: _fadeIn,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark background ─────────────────────────────────────────
          Container(color: const Color(0xD2070B14)),

          // ── Glitch overlay ──────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glitchCtrl,
              builder: (context, _) => CustomPaint(
                painter: _GlitchPainter(_glitchCtrl.value),
              ),
            ),
          ),

          // ── Main content (title + score/stats) ──────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // GAME OVER title
                Text(
                  'GAME OVER',
                  style: const TextStyle(
                    color: Color(0xFFE040FB),
                    fontSize: 44,
                    fontWeight: FontWeight.w100,
                    letterSpacing: 16,
                    shadows: [
                      Shadow(color: Color(0xFFE040FB), blurRadius: 28),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .shimmer(
                      duration: 900.ms,
                      delay: 200.ms,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),

                const SizedBox(height: 20),

                // Left: Score  |  Right: Stats
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Score (left half) ──────────────────────────────
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: widget.score),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOut,
                            builder: (context, value, _) => Text(
                              '$value',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 74,
                                fontWeight: FontWeight.w200,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF00E5FF),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.isNewBest)
                            Text(
                              '★  NEW BEST  ★',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 15,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFD700),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .shimmer(
                                  duration: 1200.ms,
                                  color: Colors.white.withValues(alpha: 0.55),
                                )
                          else
                            Text(
                              'BEST  ${widget.bestScore}',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                                letterSpacing: 3,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Stats (right half) ─────────────────────────────
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow(label: 'DISTANCE', value: '$distance m'),
                          const SizedBox(height: 10),
                          _StatRow(
                            label: 'BEST',
                            value: '${widget.bestScore}',
                          ),
                          const SizedBox(height: 10),
                          _StatRow(
                            label: 'GP EARNED',
                            value: '+${widget.gpEarned} GP',
                            valueColor: const Color(0xFF9D5BFF),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Buttons fixed at bottom ─────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NeonOutlineButton(
                  text: 'RETRY',
                  onTap: widget.onRestart,
                ),
                const SizedBox(width: 24),
                _MenuButton(onTap: widget.onMenu),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat row ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final vColor = valueColor ?? const Color(0xFF94A3B8);
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 11,
              letterSpacing: 2.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: vColor,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
              shadows: valueColor != null
                  ? [Shadow(color: vColor.withValues(alpha: 0.55), blurRadius: 8)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Neon outline button ───────────────────────────────────────────────────────

class _NeonOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _NeonOutlineButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 248,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.80),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.03,
            duration: 1500.ms,
            curve: Curves.easeInOut,
          )
          .boxShadow(
            begin: BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
              blurRadius: 10,
            ),
            end: BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.60),
              blurRadius: 26,
            ),
            duration: 1500.ms,
          ),
    );
  }
}

// ── Menu button (smaller, static outline) ────────────────────────────────────

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Text(
            'MAIN MENU',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glitch CustomPainter ──────────────────────────────────────────────────────

class _GlitchPainter extends CustomPainter {
  final double time;

  _GlitchPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    // Scan lines — subtle horizontal bands
    final scanPaint = Paint()..color = Colors.black.withValues(alpha: 0.09);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // Glitch strips — seeded by quantized time so they flicker
    final seed = (time * 9).floor() * 37 + (time * 3).floor() * 13;
    final rng = Random(seed);

    if (rng.nextDouble() > 0.62) {
      final numStrips = 1 + rng.nextInt(3);
      for (int i = 0; i < numStrips; i++) {
        final y = rng.nextDouble() * size.height;
        final h = 1.5 + rng.nextDouble() * 7.0;
        final shift = (rng.nextDouble() - 0.5) * 28.0;

        // Cyan channel shift
        canvas.drawRect(
          Rect.fromLTWH(shift, y, size.width, h),
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.13),
        );
        // Magenta counter-shift
        canvas.drawRect(
          Rect.fromLTWH(-shift * 0.5, y + h * 0.45, size.width, h * 0.55),
          Paint()
            ..color = const Color(0xFFE040FB).withValues(alpha: 0.09),
        );
      }
    }

    // Occasional full-width bright flash strip
    final flashSeed = (time * 4).floor() * 61;
    final flashRng = Random(flashSeed);
    if (flashRng.nextDouble() > 0.88) {
      final fy = flashRng.nextDouble() * size.height;
      canvas.drawRect(
        Rect.fromLTWH(0, fy, size.width, 1.0),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => old.time != time;
}
