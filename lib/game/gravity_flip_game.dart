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
import 'player.dart';

export 'gravity_flip_game.dart';

enum GameState { playing, dead, menu }

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
    children.whereType<Player>().toList().forEach((p) => p.removeFromParent());
    children.whereType<ObstacleSpawner>().toList().forEach((s) => s.removeFromParent());

    player  = Player()..position = Vector2(80, size.y - Player.playerSize);
    spawner = ObstacleSpawner();

    add(player);
    add(spawner);
    _timescale           = 1.0;
    difficultyManager.reset();
    scoreSystem.reset();
    _totalTime           = 0;
    _caTime              = 0;
    _milestoneBoostTime  = 0;
    _lastMilestone       = 0;
    _highEnergyTimer     = 0;
    _highEnergyTriggered = false;
    state = GameState.playing;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (paused) return;
    if (state == GameState.playing) player.flip();
  }

  @override
  void update(double dt) {
    // Slow-motion: scale child updates, but pass real dt to death effects
    super.update(dt * _timescale);
    if (state == GameState.dead) {
      player.updateDeathEffects(dt);
      return;
    }
    if (state != GameState.playing) return;
    final sdt = dt * _timescale;
    difficultyManager.update(sdt, scoreSystem.score);
    scoreSystem.update(sdt, difficultyManager.speed);
    if (_shakeTime          > 0) _shakeTime          -= sdt;
    if (_flipShakeTime      > 0) _flipShakeTime      -= sdt;
    if (_caTime             > 0) _caTime             -= sdt;
    if (_milestoneBoostTime > 0) _milestoneBoostTime -= sdt;
    if (_highEnergyTimer    > 0) _highEnergyTimer    -= sdt;
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

    // 3000+ ambient micro-vibration (stronger at 5000+)
    if (state == GameState.playing && score >= 3000 &&
        _shakeTime <= 0 && _flipShakeTime <= 0) {
      final amp = score >= 5000 ? 3.0 : 0.5;
      dx += sin(_totalTime * 23.0) * amp;
      dy += sin(_totalTime * 17.0) * amp * 0.8;
    }

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
      canvas.restore();
    } else {
      super.render(canvas);
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
    player.isDead = true;
    player.triggerDeathEffects();
    onPlayerDeath();
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

  void onNearMiss(NearMissGrade grade) => onNearMissCallback?.call(grade);

  void returnToMenu() {
    children.whereType<Obstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<RotatingObstacle>().toList().forEach((o) => o.removeFromParent());
    children.whereType<GravZone>().toList().forEach((o) => o.removeFromParent());
    children.whereType<Player>().toList().forEach((p) => p.removeFromParent());
    children.whereType<ObstacleSpawner>().toList().forEach((s) => s.removeFromParent());
    _highEnergyTimer = 0;
    _caTime          = 0;
    _shakeTime       = 0;
    _timescale       = 1.0;
    state = GameState.menu;
  }
}
