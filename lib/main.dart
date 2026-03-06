import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'game/gravity_flip_game.dart';
import 'game/player.dart' show NearMissGrade;
import 'ui/game_over_screen.dart';
import 'ui/hud.dart';
import 'ui/skin_shop_screen.dart';
import 'ui/skin_preview_painter.dart';
import 'systems/skin_manager.dart';
import 'systems/audio_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SkinManager.instance.load();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GravityFlipApp());
}

class GravityFlipApp extends StatelessWidget {
  const GravityFlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GravityFlipGame _game;
  bool _isDead      = false;
  bool _isStarted   = false;
  NearMissGrade? _nearMissGrade;
  bool _isPaused    = false;
  int  _gpBefore    = 0;
  int  _gpEarned    = 0;

  int    _score      = 0;
  double _multiplier = 1.0;
  int    _combo      = 0;

  @override
  void initState() {
    super.initState();
    _game = GravityFlipGame();
    _game.onDeath            = _onDeath;
    _game.onNearMissCallback = _onNearMiss;
  }

  void _onDeath() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gpEarned = SkinManager.instance.gravityPoints - _gpBefore;
      setState(() => _isDead = true);
    });
  }

  void _onNearMiss(NearMissGrade grade) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _nearMissGrade = grade);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _nearMissGrade = null);
      });
    });
  }

  void _exitToMain() {
    if (_isPaused) {
      _game.paused = false;
      _isPaused = false;
    }
    _game.returnToMenu();
    setState(() {
      _isStarted = false;
      _isDead    = false;
    });
  }

  void _togglePause() {
    if (_game.state != GameState.playing) return;
    setState(() {
      _isPaused   = !_isPaused;
      _game.paused = _isPaused;
    });
  }

  void _start() {
    if (_isPaused) {
      _game.paused = false;
      _isPaused = false;
    }
    _gpBefore = SkinManager.instance.gravityPoints;
    setState(() {
      _isDead       = false;
      _isStarted    = true;
      _score        = 0;
      _multiplier   = 1.0;
      _combo        = 0;
      _gpEarned     = 0;
      _nearMissGrade = null;
    });
    _game.startGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: _game),

          if (!_isStarted)
            _StartScreen(
              onStart: _start,
              bestScore: _game.scoreSystem.bestScore,
            ),

          if (_isStarted && !_isDead)
            StreamBuilder<void>(
              stream: Stream.periodic(const Duration(milliseconds: 50)),
              builder: (context, _) {
                if (_game.state == GameState.playing) {
                  _score      = _game.scoreSystem.score;
                  _multiplier = _game.scoreSystem.multiplier;
                  _combo      = _game.scoreSystem.combo;
                }
                return HUD(
                  score: _score,
                  bestScore: _game.scoreSystem.bestScore,
                  multiplier: _multiplier,
                  combo: _combo,
                  nearMissGrade: _nearMissGrade,
                  isPaused: _isPaused,
                  gpPoints: SkinManager.instance.gravityPoints +
                      _game.scoreSystem.liveGPEarned(
                        _game.difficultyManager.difficultyMultiplier,
                      ),
                  onExit: _exitToMain,
                  onPause: _togglePause,
                );
              },
            ),

          if (_isDead)
            GameOverScreen(
              score: _game.scoreSystem.score,
              bestScore: _game.scoreSystem.bestScore,
              isNewBest: _game.scoreSystem.isNewBest,
              gpEarned: _gpEarned,
              onRestart: _start,
              onMenu: _exitToMain,
            ),

          // ── Vignette (always visible) ──────────────────────────
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.88,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start Screen ──────────────────────────────────────────────────────────────

class _StartScreen extends StatefulWidget {
  final VoidCallback onStart;
  final int bestScore;

  const _StartScreen({required this.onStart, required this.bestScore});

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoRingCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _wheelCtrl;
  late final AnimationController _demoYCtrl;

