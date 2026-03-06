enum DifficultyPhase { easy, medium, hard, relief }

class DifficultyManager {
  double elapsedTime = 0;
  int    _score      = 0;

  // ── Speed: score-based stages ─────────────────────────────────────────────
  DifficultyPhase get currentPhase {
    final cycleTime = elapsedTime % 80;
    if (cycleTime < 20) return DifficultyPhase.easy;
    if (cycleTime < 45) return DifficultyPhase.medium;
    if (cycleTime < 70) return DifficultyPhase.hard;
    return DifficultyPhase.relief;
  }

  // ── Speed: score-based base + phase multipliers ───────────────────────────
  double get speed {
    double baseSpeed;
    if (_score < 2000)  { baseSpeed = 170; }
    else if (_score < 5000)  { baseSpeed = 210; }
    else if (_score < 8000)  { baseSpeed = 260; }
    else if (_score < 12000) { baseSpeed = 310; }
    else if (_score < 18000) { baseSpeed = 360; }
    else { baseSpeed = 410; }

    switch (currentPhase) {
      case DifficultyPhase.easy:   return baseSpeed * 0.9;
      case DifficultyPhase.medium: return baseSpeed * 1.0;
      case DifficultyPhase.hard:   return baseSpeed * 1.08;
      case DifficultyPhase.relief: return baseSpeed * 0.85; // Notable slowdown
    }
  }

  double get minGap {
    double baseGap;
    if (_score < 2000)  { baseGap = 550; }
    else if (_score < 5000)  { baseGap = 470; }
    else if (_score < 8000)  { baseGap = 400; }
    else if (_score < 12000) { baseGap = 340; }
    else if (_score < 18000) { baseGap = 290; }
    else { baseGap = 250; }

    switch (currentPhase) {
      case DifficultyPhase.easy:   return baseGap * 1.1;
      case DifficultyPhase.medium: return baseGap * 1.0;
      case DifficultyPhase.hard:   return baseGap * 0.88;
      case DifficultyPhase.relief: return baseGap * 1.4; // Lots of breathing room
    }
  }

  double get maxObstacleHeight {
    if (_score < 2000)  return 55;
    if (_score < 5000)  return 72;
    if (_score < 10000) return 90;
    if (_score < 16000) return 115;
    return 140;
  }

  // ── Near Miss 게이지 ────────────────────────────────────────────────────────
  int nearMissGaugeCount = 0; // 0~5
  bool get gaugeReady => nearMissGaugeCount >= 5;

  void addNearMissGauge() {
    if (nearMissGaugeCount < 5) nearMissGaugeCount++;
  }

  void consumeGauge() { nearMissGaugeCount = 0; }

  double get difficultyMultiplier {
    if (_score < 1000)  return 1.0;
    if (_score < 5000)  return 1.2;
    if (_score < 10000) return 1.5;
    return 2.0;
  }

  void update(double dt, int score) {
    elapsedTime += dt;
    _score = score;
  }

  void reset() {
    elapsedTime = 0;
    _score = 0;
    nearMissGaugeCount = 0;
  }
}
