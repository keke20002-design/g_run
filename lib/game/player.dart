import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../systems/skin_manager.dart';
import '../systems/audio_manager.dart';
import 'gravity_flip_game.dart';
import 'obstacle.dart';
import 'skins/wheel_skin.dart';
import 'skins/classic_neon_skin.dart';
import 'skins/dual_core_skin.dart';
import 'skins/pulse_core_skin.dart';
import 'skins/black_hole_core_skin.dart';
import 'skins/prism_glass_skin.dart';
import 'skins/electric_pulse_skin.dart';
import 'skins/cyberpunk_wheel_skin.dart';
import 'skins/guardian_shield_skin.dart';

// ── Particle / effect data classes ───────────────────────────────────────────

class _TrailDot {
  double x, y, age;
  _TrailDot(this.x, this.y) : age = 0;
}

class _BurstDot {
  double x, y, vx, vy, age;
  _BurstDot(this.x, this.y, this.vx, this.vy) : age = 0;
}

class _AntiGravParticle {
  double x, y, vx, vy, age;
  _AntiGravParticle(this.x, this.y, this.vx, this.vy) : age = 0;
}

class _Shockwave {
  double age;
  _Shockwave() : age = 0;
}

class _DeathSpark {
  double x, y, vx, vy, age;
  _DeathSpark(this.x, this.y, this.vx, this.vy) : age = 0;
}

class _RingFragment {
  double x, y, vx, vy, age;
  _RingFragment(this.x, this.y, this.vx, this.vy) : age = 0;
}

class _DeathShockwave {
  double age;
  _DeathShockwave() : age = 0;
}

class _Afterimage {
  double x, y, age;
  _Afterimage(this.x, this.y) : age = 0;
}

class _TimeRing {
  double age;
  _TimeRing() : age = 0;
}

class _ItemWave {
  double age;
  final Color color;
  _ItemWave(this.color) : age = 0;
}

// ── Near Miss Grade ───────────────────────────────────────────────────────────

enum NearMissGrade { close, near, superMiss, insane }

// ── Player ───────────────────────────────────────────────────────────────────

