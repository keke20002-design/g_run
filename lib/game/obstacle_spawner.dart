import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'gravity_flip_game.dart';
import 'difficulty_manager.dart';
import 'obstacle.dart';
import 'rotating_obstacle.dart';
import 'grav_zone.dart';
import 'energy_barrier.dart';
import 'breakable_block.dart';
import 'electric_sphere.dart';
import 'laser_cannon.dart';

// ── Queued delayed spawn ───────────────────────────────────────────────────────

class _Queued {
  double delay;
  final ObstacleSide    side;
  final ObstacleVariant variant;
  final bool isSlim;

  _Queued({
    required this.delay,
    required this.side,
    required this.variant,
    this.isSlim = false,
  });
}

// ── Pop-wall warning flash ─────────────────────────────────────────────────────

class PopWarning extends PositionComponent
    with HasGameReference<GravityFlipGame> {
  double _age = 0;
  static const double _duration = 0.20;
  final ObstacleSide side;
  final double       wallHeight;

  static const Color _warn = Color(0xFFFF8C00);

  PopWarning({
    required Vector2 pos,
    required this.side,
    required this.wallHeight,
  }) : super(position: pos, size: Vector2(28.0, wallHeight));

  @override
  void update(double dt) {
    if (game.state != GameState.playing) { removeFromParent(); return; }
    _age += dt;
    if (_age >= _duration) {
      game.add(Obstacle(
        pos:           Vector2(position.x, position.y),
        side:          side,
        obstacleHeight: wallHeight,
        variant:       ObstacleVariant.popWall,
        isInstant:     true,
      ));
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final flash = ((sin(_age * 50.0) + 1) / 2);
    final rect  = Rect.fromLTWH(0, 0, size.x, wallHeight);
    // Flashing fill
    canvas.drawRect(rect,
        Paint()..color = _warn.withValues(alpha: flash * 0.80));
    // Border
    canvas.drawRect(rect,
        Paint()
          ..color       = _warn.withValues(alpha: 0.95)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }
}

// ── Spawner ───────────────────────────────────────────────────────────────────

class ObstacleSpawner extends Component with HasGameReference<GravityFlipGame> {
  double _timeSinceLastSpawn = 0;
  double _nearMissBonus      = 0;
  final List<_Queued> _queue = [];
  final Random _rng = Random();

  double get _spawnInterval {
    final dm = game.difficultyManager;
    return (dm.minGap / dm.speed);
  }

  @override
  void update(double dt) {
    for (final q in _queue) { q.delay -= dt; }
    final ready = _queue.where((q) => q.delay <= 0).toList();
    for (final q in ready) {
      _doSpawn(q.side, variant: q.variant, isSlim: q.isSlim);
    }
    _queue.removeWhere((q) => q.delay <= 0);

    _timeSinceLastSpawn += dt;
    
    // Near miss bonus: if active, it delays the NEXT spawn
    double effectiveInterval = _spawnInterval;
    if (_nearMissBonus > 0) {
      effectiveInterval += _nearMissBonus;
      _nearMissBonus = 0; // consumed
    }

    if (_timeSinceLastSpawn >= effectiveInterval) {
      _timeSinceLastSpawn = 0;
      _pickAndSpawn();
    }
  }

  void addNearMissBonus(double extraGap) {
    // Convert 20px gap to seconds based on current speed
    final dtBonus = extraGap / game.difficultyManager.speed;
    _nearMissBonus += dtBonus;
  }

  void _pickAndSpawn() {
    final score = game.scoreSystem.score;
    final phase = game.difficultyManager.currentPhase;

    // Relief phase: much simpler spawning
    if (phase == DifficultyPhase.relief) {
      if (_rng.nextDouble() < 0.3) _spawnPillar();
      return;
    }

    // ── Rare specials: independent probability per type ───────────────────────
    if (score >= 10000 && _rng.nextDouble() < 0.05) { _spawnGravZone();       return; }
    if (score >= 9000  && _rng.nextDouble() < 0.08) { _spawnElectricSphere(); return; }
    if (score >= 8000  && _rng.nextDouble() < 0.07) { _spawnLaserCannon();    return; }
    if (score >= 7000  && _rng.nextDouble() < 0.08) { _spawnPopWall();        return; }
    if (score >= 4000  && _rng.nextDouble() < 0.10) { _spawnRotating();       return; }

    // ── Determine if we spawn a pattern or a single ──────────────────────────
    final patternChance = (phase == DifficultyPhase.hard) ? 0.6 : 0.3;
    if (_rng.nextDouble() < patternChance && score > 2000) {
      _spawnRandomPattern();
      return;
    }

    // ── Normal obstacle pool ──────────────────────────────────────────────────
    final r = _rng.nextDouble();
    if (score < 1500) {
      _spawnPillar();
    } else if (score < 2000) {
      if (r < 0.65) { _spawnPillar(); } else { _spawnMoving(); }
    } else if (score < 3000) {
      if (r < 0.45)      { _spawnPillar(); }
      else if (r < 0.70) { _spawnMoving(); }
      else               { _spawnEnergyBarrier(); }
    } else if (score < 5000) {
      if (r < 0.35)      { _spawnPillar(); }
      else if (r < 0.55) { _spawnMoving(); }
      else if (r < 0.72) { _spawnSpikeBurst(); }
      else               { _spawnBreakableBlock(); }
    } else {
      if (r < 0.28)      { _spawnPillar(); }
      else if (r < 0.46) { _spawnSpikeBurst(); }
      else if (r < 0.64) { _spawnGate(); }
      else if (r < 0.78) { _spawnMoving(); }
      else if (r < 0.90) { _spawnEnergyBarrier(); }
      else               { _spawnBreakableBlock(); }
    }
  }

  void _spawnRandomPattern() {
    final r = _rng.nextInt(3);
    switch (r) {
      case 0: _patternSineWave(); break;
      case 1: _patternStaircase(); break;
      case 2: _patternDoubleGate(); break;
    }
  }

  void _patternSineWave() {
    final startTop = _rng.nextBool();
    for (int i = 0; i < 4; i++) {
      final isTop = (i % 2 == 0) ? startTop : !startTop;
      _queue.add(_Queued(
        delay: i * 0.45,
        side: isTop ? ObstacleSide.top : ObstacleSide.bottom,
        variant: ObstacleVariant.pillar,
      ));
    }
  }

  void _patternStaircase() {
    final side = _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom;
    for (int i = 0; i < 3; i++) {
      _queue.add(_Queued(
        delay: i * 0.4,
        side: side,
        variant: ObstacleVariant.pillar,
      ));
    }
  }

  void _patternDoubleGate() {
    _spawnGate();
    _queue.add(_Queued(
      delay: 0.8,
      side: _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom,
      variant: ObstacleVariant.gate,
    ));
  }

  // ── Normal obstacle spawners ──────────────────────────────────────────────

  void _spawnPillar() {
    final side = _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom;
    _doSpawn(side, variant: ObstacleVariant.pillar);
  }

  void _spawnSpikeBurst() {
    final score = game.scoreSystem.score;
    final side  = _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom;
    final count = score >= 10000 ? 1 + _rng.nextInt(3) : 1 + _rng.nextInt(2);
    _doSpawn(side, variant: ObstacleVariant.spike, isSlim: true);
    for (int i = 1; i <= count; i++) {
      _queue.add(_Queued(
        delay:   i * 0.32,
        side:    side,
        variant: ObstacleVariant.spike,
        isSlim:  true,
      ));
    }
  }

  void _spawnGate() {
    final firstTop = _rng.nextBool();
    _doSpawn(
      firstTop ? ObstacleSide.top : ObstacleSide.bottom,
      variant: ObstacleVariant.gate,
    );
    _queue.add(_Queued(
      delay:   0.35,
      side:    firstTop ? ObstacleSide.bottom : ObstacleSide.top,
      variant: ObstacleVariant.gate,
    ));
  }

  void _spawnMoving() {
    final top       = _rng.nextBool();
    final amplitude = (20 + _rng.nextDouble() * 20) * (top ? 1 : -1);
    final screenH   = game.size.y;
    final dm        = game.difficultyManager;
    final h         = _randomHeight(dm.maxObstacleHeight);
    final y         = top ? 0.0 : screenH - h;
    final screenW   = game.size.x;
    game.add(Obstacle(
      pos:               Vector2(screenW, y),
      side:              top ? ObstacleSide.top : ObstacleSide.bottom,
      obstacleHeight:    h,
      variant:           ObstacleVariant.moving,
      isMoving:          true,
      oscillateAmplitude: amplitude,
    ));
  }

  // ── New obstacle spawners ─────────────────────────────────────────────────

  void _spawnRotating() {
    final score   = game.scoreSystem.score;
    final screenW = game.size.x;
    final screenH = game.size.y;
    final y       = screenH * (0.30 + _rng.nextDouble() * 0.40);
    final rotDir  = _rng.nextBool() ? 1.0 : -1.0;
    final base    = score >= 10000 ? 4.0 : (score >= 8000 ? 3.5 : 2.0);
    final add     = score >= 10000 ? 3.0 : (score >= 8000 ? 2.5 : 2.0);
    final speed   = (base + _rng.nextDouble() * add) * rotDir;
    game.add(RotatingObstacle(
      pos:      Vector2(screenW, y),
      rotSpeed: speed,
    ));
  }

  void _spawnPopWall() {
    final screenH  = game.size.y;
    final screenW  = game.size.x;

    // Prefer the side that has no visible obstacles, to avoid Y-overlap
    final visible     = game.children.whereType<Obstacle>()
        .where((o) => o.position.x + o.size.x > 0 && o.position.x < screenW);
    final topBlocked    = visible.any((o) => o.side == ObstacleSide.top);
    final bottomBlocked = visible.any((o) => o.side == ObstacleSide.bottom);

    final ObstacleSide side;
    if (topBlocked && !bottomBlocked) {
      side = ObstacleSide.bottom;
    } else if (bottomBlocked && !topBlocked) {
      side = ObstacleSide.top;
    } else {
      side = _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom;
    }

    final h = 80.0 + _rng.nextDouble() * 80;
    final y = side == ObstacleSide.top ? 0.0 : screenH - h;
    game.add(PopWarning(
      pos:        Vector2(screenW * 0.72, y),
      side:       side,
      wallHeight: h,
    ));
  }

  void _spawnGravZone() {
    game.add(GravZone(
      pos:    Vector2(game.size.x, 0),
      height: game.size.y,
    ));
  }

  void _spawnEnergyBarrier() {
    final screenH = game.size.y;
    final screenW = game.size.x;
    final side    = _rng.nextBool() ? ObstacleSide.top : ObstacleSide.bottom;
    final h       = 60.0 + _rng.nextDouble() * (screenH * 0.35);
    final y       = side == ObstacleSide.top ? 0.0 : screenH - h;
    game.add(EnergyBarrier(
      pos:           Vector2(screenW, y),
      side:          side,
      barrierHeight: h,
    ));
  }

  void _spawnBreakableBlock() {
    final screenH = game.size.y;
    final screenW = game.size.x;
    final y       = screenH * (0.25 + _rng.nextDouble() * 0.50);
    game.add(BreakableBlock(pos: Vector2(screenW, y)));
  }

  void _spawnElectricSphere() {
    final screenH = game.size.y;
    final screenW = game.size.x;
    final y       = screenH * (0.25 + _rng.nextDouble() * 0.50);
    game.add(ElectricSphere(pos: Vector2(screenW, y)));
  }

  void _spawnLaserCannon() {
    final screenH = game.size.y;
    final screenW = game.size.x;
    final isTop   = _rng.nextBool();
    final y       = isTop ? 0.0 : screenH - 20.0; // 20 = cannon height
    game.add(LaserCannon(pos: Vector2(screenW, y), isTop: isTop));
  }

  // ── Core spawn helper ─────────────────────────────────────────────────────

  void _doSpawn(
    ObstacleSide side, {
    required ObstacleVariant variant,
    bool isSlim = false,
  }) {
    final dm      = game.difficultyManager;
    final screenW = game.size.x;
    final screenH = game.size.y;
    final h       = isSlim
        ? 55 + _rng.nextDouble() * 50
        : _randomHeight(dm.maxObstacleHeight);
    final y = side == ObstacleSide.top ? 0.0 : screenH - h;

    game.add(Obstacle(
      pos:           Vector2(screenW, y),
      side:          side,
      obstacleHeight: h,
      variant:       variant,
      isSlim:        isSlim,
    ));
  }

  double _randomHeight(double max) => 40 + _rng.nextDouble() * (max - 40);

  void reset() {
    _timeSinceLastSpawn = 0;
    _queue.clear();
  }
}
