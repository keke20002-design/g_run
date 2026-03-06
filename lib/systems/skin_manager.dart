import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Skin data model ──────────────────────────────────────────────────────────

class CharacterSkin {
  final String id;
  final String name;
  final Color themeColor;
  final int price;
  bool isUnlocked;

  CharacterSkin({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.price,
    this.isUnlocked = false,
  });
}

// ── SkinManager singleton ────────────────────────────────────────────────────

class SkinManager {
  SkinManager._internal();
  static final SkinManager instance = SkinManager._internal();

  // ── All available skins (order = display order) ──────────────────────────
  final List<CharacterSkin> skins = [
    CharacterSkin(
      id: 'classic_neon',
      name: 'Classic Neon',
      themeColor: const Color(0xFF00E5FF),
      price: 0,
      isUnlocked: true,
    ),
    CharacterSkin(
      id: 'dual_core',
      name: 'Dual Core',
      themeColor: const Color(0xFF00E5FF),
      price: 800,
    ),
    CharacterSkin(
      id: 'pulse_core',
      name: 'Pulse Core',
      themeColor: const Color(0xFFFFEA00),
      price: 2500,
    ),
    CharacterSkin(
      id: 'black_hole_core',
      name: 'Black Hole Core',
      themeColor: const Color(0xFF9B30FF),
      price: 6000,
    ),
    CharacterSkin(
      id: 'prism_glass',
      name: 'Prism Glass',
      themeColor: const Color(0xFFB8F0FF),
      price: 8000,
    ),
    CharacterSkin(
      id: 'electric_pulse',
      name: 'Electric Pulse',
      themeColor: const Color(0xFF00FFFF),
      price: 10000,
    ),
    CharacterSkin(
      id: 'cyberpunk_wheel',
      name: 'Cyberpunk Wheel',
      themeColor: const Color(0xFF00FF41),
      price: 12000,
    ),
    CharacterSkin(
      id: 'guardian_shield',
      name: 'Guardian Shield',
      themeColor: const Color(0xFFFFD700),
      price: 15000,
    ),
  ];

  // ── Runtime state ─────────────────────────────────────────────────────────
  int _gravityPoints = 0;
  String _equippedSkinId = 'classic_neon';

  // Consecutive run counter (in-memory; resets on app restart)
  int _consecutiveRuns = 0;

  int get gravityPoints => _gravityPoints;
  String get equippedSkinId => _equippedSkinId;

  CharacterSkin get equippedSkin =>
      skins.firstWhere((s) => s.id == _equippedSkinId, orElse: () => skins[0]);

  // ── Persistence ───────────────────────────────────────────────────────────
  static const _keyGP       = 'gravity_points';
  static const _keyEquipped = 'equipped_skin';
  static const _keyUnlocked = 'unlocked_skins';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _gravityPoints  = prefs.getInt(_keyGP) ?? 0;
    _equippedSkinId = prefs.getString(_keyEquipped) ?? 'classic_neon';

    final unlocked = prefs.getStringList(_keyUnlocked) ?? ['classic_neon'];
    for (final skin in skins) {
      skin.isUnlocked = unlocked.contains(skin.id);
    }
    // classic neon is always free
    skins[0].isUnlocked = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGP, _gravityPoints);
    await prefs.setString(_keyEquipped, _equippedSkinId);
    await prefs.setStringList(
      _keyUnlocked,
      skins.where((s) => s.isUnlocked).map((s) => s.id).toList(),
    );
  }

  // ── GP earning ────────────────────────────────────────────────────────────
  /// Called after each run.
  /// Formula (section 8):
  ///   baseGP             = max(1, score ÷ 100)
  ///   comboBonus         = maxCombo × 2
  ///   difficultyBonus    = baseGP × difficultyMultiplier
  ///   bestBonus          = score ÷ 50  (only when new best)
  ///   consecutiveBonus   = ×1.2 at 3 runs, ×1.4 at 5+ runs
  ///   finalGP            = clamp(sum × consecutiveBonus, 1, 500)
  Future<void> earnPoints({
    required int score,
    required int maxCombo,
    required double difficultyMultiplier,
    required bool isNewBest,
  }) async {
    if (score <= 0) return;

    _consecutiveRuns++;

    final baseGP       = (score ~/ 100).clamp(1, 9999);
    final comboBonus   = maxCombo * 2;
    final diffBonus    = (baseGP * difficultyMultiplier).toInt();
    final bestBonus    = isNewBest ? (score ~/ 50) : 0;

    int raw = baseGP + comboBonus + diffBonus + bestBonus;

    // Consecutive play multiplier
    if (_consecutiveRuns >= 5) {
      raw = (raw * 1.4).toInt();
    } else if (_consecutiveRuns >= 3) {
      raw = (raw * 1.2).toInt();
    }

    _gravityPoints += raw.clamp(1, 500);
    await _save();
  }

  // ── Purchase ─────────────────────────────────────────────────────────────
  /// Returns true if purchase succeeded.
  Future<bool> buySkin(String id) async {
    final skin = skins.firstWhere((s) => s.id == id, orElse: () => skins[0]);
    if (skin.isUnlocked) return false;
    if (_gravityPoints < skin.price) return false;
    _gravityPoints -= skin.price;
    skin.isUnlocked = true;
    await _save();
    return true;
  }

  // ── Equip ─────────────────────────────────────────────────────────────────
  Future<void> equipSkin(String id) async {
    final skin = skins.firstWhere((s) => s.id == id, orElse: () => skins[0]);
    if (!skin.isUnlocked) return;
    _equippedSkinId = id;
    await _save();
  }
}
