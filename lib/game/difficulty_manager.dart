class DifficultyManager {
  double elapsedTime = 0;
  int    _score      = 0;

  // ── Speed: score-based stages ─────────────────────────────────────────────
  double get speed {
    if (_score < 2000)  return 190;
    if (_score < 5000)  return 240;
    if (_score < 8000)  return 300;
    if (_score < 12000) return 360;
    if (_score < 18000) return 420;
    return 480;
  }

  double get minGap {
    if (_score < 2000)  return 520;
    if (_score < 5000)  return 440;
    if (_score < 8000)  return 360;
    if (_score < 12000) return 300;
    if (_score < 18000) return 250;
    return 200;
  }

  double get maxObstacleHeight {
    if (_score < 2000)  return 60;
    if (_score < 5000)  return 80;
    if (_score < 10000) return 100;
    if (_score < 16000) return 130;
    return 160;
  }

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
  }
}
