import 'package:shared_preferences/shared_preferences.dart';
import 'skin_manager.dart';

class ScoreSystem {
  double _distance = 0;
  double _multiplier = 1.0;
  int _combo = 0;
  int _maxCombo = 0;
  int _bestScore = 0;
  bool _newBest = false;

  int get score => (_distance * _multiplier).toInt();
  int get bestScore => _bestScore;
  double get multiplier => _multiplier;
  int get combo => _combo;
  int get maxCombo => _maxCombo;
  bool get isNewBest => _newBest;

  Future<void> loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScore = prefs.getInt('best_score') ?? 0;
  }

  /// 현재 런에서 얻을 GP 추산 (저장 없음 — HUD 실시간 표시용)
  int liveGPEarned(double difficultyMultiplier) {
    if (score <= 0) return 0;
    final baseGP     = (score ~/ 100).clamp(1, 9999);
    final comboBonus = _maxCombo * 2;
    final diffBonus  = (baseGP * difficultyMultiplier).toInt();
    return (baseGP + comboBonus + diffBonus).clamp(1, 500);
  }

  Future<void> saveBest(double difficultyMultiplier) async {
    bool newBest = false;
    if (score > _bestScore) {
      _bestScore = score;
      _newBest = true;
      newBest = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('best_score', _bestScore);
    }
    // Always earn GP from every run, regardless of best
    await SkinManager.instance.earnPoints(
      score: score,
      maxCombo: _maxCombo,
      difficultyMultiplier: difficultyMultiplier,
      isNewBest: newBest,
    );
  }

  void update(double dt, double speed) {
    _distance += speed * dt;
  }

  // Call when player passes an obstacle within near-miss threshold
  void registerNearMiss() {
    _combo++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    _multiplier = 1.0 + (_combo * 0.2).clamp(0, 1.5);
  }

  // Call when combo is broken (player goes far from any obstacle)
  void resetCombo() {
    _combo = 0;
    _multiplier = 1.0;
  }

  void reset() {
    _distance = 0;
    _multiplier = 1.0;
    _combo = 0;
    _maxCombo = 0;
    _newBest = false;
  }
}