  bool _demoFlipped = false;

  static const Color _accent = Color(0xFF00E5FF);
  static const Color _purple = Color(0xFF7C4DFF);
  static const Color _green  = Color(0xFF00FFA3);

  @override
  void initState() {
    super.initState();

    // Logo ring: one full rotation every 45 s (~8°/s)
    _logoRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();

    // Glow pulse: 0.6 → 0.9 → 0.6 every 2 s
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Demo wheel repaint ticker (60 fps)
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Demo wheel vertical flip animation
    _demoYCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _scheduleFlip();
  }

  void _scheduleFlip() {
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() => _demoFlipped = !_demoFlipped);
        _demoFlipped
            ? _demoYCtrl.forward(from: 0)
            : _demoYCtrl.reverse(from: 1);
        _scheduleFlip();
      }
    });
  }

  @override
  void dispose() {
    _logoRingCtrl.dispose();
    _glowCtrl.dispose();
    _wheelCtrl.dispose();
    _demoYCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: gravity particles (behind everything)
        const _GravityParticles(),

        // Layer 2: content
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 24),
              _buildDemoWheel(),
              const SizedBox(height: 32),
              _buildPlayButton(),
              const SizedBox(height: 14),
              _buildSkinShopButton(),
              const SizedBox(height: 16),
              _buildBestScore(),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoRingCtrl, _glowCtrl]),
      builder: (context, _) {
        final ringAngle = _logoRingCtrl.value * 2 * pi;
        final glowAlpha = 0.6 + _glowCtrl.value * 0.3; // 0.6~0.9

        return SizedBox(
          width: 220,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing halo behind logo
              Container(
                width: 160,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: glowAlpha * 0.18),
                      blurRadius: 40,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
              // Rotating ring
              CustomPaint(
                size: const Size(220, 110),
                painter: _LogoRingPainter(
                  angle: ringAngle,
                  glowAlpha: glowAlpha,
                ),
              ),
              // Logo image: floating up/down
              Image.asset('assets/images/logo.png', width: 190)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: -6,
                    end: 6,
                    duration: 2000.ms,
                    curve: Curves.easeInOutSine,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDemoWheel() {
    const trackH    = 96.0;
    const wheelSize = 44.0;
    const rollSpeed = 80.0; // px/s

    return SizedBox(
      width: double.infinity,
      height: trackH,
      child: LayoutBuilder(builder: (ctx, constraints) {
        final trackW = constraints.maxWidth;
        return AnimatedBuilder(
          animation: Listenable.merge([_wheelCtrl, _demoYCtrl]),
          builder: (ctx, _) {
            final skin  = SkinManager.instance.equippedSkin;
            final pTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

            // Smooth horizontal roll — loops offscreen left → offscreen right
            final xPos = (pTime * rollSpeed) % (trackW + wheelSize) - wheelSize;

            // Smooth vertical flip via _demoYCtrl (easeInOut)
            const yTop = 2.0;
            const yBot = trackH - wheelSize - 2.0;
            final yFrac = Curves.easeInOut.transform(_demoYCtrl.value);
            final yPos  = yBot + yFrac * (yTop - yBot);

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Top rail
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        skin.themeColor.withValues(alpha: 0.28),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Bottom rail
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        skin.themeColor.withValues(alpha: 0.28),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Rolling wheel
                Positioned(
                  top:  yPos,
                  left: xPos,
                  child: SizedBox(
                    width:  wheelSize,
                    height: wheelSize,
                    child: CustomPaint(
                      painter: SkinPreviewPainter(
                        color:   skin.themeColor,
                        glowT:   0.99,
                        skinId:  skin.id,
                        repaint: _wheelCtrl,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }

  Widget _buildPlayButton() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, _) {
        final g = _glowCtrl.value; // 0.0 ~ 1.0, pulsing
        return GestureDetector(
          onTap: () {
            AudioManager.playButton();
            widget.onStart();
          },
          child: Container(
            width: 200,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: _accent, width: 1.5),
              borderRadius: BorderRadius.circular(28),
              color: _accent.withValues(alpha: 0.05),
              boxShadow: [
                // Inner glow
                BoxShadow(
                  color: _accent.withValues(alpha: 0.40 + g * 0.35),
                  blurRadius: 20,
                ),
                // Outer glow
                BoxShadow(
                  color: _accent.withValues(alpha: 0.10 + g * 0.20),
                  blurRadius: 60,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'PLAY',
                style: TextStyle(
                  color: _accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: _accent.withValues(alpha: 0.80),
                      blurRadius: 10,
                    ),
                    Shadow(
                      color: _accent.withValues(alpha: 0.40),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
            ),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 2000.ms,
            color: _accent.withValues(alpha: 0.28),
          ),
        );
      },
    );
  }

  Widget _buildSkinShopButton() {
    return GestureDetector(
      onTap: () async {
        AudioManager.playButton();
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SkinShopScreen()),
        );
        // Refresh after returning from shop
        if (mounted) setState(() {});
      },
      child: Container(
        width: 160,
        height: 42,
        decoration: BoxDecoration(
          border: Border.all(
            color: _purple.withValues(alpha: 0.65),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(21),
          color: _purple.withValues(alpha: 0.05),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.30),
              blurRadius: 16,
            ),
            BoxShadow(
              color: _purple.withValues(alpha: 0.12),
              blurRadius: 40,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SKIN SHOP',
            style: TextStyle(
              color: _purple.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: _purple.withValues(alpha: 0.80),
                  blurRadius: 8,
                ),
                Shadow(
                  color: _purple.withValues(alpha: 0.40),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
        ),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .shimmer(
        duration: 2200.ms,
        color: _purple.withValues(alpha: 0.22),
      ),
    );
  }

  Widget _buildBestScore() {
    return Text(
      'BEST  ${widget.bestScore}',
      style: TextStyle(
        color: _green.withValues(alpha: 0.85),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 3,
        shadows: [
          Shadow(
            color: _green.withValues(alpha: 0.60),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

// ── Gravity particles (flutter widget layer on menu) ─────────────────────────

class _GravityParticles extends StatelessWidget {
  const _GravityParticles();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx   = size.width  / 2;
    final cy   = size.height / 2;
    final rng  = Random(13);

    return Stack(
      children: List.generate(18, (i) {
        final sx = rng.nextDouble() * size.width;
        final sy = rng.nextDouble() * size.height;
        final delay    = (rng.nextDouble() * 2800).round();
        final duration = 2200 + (i % 4) * 600;

        return Positioned(
          left: sx,
          top:  sy,
          child: Container(
            width: 2,
            height: 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          )
          .animate(
            onPlay: (c) => c.repeat(),
            delay: Duration(milliseconds: delay),
          )
          .move(
            begin: Offset.zero,
            end: Offset(cx - sx, cy - sy),
            duration: Duration(milliseconds: duration),
            curve: Curves.easeInExpo,
          )
          .fadeOut(duration: Duration(milliseconds: duration)),
        );
      }),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _LogoRingPainter extends CustomPainter {
  final double angle;
  final double glowAlpha;

  _LogoRingPainter({required this.angle, required this.glowAlpha});

  static const Color _accent = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final rx = size.width  * 0.50;
    final ry = size.height * 0.58;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final oval = Rect.fromCenter(
      center: Offset.zero,
      width:  rx * 2,
      height: ry * 2,
    );

    canvas.drawOval(
      oval,
      Paint()
        ..color       = _accent.withValues(alpha: glowAlpha * 0.12)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color       = _accent.withValues(alpha: glowAlpha * 0.22)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoRingPainter old) =>
      old.angle != angle || old.glowAlpha != glowAlpha;
}