class Player extends PositionComponent
    with HasGameReference<GravityFlipGame>, CollisionCallbacks {
  bool isFlipped = false;
  bool isDead    = false;

  // Forward tilt (visual only)
  double _tiltAngle  = 0.10;
  static const double _targetTilt = 0.10;

  // Scale pulse on flip
  double _scalePulse      = 1.0;
  double _scalePulseTimer = 0;
  static const double _scalePulseDuration = 0.12;

  // Trail
  final List<_TrailDot> _trail = [];
  double _trailTimer = 0;
  static const double _trailInterval = 0.04;
  static const double _trailLifetime = 0.18;

  // Burst (on flip)
  final List<_BurstDot> _burst = [];
  static const double _burstLifetime = 0.16;

  // ── Gravity Aura ──────────────────────────────────────────────────────────
  double _auraTimer = 0;

  // ── Orbiting Dots ─────────────────────────────────────────────────────────
  double _orbitAngle = 0;
  static const double _orbitSpeed  = 2.8; // rad/s base
  static const double _orbitRadius = 22.0;
  static const int    _orbitCount  = 3;

  // ── Anti-Gravity Particles ────────────────────────────────────────────────
  final List<_AntiGravParticle> _antiGravParticles = [];
  double _antiGravTimer = 0;
  static const double _antiGravInterval = 0.10;
  static const double _antiGravLifetime = 0.90;

  // ── Flip Shockwave ────────────────────────────────────────────────────────
  final List<_Shockwave> _shockwaves = [];
  static const double _shockwaveLifetime = 0.38;

  // ── Death effects (updated with real/unscaled dt) ─────────────────────────
  double _deathRealElapsed  = 0;
  bool   _fragmentsSpawned  = false;
  final List<_DeathSpark>    _deathSparks    = [];
  final List<_RingFragment>  _ringFragments  = [];
  final List<_DeathShockwave> _deathShockwaves = [];

  static const double _deathSparkLifetime = 0.35;
  static const double _ringFragLifetime   = 0.65;
  static const double _deathShockLifetime = 0.60;
  static const double _fragSpawnDelay     = 0.12; // 0.12s after death

  // ── Slow Field: afterimages ───────────────────────────────────────────────
  final List<_Afterimage> _afterimages   = [];
  double _afterimageTimer                = 0;
  static const double _afterimageInterval = 0.055;
  static const double _afterimageLifetime = 0.22;

  // ── Slow Field: time distortion rings ─────────────────────────────────────
  final List<_TimeRing> _timeRings     = [];
  double _timeRingTimer                = 0;
  static const double _timeRingInterval = 0.28;
  static const double _timeRingLifetime = 0.55;

  // ── Item pickup waves ─────────────────────────────────────────────────────
  final List<_ItemWave> _itemWaves     = [];
  static const double _itemWaveLifetime = 0.42;

  // ── Ghost float offset ────────────────────────────────────────────────────
  double _ghostFloatY = 0.0;

  // ── Smooth gravity transition ─────────────────────────────────────────────
  double _posY            = -1.0;
  static const double _gravLerpSpeed = 14.0;

  static const double playerSize = 34;

  double _nearMissCooldown = 0.0;

  Color  get _accent => SkinManager.instance.equippedSkin.themeColor;
  String get _skinId => SkinManager.instance.equippedSkinId;

  WheelSkin? _activeSkin;
  final _rng = Random();

  Player() : super(size: Vector2.all(playerSize));

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(radius: playerSize / 2 - 4));
    _updateSkinComponent();
  }

  void _updateSkinComponent() {
    _activeSkin?.removeFromParent();
    switch (_skinId) {
      case 'classic_neon':
        _activeSkin = ClassicNeonSkin(themeColor: _accent);
        break;
      case 'dual_core':
        _activeSkin = DualCoreSkin(themeColor: _accent);
        break;
      case 'pulse_core':
        _activeSkin = PulseCoreSkin(themeColor: _accent);
        break;
      case 'black_hole_core':
        _activeSkin = BlackHoleCoreSkin(themeColor: _accent);
        break;
      case 'prism_glass':
        _activeSkin = PrismGlassSkin(themeColor: _accent);
        break;
      case 'electric_pulse':
        _activeSkin = ElectricPulseSkin(themeColor: _accent);
        break;
      case 'cyberpunk_wheel':
        _activeSkin = CyberpunkWheelSkin(themeColor: _accent);
        break;
      case 'guardian_shield':
        _activeSkin = GuardianShieldSkin(themeColor: _accent);
        break;
      default:
        _activeSkin = _skinId == 'solar_flare'
            ? DualCoreSkin(themeColor: _accent)
            : ClassicNeonSkin(themeColor: _accent);
    }
    if (_activeSkin != null) {
      _activeSkin!.size     = Vector2.all(playerSize);
      _activeSkin!.position = size / 2;
      _activeSkin!.anchor   = Anchor.center;
      add(_activeSkin!);
    }
  }

  void flip() {
    if (isDead) return;
    isFlipped = !isFlipped;
    _scalePulseTimer = _scalePulseDuration;
    _spawnBurst();
    _shockwaves.add(_Shockwave());
    _activeSkin?.triggerGravityFlip();
    // Anti.wav when entering anti-gravity, Jump.wav when returning
    if (isFlipped) {
      AudioManager.playAntiGravity();
    } else {
      AudioManager.playFlip();
    }
    game.onGravityFlip();
  }

  // Called by GravityFlipGame when an item is collected
  void triggerItemPickup(Color color) {
    _itemWaves.add(_ItemWave(color));
    _itemWaves.add(_ItemWave(color)); // double wave for impact
    _spawnBurst();
    _shockwaves.add(_Shockwave());
  }

  /// 광고 시청 후 부활: 플레이어 상태와 이펙트를 초기화합니다.
  void revive(double screenH) {
    isDead            = false;
    isFlipped         = false;
    _posY             = screenH - playerSize - 8.0;
    position.y        = _posY;
    _deathRealElapsed = 0;
    _fragmentsSpawned = false;
    _deathSparks.clear();
    _ringFragments.clear();
    _deathShockwaves.clear();
    _afterimages.clear();
    _timeRings.clear();
    _itemWaves.clear();
    _burst.clear();
    _shockwaves.clear();
    _tiltAngle       = 0.10;
    _scalePulse      = 1.0;
    _scalePulseTimer = 0;
  }

  void triggerMilestoneRush() {
    _spawnBurst();
    _shockwaves.add(_Shockwave());
    _activeSkin?.triggerGravityFlip();
  }

  void _spawnBurst() {
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;
    for (int i = 0; i < 8; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final s = 50 + _rng.nextDouble() * 55;
      _burst.add(_BurstDot(cx, cy, cos(a) * s, sin(a) * s));
    }
  }

  @override
  void update(double dt) {
    if (isDead) return;
    if (_nearMissCooldown > 0) _nearMissCooldown -= dt;

    final screenH    = game.size.y;
    final zoom       = game.scoreSystem.score >= 1000 ? 1.02 : 1.0;
    final zoomOffset = (screenH / 2) * (zoom - 1.0);
    const verticalPad = 8.0;

    final targetY = isFlipped
        ? zoomOffset + verticalPad
        : screenH - playerSize - zoomOffset - verticalPad;

    if (_posY < 0) _posY = targetY;
    _posY += (targetY - _posY) * (_gravLerpSpeed * dt).clamp(0.0, 1.0);
    position.y = _posY;

    _activeSkin?.setSpeed(game.difficultyManager.speed);

    // Tilt
    final targetTilt = isFlipped ? -_targetTilt : _targetTilt;
    _tiltAngle += (targetTilt - _tiltAngle) * dt * 14;

    // Scale pulse
    if (_scalePulseTimer > 0) {
      _scalePulseTimer = (_scalePulseTimer - dt).clamp(0.0, _scalePulseDuration);
      _scalePulse = 1.0 + 0.08 * sin((_scalePulseTimer / _scalePulseDuration) * pi);
    } else {
      _scalePulse = 1.0;
    }

    for (final child in children.whereType<WheelSkin>()) {
      child.scale = Vector2.all(_scalePulse);
      child.angle = _tiltAngle;
    }

    // ── Aura timer ────────────────────────────────────────────────────────
    _auraTimer += dt;

    // ── Orbit angle: speed scales with game speed ────────────────────────
    final speedFactor = (game.difficultyManager.speed / 300.0).clamp(3.0, 13.5);
    final orbitDir    = isFlipped ? -1.0 : 1.0;
    _orbitAngle += dt * _orbitSpeed * speedFactor * orbitDir;

    // ── Anti-gravity particles (only when flipped) ────────────────────────
    if (isFlipped) {
      _antiGravTimer += dt;
      if (_antiGravTimer >= _antiGravInterval) {
        _antiGravTimer = 0;
        final cx = position.x + playerSize / 2;
        final cy = position.y + playerSize / 2;
        final vx = (_rng.nextDouble() - 0.5) * 14;
        _antiGravParticles.add(_AntiGravParticle(
          cx + (_rng.nextDouble() - 0.5) * 10,
          cy + (_rng.nextDouble() - 0.5) * 8,
          vx, -34,
        ));
      }
    } else {
      _antiGravTimer = 0;
    }
    for (final p in _antiGravParticles) {
      p.x  += p.vx * dt;
      p.y  += p.vy * dt;
      p.age += dt;
    }
    _antiGravParticles.removeWhere((p) => p.age >= _antiGravLifetime);

    // ── Shockwaves ────────────────────────────────────────────────────────
    for (final s in _shockwaves) { s.age += dt; }
    _shockwaves.removeWhere((s) => s.age >= _shockwaveLifetime);

    // ── Trail & Burst ─────────────────────────────────────────────────────
    _trailTimer += dt;
    if (_trailTimer >= _trailInterval) {
      _trailTimer = 0;
      _trail.add(_TrailDot(position.x + playerSize / 2, position.y + playerSize / 2));
    }
    for (final d in _trail)  { d.age += dt; }
    _trail.removeWhere((d) => d.age >= _trailLifetime);

    for (final b in _burst) {
      b.x  += b.vx * dt;
      b.y  += b.vy * dt;
      b.age += dt;
    }
    _burst.removeWhere((b) => b.age >= _burstLifetime);

    // ── Slow Field: afterimages ───────────────────────────────────────────
    if (game.slowFieldActive) {
      _afterimageTimer += dt;
      if (_afterimageTimer >= _afterimageInterval) {
        _afterimageTimer = 0;
        _afterimages.add(_Afterimage(position.x, position.y));
      }
    } else {
      _afterimages.clear();
      _afterimageTimer = 0;
    }
    for (final a in _afterimages) { a.age += dt; }
    _afterimages.removeWhere((a) => a.age >= _afterimageLifetime);

    // ── Slow Field: time distortion rings ─────────────────────────────────
    if (game.slowFieldActive) {
      _timeRingTimer += dt;
      if (_timeRingTimer >= _timeRingInterval) {
        _timeRingTimer = 0;
        _timeRings.add(_TimeRing());
      }
    } else {
      _timeRings.clear();
      _timeRingTimer = 0;
    }
    for (final r in _timeRings) { r.age += dt; }
    _timeRings.removeWhere((r) => r.age >= _timeRingLifetime);

    // ── Item pickup waves ─────────────────────────────────────────────────
    for (final w in _itemWaves) { w.age += dt; }
    _itemWaves.removeWhere((w) => w.age >= _itemWaveLifetime);

    // ── Ghost float ───────────────────────────────────────────────────────
    _ghostFloatY = game.ghostModeActive ? sin(_auraTimer * 7.5) * 3.5 : 0.0;

    _checkNearMiss();
  }

  // ── Death effect spawners ─────────────────────────────────────────────────

  void triggerDeathEffects() {
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;
    // Electric sparks — random directions, fast
    for (int i = 0; i < 20; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final s = 120.0 + _rng.nextDouble() * 200;
      _deathSparks.add(_DeathSpark(cx, cy, cos(a) * s, sin(a) * s));
    }
    // Immediate death shockwave
    _deathShockwaves.add(_DeathShockwave());
  }

  void _spawnRingFragments() {
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;
    // 20 fragments evenly + randomly distributed around ring
    for (int i = 0; i < 20; i++) {
      final a = i * (2 * pi / 20) + _rng.nextDouble() * 0.3;
      final s = 90.0 + _rng.nextDouble() * 130;
      _ringFragments.add(_RingFragment(cx, cy, cos(a) * s, sin(a) * s));
    }
    // Second larger shockwave at fragment spawn
    _deathShockwaves.add(_DeathShockwave());
  }

  /// Called by GravityFlipGame with UNSCALED dt so effects run at real speed.
  void updateDeathEffects(double realDt) {
    _deathRealElapsed += realDt;

    // Spawn ring fragments 0.12s after death
    if (!_fragmentsSpawned && _deathRealElapsed >= _fragSpawnDelay) {
      _fragmentsSpawned = true;
      _spawnRingFragments();
    }

    // Sparks
    for (final s in _deathSparks) {
      s.x += s.vx * realDt;
      s.y += s.vy * realDt;
      s.vx *= 1 - 8 * realDt; // drag
      s.vy *= 1 - 8 * realDt;
      s.age += realDt;
    }
    _deathSparks.removeWhere((s) => s.age >= _deathSparkLifetime);

    // Ring fragments
    for (final f in _ringFragments) {
      f.vx *= 1 - 6 * realDt; // drag
      f.vy *= 1 - 6 * realDt;
      f.x += f.vx * realDt;
      f.y += f.vy * realDt;
      f.age += realDt;
    }
    _ringFragments.removeWhere((f) => f.age >= _ringFragLifetime);

    // Death shockwaves
    for (final s in _deathShockwaves) { s.age += realDt; }
    _deathShockwaves.removeWhere((s) => s.age >= _deathShockLifetime);
  }

  void _checkNearMiss() {
    final ghostActive     = game.ghostModeActive;
    final precisionActive = game.precisionCoreActive;

    for (final obs in game.children.whereType<Obstacle>()) {
      if (obs.passed || obs.nearMissChecked) continue;
      if (obs.position.x + obs.size.x < position.x) {
        obs.passed      = true;
        obs.nearMissChecked = true;

        if (_nearMissCooldown > 0) continue;

        // Ghost mode: auto near miss for every obstacle passed
        if (ghostActive) {
          _nearMissCooldown = 0.15;
          game.scoreSystem.registerNearMiss();
          game.onNearMiss(NearMissGrade.near);
          game.spawner.addNearMissBonus(25.0);
          continue;
        }

        // 플레이어가 장애물과 반대 면일 때만 near miss 가능
        final playerOnFloor = !isFlipped;
        final obsOnFloor    = obs.side == ObstacleSide.bottom;
        if (playerOnFloor == obsOnFloor) continue;

        final maxH       = game.difficultyManager.maxObstacleHeight;
        final effectiveH = obs.isSlim ? obs.obstacleHeight * 0.75 : obs.obstacleHeight;
        final ratio      = (effectiveH / maxH).clamp(0.0, 1.0);

        // Precision Core: wider near-miss window (0.62 vs 0.72)
        final threshold = precisionActive ? 0.62 : 0.72;

        if (ratio >= threshold) {
          final NearMissGrade grade;
          if (ratio >= 0.92)      { grade = NearMissGrade.insane; }
          else if (ratio >= 0.83) { grade = NearMissGrade.superMiss; }
          else if (ratio >= 0.77) { grade = NearMissGrade.near; }
          else                    { grade = NearMissGrade.close; }
          _nearMissCooldown = 0.15;
          game.scoreSystem.registerNearMiss();
          game.onNearMiss(grade);
          game.spawner.addNearMissBonus(25.0);
        }
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Obstacle && !isDead) {
      if (game.shieldActive)           { game.absorbShieldHit(); return; }
      if (game.itemSecondChanceActive) { game.absorbItemShield(); return; }
      if (game.ghostModeActive)        return; // ghost: pass through
      isDead = true;
      triggerDeathEffects();
      game.onPlayerDeath();
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────
  // Order: afterimage → time rings → shockwave → aura → anti-grav → trail → [skin]
  @override
  void render(Canvas canvas) {
    _renderAfterimages(canvas);
    _renderTimeRings(canvas);
    _renderShockwaves(canvas);
    _renderAura(canvas);
    _renderAntiGravParticles(canvas);
    _renderTrail(canvas);
    // skin child component renders itself automatically via Flame
  }

  @override
  void renderTree(Canvas canvas) {
    if (isDead) {
      _renderDeathSparks(canvas);
      _renderRingFragments(canvas);
      _renderDeathShockwaves(canvas);
      return;
    }
    if (game.ghostModeActive) {
      // Semi-transparent flicker + float
      final alpha = 0.35 + 0.25 * sin(_auraTimer * 11.0);
      final rect  = Rect.fromLTWH(
        position.x - 30, position.y - 30 + _ghostFloatY,
        playerSize + 60, playerSize + 60,
      );
      canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: alpha));
      canvas.translate(0, _ghostFloatY);
      super.renderTree(canvas);
      canvas.translate(0, -_ghostFloatY);
      canvas.restore();
      _renderOrbitDots(canvas);
      _renderBurst(canvas);
      _renderGhostRing(canvas);
      _renderGhostGlitch(canvas);
    } else {
      super.renderTree(canvas);
      _renderOrbitDots(canvas);
      _renderBurst(canvas);
    }
    _renderItemWaves(canvas);
  }

  // Ghost mode: purple ring with float
  void _renderGhostRing(Canvas canvas) {
    final cx    = position.x + playerSize / 2;
    final cy    = position.y + playerSize / 2 + _ghostFloatY;
    final pulse = 0.20 + 0.18 * sin(_auraTimer * 9.0);
    canvas.drawCircle(
      Offset(cx, cy),
      playerSize * 0.82,
      Paint()
        ..color       = const Color(0xFF9B30FF).withValues(alpha: pulse)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // Ghost mode: glitch scanlines
  void _renderGhostGlitch(Canvas canvas) {
    final cx   = position.x + playerSize / 2;
    final cy   = position.y + playerSize / 2 + _ghostFloatY;
    final seed = DateTime.now().millisecondsSinceEpoch ~/ 75;
    final rng  = Random(seed * 31 + 7);
    if (rng.nextDouble() > 0.38) {
      final yo    = (rng.nextDouble() - 0.5) * playerSize;
      final shift = (rng.nextDouble() - 0.5) * 10.0;
      canvas.drawLine(
        Offset(cx - 14 + shift, cy + yo),
        Offset(cx + 14 + shift, cy + yo),
        Paint()
          ..color       = const Color(0xFF9B30FF).withValues(alpha: 0.55)
          ..strokeWidth = 1.2,
      );
      // Cyan counter-shift
      canvas.drawLine(
        Offset(cx - 10 - shift * 0.5, cy + yo + 2),
        Offset(cx + 10 - shift * 0.5, cy + yo + 2),
        Paint()
          ..color       = const Color(0xFF00E5FF).withValues(alpha: 0.30)
          ..strokeWidth = 0.8,
      );
    }
  }

  // Item pickup: expanding colored ring (world space)
  void _renderItemWaves(Canvas canvas) {
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;
    for (final w in _itemWaves) {
      final t = w.age / _itemWaveLifetime;
      final r = playerSize * 0.5 + t * playerSize * 3.2;
      final a = (1.0 - t) * 0.85;
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color       = w.color.withValues(alpha: a)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1.0 - t * 0.80)
          ..maskFilter  = MaskFilter.blur(BlurStyle.normal, (1.0 - t) * 4),
      );
    }
  }

  // ── Gravity Aura ──────────────────────────────────────────────────────────
  void _renderAura(Canvas canvas) {
    final cx    = playerSize / 2;
    final cy    = playerSize / 2;
    final pulse = 1.0 + sin(_auraTimer * 2.0) * 0.07;
    final r     = playerSize * 0.72 * pulse;

    // Normal gravity: skin-colored cyan glow; anti-gravity: purple glow
    final auraColor = isFlipped ? const Color(0xFF9B30FF) : _accent;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color      = auraColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  // ── Orbiting Dots ─────────────────────────────────────────────────────────
  // Called after renderTree so dots appear on top of the skin.
  void _renderOrbitDots(Canvas canvas) {
    // renderTree gives us the PARENT canvas (game world space).
    // We need to manually offset by position since we're outside normal render().
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;

    for (int i = 0; i < _orbitCount; i++) {
      final a   = _orbitAngle + i * (2 * pi / _orbitCount);
      final dx  = cos(a) * _orbitRadius;
      final dy  = sin(a) * _orbitRadius;
      final dot = Offset(cx + dx, cy + dy);

      // Glow
      canvas.drawCircle(dot, 4.0,
          Paint()
            ..color      = _accent.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Core
      canvas.drawCircle(dot, 2.2,
          Paint()..color = _accent.withValues(alpha: 0.85));
    }
  }

  // ── Anti-Gravity Particles ────────────────────────────────────────────────
  void _renderAntiGravParticles(Canvas canvas) {
    const purple = Color(0xFF9B30FF);
    for (final p in _antiGravParticles) {
      final progress = p.age / _antiGravLifetime;
      final alpha    = (1.0 - progress) * 0.88;
      final r        = 6.0 * (1.0 - progress * 0.50);
      final dx = p.x - position.x;
      final dy = p.y - position.y;
      // Glow
      canvas.drawCircle(Offset(dx, dy), r + 3,
          Paint()
            ..color      = purple.withValues(alpha: alpha * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      // Core
      canvas.drawCircle(Offset(dx, dy), r,
          Paint()..color = purple.withValues(alpha: alpha));
    }
  }

  // ── Flip Shockwave ────────────────────────────────────────────────────────
  void _renderShockwaves(Canvas canvas) {
    final cx = playerSize / 2;
    final cy = playerSize / 2;
    for (final s in _shockwaves) {
      final t     = s.age / _shockwaveLifetime;
      final r     = playerSize * 0.5 + t * playerSize * 1.8;
      final alpha = (1.0 - t) * 0.75;
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color       = _accent.withValues(alpha: alpha)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1.0 - t * 0.6),
      );
    }
  }

  // ── Death Sparks (electric) ────────────────────────────────────────────────
  void _renderDeathSparks(Canvas canvas) {
    for (final s in _deathSparks) {
      final t     = s.age / _deathSparkLifetime;
      final alpha = (1.0 - t) * 0.95;
      final r     = 2.8 * (1.0 - t * 0.5);
      final ox = s.x;
      final oy = s.y;
      // Glow
      canvas.drawCircle(Offset(ox, oy), r + 4,
          Paint()
            ..color      = const Color(0xFF00E5FF).withValues(alpha: alpha * 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // Core
      canvas.drawCircle(Offset(ox, oy), r,
          Paint()..color = Colors.white.withValues(alpha: alpha));
    }
  }

  // ── Ring Fragments ────────────────────────────────────────────────────────
  void _renderRingFragments(Canvas canvas) {
    for (final f in _ringFragments) {
      final t     = f.age / _ringFragLifetime;
      final alpha = (1.0 - t) * 0.90;
      final len   = 6.0 * (1.0 - t * 0.6);
      final ox = f.x;
      final oy = f.y;
      // Direction of travel
      final speed = sqrt(f.vx * f.vx + f.vy * f.vy).clamp(1.0, 999.0);
      final nx = f.vx / speed;
      final ny = f.vy / speed;
      canvas.drawLine(
        Offset(ox - nx * len, oy - ny * len),
        Offset(ox + nx * len, oy + ny * len),
        Paint()
          ..color       = _accent.withValues(alpha: alpha)
          ..strokeWidth = 2.0
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // ── Death Shockwaves ──────────────────────────────────────────────────────
  void _renderDeathShockwaves(Canvas canvas) {
    final cx = position.x + playerSize / 2;
    final cy = position.y + playerSize / 2;
    for (final s in _deathShockwaves) {
      final t     = s.age / _deathShockLifetime;
      final r     = playerSize * 0.5 + t * 180;
      final alpha = (1.0 - t) * 0.65;
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color       = _accent.withValues(alpha: alpha)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1.0 - t * 0.8),
      );
    }
  }

  // ── Slow Field: afterimages ───────────────────────────────────────────────
  void _renderAfterimages(Canvas canvas) {
    for (int i = 0; i < _afterimages.length; i++) {
      final a     = _afterimages[i];
      final t     = a.age / _afterimageLifetime;
      final alpha = (1.0 - t) * (0.42 - i * 0.10).clamp(0.05, 0.42);
      final ox    = a.x - position.x + playerSize / 2;
      final oy    = a.y - position.y + playerSize / 2;
      // Glow blob
      canvas.drawCircle(Offset(ox, oy), playerSize * 0.52,
          Paint()
            ..color      = const Color(0xFF00E5FF).withValues(alpha: alpha * 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      // Ring outline
      canvas.drawCircle(Offset(ox, oy), playerSize * 0.44,
          Paint()
            ..color       = const Color(0xFF00E5FF).withValues(alpha: alpha)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }
  }

  // ── Slow Field: time distortion rings ─────────────────────────────────────
  void _renderTimeRings(Canvas canvas) {
    final cx = playerSize / 2;
    final cy = playerSize / 2;
    for (final ring in _timeRings) {
      final t = ring.age / _timeRingLifetime;
      final r = playerSize * 0.28 + t * playerSize * 2.0;
      final a = (1.0 - t) * 0.55;
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()
            ..color       = const Color(0xFF00E5FF).withValues(alpha: a)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.2 * (1.0 - t * 0.65));
    }
  }

  // ── Trail ─────────────────────────────────────────────────────────────────
  void _renderTrail(Canvas canvas) {
    final insane = !isDead && game.scoreSystem.score >= 8000;
    for (final dot in _trail) {
      final progress = dot.age / _trailLifetime;
      final alpha    = (1 - progress) * (insane ? 0.70 : 0.40);
      final r        = (insane ? 3.5 : 2.2) * (1 - progress * 0.50);
      if (insane) {
        canvas.drawCircle(
          Offset(dot.x - position.x, dot.y - position.y), r + 4,
          Paint()
            ..color      = _accent.withValues(alpha: alpha * 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(
        Offset(dot.x - position.x, dot.y - position.y), r,
        Paint()..color = _accent.withValues(alpha: alpha),
      );
    }
  }

  // ── Burst ─────────────────────────────────────────────────────────────────
  void _renderBurst(Canvas canvas) {
    // canvas here is the PARENT game world canvas (from renderTree override)
    for (final b in _burst) {
      final progress = b.age / _burstLifetime;
      final alpha    = (1 - progress) * 0.65;
      final r        = 2.5 * (1 - progress * 0.45);
      canvas.drawCircle(
        Offset(b.x, b.y),
        r,
        Paint()..color = _accent.withValues(alpha: alpha),
      );
    }
  }
}
