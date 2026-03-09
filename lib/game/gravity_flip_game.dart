import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../systems/score_system.dart';
import '../systems/audio_manager.dart';
import 'background_component.dart';
import 'difficulty_manager.dart';
import 'speed_lines.dart';
import 'obstacle.dart';
import 'obstacle_spawner.dart';
import 'rotating_obstacle.dart';
import 'grav_zone.dart';
import 'energy_barrier.dart';
import 'breakable_block.dart';
import 'breakable_pillar.dart';
import 'electric_sphere.dart';
import 'laser_cannon.dart';
import 'player.dart';

export 'gravity_flip_game.dart';

enum GameState { playing, dead, menu }

enum TutorialStep { tap, obstacle, nearMiss, combo, done }

class GravityFlipGame extends FlameGame
    with TapCallbacks, HasCollisionDetection {
  late Player player;
  late ObstacleSpawner spawner;

  final DifficultyManager difficultyManager = DifficultyManager();
  final ScoreSystem scoreSystem = ScoreSystem();

  GameState state = GameState.menu;

  VoidCallback? onDeath;
  VoidCallback? onFlip;
  void Function(NearMissGrade)? onNearMissCallback;
  void Function(TutorialStep)? onTutorialStep;

  TutorialStep tutorialStep        = TutorialStep.tap;
  int          _tutorialNearMissCount = 0;

  // Death shake
  double _shakeTime = 0;
  static const double _shakeDuration  = 0.30;
  static const double _shakeIntensity = 6.0;

  // Flip micro-shake
  double _flipShakeTime = 0;
  static const double _flipShakeDuration  = 0.08;
  static const double _flipShakeIntensity = 2.5;

  // Total elapsed gameplay time (for ambient shake)
  double _totalTime = 0;

  // 1000-point milestone chromatic aberration flash
  double _caTime = 0;
  static const double _caDuration = 0.22;

  // 1000-point milestone star/character boost
  double _milestoneBoostTime = 0;
  static const double _milestoneBoostDuration = 0.65;

  int _lastMilestone = 0;

  // HIGH ENERGY MODE overlay (first time reaching 5000)
  double _highEnergyTimer     = 0;
  bool   _highEnergyTriggered = false;
  static const double _highEnergyDuration = 1.2;

  // Slow motion on death
  double _timescale = 1.0;

  // Shield
  bool   shieldActive   = false;
  double _shieldHitTime = 0.0;
  static const double _shieldHitDuration = 0.45;

  /// 0.0~1.0 — read by BackgroundComponent and Player
  double get milestoneBoostIntensity =>
      (_milestoneBoostTime / _milestoneBoostDuration).clamp(0.0, 1.0);

  double get totalTime => _totalTime;

  @override
  Color backgroundColor() => const Color(0xFF070B14);

  @override
  Future<void> onLoad() async {
    await AudioManager.load();
    await scoreSystem.loadBest();
    add(BackgroundComponent());
    add(SpeedLinesComponent());
  }

  void startGame() {
    children.whereType<Obstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<RotatingObstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<GravZone>().toList().forEach((o) => o.removeFromParent());
    children.whereType<EnergyBarrier>().toList().forEach((o) => o.removeFromParent());
    children.whereType<BreakableBlock>().toList().forEach((o) => o.removeFromParent());
    children.whereType<BreakablePillar>().toList().forEach((o) => o.removeFromParent());
    children.whereType<ElectricSphere>().toList().forEach((o) => o.removeFromParent());
    children.whereType<LaserCannon>().toList().forEach((o) => o.removeFromParent());
    children.whereType<Player>().toList().forEach((p) => p.removeFromParent());
    children.whereType<ObstacleSpawner>().toList().forEach((s) => s.removeFromParent());

    player  = Player()..position = Vector2(80, size.y - Player.playerSize);
    spawner = ObstacleSpawner();

    add(player);
    add(spawner);
    _timescale           = 1.0;
    shieldActive         = false;
    _shieldHitTime       = 0.0;
    difficultyManager.reset();
    scoreSystem.reset();
    _totalTime              = 0;
    _caTime                 = 0;
    _milestoneBoostTime     = 0;
    _lastMilestone          = 0;
    _highEnergyTimer        = 0;
    _highEnergyTriggered    = false;
    tutorialStep            = TutorialStep.tap;
    _tutorialNearMissCount  = 0;
    state = GameState.playing;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (paused) return;
    if (state == GameState.playing) {
      // Tutorial: first tap dismisses TAP TO FLIP hint
      if (tutorialStep == TutorialStep.tap) {
        tutorialStep = TutorialStep.obstacle;
        onTutorialStep?.call(TutorialStep.obstacle);
      }
      player.flip();
    }
  }

  @override
  void update(double dt) {
    // Record player Y before children update (for sweep collision)
    final prevY = (state == GameState.playing && !player.isDead)
        ? player.position.y
        : -1.0;

    // Slow-motion: scale child updates, but pass real dt to death effects
    super.update(dt * _timescale);
    if (state == GameState.dead) {
      player.updateDeathEffects(dt);
      return;
    }
    if (state != GameState.playing) return;
    final sdt = dt * _timescale;
    difficultyManager.update(sdt, scoreSystem.difficultyScore);
    scoreSystem.update(sdt, difficultyManager.speed);

    // BreakableBlock collision:
    // 1) 이번 프레임 sweep (플레이어 이동 경로 전체)
    // 2) 플레이어가 최근 0.45초 안에 블록 y구간을 지난 경우 (유예 플래그)
    if (!player.isDead && prevY >= 0) {
      const ps = Player.playerSize;
      final currY = player.position.y;
      final px    = player.position.x;
      final sweepTop    = min(prevY, currY);
      final sweepBottom = max(prevY, currY) + ps;
      for (final bb in children.whereType<BreakableBlock>().toList()) {
        if (bb.isBroken) continue;
        // X 겹침 확인
        if (px + ps <= bb.position.x || px >= bb.position.x + bb.size.x) continue;
        // Y 조건: 이번 프레임 sweep OR 유예 플래그
        final sweepHit = sweepBottom > bb.position.y && sweepTop < bb.position.y + bb.size.y;
        if (!sweepHit && !bb.playerPassedThroughY) continue;
        if (bb.tryBreak()) {
          scoreSystem.registerNearMiss();
          onNearMiss(NearMissGrade.close);
        }
      }

      // BreakablePillar 충돌 (top/bottom 부착 기둥)
      for (final bp in children.whereType<BreakablePillar>().toList()) {
        if (bp.isBroken) continue;
        if (px + ps <= bp.position.x || px >= bp.position.x + bp.size.x) continue;
        final sweepHit = sweepBottom > bp.position.y && sweepTop < bp.position.y + bp.size.y;
        if (!sweepHit && !bp.playerPassedThroughY) continue;
        if (bp.tryBreak()) {
          scoreSystem.registerNearMiss();
          onNearMiss(NearMissGrade.close);
        }
      }
    }
    if (_shakeTime          > 0) _shakeTime          -= sdt;
    if (_flipShakeTime      > 0) _flipShakeTime      -= sdt;
    if (_caTime             > 0) _caTime             -= sdt;
    if (_milestoneBoostTime > 0) _milestoneBoostTime -= sdt;
    if (_highEnergyTimer    > 0) _highEnergyTimer    -= sdt;
    if (_shieldHitTime      > 0) _shieldHitTime      -= dt; // wall-clock
    _totalTime += sdt;

    // Detect 1000-point milestones → CA flash + star boost + character rush
    final milestone = scoreSystem.score ~/ 1000;
    if (milestone > _lastMilestone && milestone > 0) {
      _lastMilestone      = milestone;
      _caTime             = _caDuration;
      _milestoneBoostTime = _milestoneBoostDuration;
      player.triggerMilestoneRush();
    }

    // Detect first time reaching 5000 → HIGH ENERGY MODE overlay
    if (!_highEnergyTriggered && scoreSystem.score >= 5000) {
      _highEnergyTriggered = true;
      _highEnergyTimer     = _highEnergyDuration;
    }
  }

  @override
  void render(Canvas canvas) {
    double dx = 0, dy = 0;

    // Death shake
    if (_shakeTime > 0) {
      final p = _shakeTime / _shakeDuration;
      dx += ((_shakeTime * 90) % (_shakeIntensity * 2) - _shakeIntensity) * p;
      dy += ((_shakeTime * 70) % (_shakeIntensity * 2) - _shakeIntensity) * p;
    }

    // Flip micro-shake
    if (_flipShakeTime > 0) {
      final p = _flipShakeTime / _flipShakeDuration;
      dx += ((_flipShakeTime * 300) % (_flipShakeIntensity * 2) - _flipShakeIntensity) * p;
    }

    // Score-based zoom: 1.02 at 1000+
    final score = scoreSystem.score;
    final zoom  = score >= 1000 ? 1.02 : 1.0;


    // Milestone CA jitter (horizontal glitch)
    if (_caTime > 0) {
      final p = (_caTime / _caDuration).clamp(0.0, 1.0);
      dx += sin(_caTime * 70.0) * p * 4.5;
    }

    final needsTransform = (dx != 0 || dy != 0 || zoom != 1.0);

    if (needsTransform) {
      canvas.save();
      if (zoom != 1.0) {
        final cx = size.x / 2;
        final cy = size.y / 2;
        canvas.translate(cx, cy);
        canvas.scale(zoom);
        canvas.translate(-cx, -cy);
      }
      if (dx != 0 || dy != 0) {
        canvas.translate(dx, dy);
      }
      super.render(canvas);
      _drawComboRing(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
      _drawComboRing(canvas);
    }

    // Cyan flash overlay at screen space (no transform applied)
    if (_caTime > 0) {
      final p = (_caTime / _caDuration).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: p * 0.13),
      );
    }

    // HIGH ENERGY MODE text overlay (only during active gameplay)
    if (_highEnergyTimer > 0 && state == GameState.playing) {
      _drawHighEnergyMode(canvas);
    }
  }

  void _drawHighEnergyMode(Canvas canvas) {
    final t = (_highEnergyTimer / _highEnergyDuration).clamp(0.0, 1.0);
    // Fade in over first 0.125 of remaining fraction, fade out over last 0.25
    double alpha;
    if (t > 0.875) {
      alpha = (1.0 - t) / 0.125;
    } else if (t < 0.25) {
      alpha = t / 0.25;
    } else {
      alpha = 1.0;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'HIGH ENERGY MODE',
        style: TextStyle(
          fontSize:     18,
          fontWeight:   FontWeight.bold,
          color:        const Color(0xFF00E5FF).withValues(alpha: alpha),
          letterSpacing: 3.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset((size.x - tp.width) / 2, size.y * 0.34),
    );
  }

  /// Called by rotating obstacle / other non-Obstacle components.
  void killPlayer() {
    if (state != GameState.playing || player.isDead) return;
    if (shieldActive) { absorbShieldHit(); return; }
    player.isDead = true;
    player.triggerDeathEffects();
    onPlayerDeath();
  }

  void absorbShieldHit() {
    shieldActive   = false;
    _shieldHitTime = _shieldHitDuration;
    difficultyManager.nearMissGaugeCount = 0;
    _shakeTime = _shakeDuration * 0.5; // 약한 진동 피드백
  }

  /// Called by GravZone — flip without killing.
  void flipPlayer() {
    if (state != GameState.playing || player.isDead) return;
    player.flip();
  }

  Future<void> onPlayerDeath() async {
    state      = GameState.dead;
    _timescale = 0.15;           // slow motion
    _shakeTime = _shakeDuration;
    AudioManager.playGameOver();
    // Hold slow-mo for 220ms wall clock, then snap back
    await Future.delayed(const Duration(milliseconds: 220));
    _timescale = 1.0;
    // Wait for death effects to finish before showing game over
    await Future.delayed(const Duration(milliseconds: 480));
    await scoreSystem.saveBest(difficultyManager.difficultyMultiplier);
    onDeath?.call();
  }

  void onGravityFlip() {
    _flipShakeTime = _flipShakeDuration;
    onFlip?.call();
  }

  void onNearMiss(NearMissGrade grade) {
    difficultyManager.addNearMissGauge();
    if (difficultyManager.gaugeReady && !shieldActive) {
      difficultyManager.consumeGauge();
      shieldActive = true;
    }

    // ── Tutorial progression ────────────────────────────────────────
    if (tutorialStep != TutorialStep.done) {
      if (tutorialStep == TutorialStep.tap || tutorialStep == TutorialStep.obstacle) {
        tutorialStep = TutorialStep.nearMiss;
        onTutorialStep?.call(TutorialStep.nearMiss);
      } else if (tutorialStep == TutorialStep.nearMiss) {
        _tutorialNearMissCount++;
        if (_tutorialNearMissCount >= 2) {
          tutorialStep = TutorialStep.combo;
          onTutorialStep?.call(TutorialStep.combo);
          // Schedule tutorial done after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (state == GameState.playing && tutorialStep == TutorialStep.combo) {
              tutorialStep = TutorialStep.done;
              onTutorialStep?.call(TutorialStep.done);
            }
          });
        }
      }
    }

    // ── Near Miss 10-stage combo effects ────────────────────────────
    final combo = scoreSystem.combo;
    if (combo == 5) {
      // RISK MASTER: 0.1s slow-motion
      _triggerBriefSlowMo();
    }
    if (combo >= 9) {
      // GODLIKE+: screen shake
      _shakeTime = _shakeDuration * 0.45;
    }

    onNearMissCallback?.call(grade);
  }

  Future<void> _triggerBriefSlowMo() async {
    _timescale = 0.25;
    await Future.delayed(const Duration(milliseconds: 100));
    if (state == GameState.playing) _timescale = 1.0;
  }

  void _drawComboRing(Canvas canvas) {
    if (state != GameState.playing) return;
    final gauge = difficultyManager.nearMissGaugeCount;
    if (gauge == 0 && !shieldActive && _shieldHitTime <= 0) return;

    final cx = player.position.x + Player.playerSize / 2;
    final cy = player.position.y + Player.playerSize / 2;
    const ringR    = 27.0;
    const sw       = 3.0;
    const segments = 5;
    const gap      = 0.14; // 세그먼트 사이 간격 (radian)
    const segSweep = (2 * pi / segments) - gap;
    const startA   = -pi / 2; // 12시 방향

    // 쉴드 색상 팔레트
    const colorBase  = Color(0xFF00CFFF); // 밝은 사이언
    const colorCore  = Color(0xFFADE8FF); // 코어 하이라이트
    const colorDim   = Color(0xFF0A1A28); // 빈 칸

    final pulse = 0.60 + 0.40 * sin(_totalTime * 3.8);
    // 쉴드 활성 시 느린 회전
    final rot   = shieldActive ? _totalTime * 0.6 : 0.0;

    for (int i = 0; i < segments; i++) {
      final filled   = shieldActive || i < gauge;
      final segStart = startA + i * (2 * pi / segments) + gap / 2 + rot;
      final center   = Offset(cx, cy);
      final rect     = Rect.fromCircle(center: center, radius: ringR);

      if (!filled) {
        // 빈 칸 — 어두운 아웃라인
        canvas.drawArc(rect, segStart, segSweep, false,
          Paint()
            ..style       = PaintingStyle.stroke
            ..strokeWidth = sw * 0.7
            ..strokeCap   = StrokeCap.round
            ..color       = colorDim,
        );
        continue;
      }

      // 채워진 / 쉴드 활성 칸
      final glowAlpha  = shieldActive ? pulse * 0.85 : 0.50;
      final glowBlur   = shieldActive ? 6.0 + pulse * 7 : 4.0;
      final glowStroke = shieldActive ? sw + pulse * 9  : sw + 4;

      // 외부 글로우
      canvas.drawArc(rect, segStart, segSweep, false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = glowStroke
          ..strokeCap   = StrokeCap.round
          ..color       = colorBase.withValues(alpha: glowAlpha)
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, glowBlur),
      );
      // 메인 선
      canvas.drawArc(rect, segStart, segSweep, false,
        Paint()
          ..style       = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap   = StrokeCap.round
          ..color       = shieldActive
              ? Color.lerp(colorBase, colorCore, pulse * 0.6)!
              : colorBase.withValues(alpha: 0.90),
      );
    }

    // 쉴드 활성 시 내부 반투명 원판 (force field 느낌)
    if (shieldActive) {
      canvas.drawCircle(Offset(cx, cy), ringR - sw,
        Paint()..color = colorBase.withValues(alpha: pulse * 0.08),
      );
      // 회전 스캔라인 (2개)
      for (int s = 0; s < 2; s++) {
        final scanAngle = rot * 2.5 + s * pi;
        final ex = cx + cos(scanAngle) * (ringR - sw);
        final ey = cy + sin(scanAngle) * (ringR - sw);
        canvas.drawLine(Offset(cx, cy), Offset(ex, ey),
          Paint()
            ..color       = colorCore.withValues(alpha: pulse * 0.22)
            ..strokeWidth = 1.0
            ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // 쉴드 흡수 충격파
    if (_shieldHitTime > 0) {
      final t = 1.0 - (_shieldHitTime / _shieldHitDuration);
      for (int r = 0; r < 3; r++) {
        final delay = r * 0.10;
        final lt    = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        if (lt <= 0) continue;
        final burstR = ringR + lt * (40.0 + r * 12);
        final alpha  = ((1.0 - lt) * (1.0 - delay)).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(cx, cy), burstR,
          Paint()
            ..style       = PaintingStyle.stroke
            ..strokeWidth = max(0.5, sw * (1.0 - lt * 0.9))
            ..color       = (r == 0 ? Colors.white : colorBase)
                .withValues(alpha: alpha * 0.85)
            ..maskFilter  = MaskFilter.blur(BlurStyle.normal, 8 - lt * 5),
        );
      }
    }
  }

  void triggerLaserFlash() {
    _caTime = _caDuration;
  }

  void returnToMenu() {
    children.whereType<Obstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<RotatingObstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<GravZone>().toList().forEach((o) => o.removeFromParent());
    children.whereType<EnergyBarrier>().toList().forEach((o) => o.removeFromParent());
    children.whereType<BreakableBlock>().toList().forEach((o) => o.removeFromParent());
    children.whereType<BreakablePillar>().toList().forEach((o) => o.removeFromParent());
    children.whereType<ElectricSphere>().toList().forEach((o) => o.removeFromParent());
    children.whereType<LaserCannon>().toList().forEach((o) => o.removeFromParent());
    children.whereType<Player>().toList().forEach((p) => p.removeFromParent());
    children.whereType<ObstacleSpawner>().toList().forEach((s) => s.removeFromParent());
    _highEnergyTimer = 0;
    _caTime          = 0;
    _shakeTime       = 0;
    _timescale       = 1.0;
    state = GameState.menu;
  }
}
