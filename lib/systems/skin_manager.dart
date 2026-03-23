import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Rarity system ────────────────────────────────────────────────────────────

enum SkinRarity {
  common(Color(0xFF4FC3F7), 'COMMON'),
  rare(Color(0xFFAB47BC), 'RARE'),
  epic(Color(0xFFEC407A), 'EPIC'),
  legendary(Color(0xFFFFD700), 'LEGENDARY');

  final Color color;
  final String label;
  const SkinRarity(this.color, this.label);
}

// ── Skin data model ──────────────────────────────────────────────────────────

class CharacterSkin {
  final String id;
  final String name;
  final Color themeColor;
  final int price;
  final SkinRarity rarity;
  final String effectName;
  bool isUnlocked;

  CharacterSkin({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.price,
    required this.rarity,
    required this.effectName,
    this.isUnlocked = false,
  });
}

// ── Daily Deal ───────────────────────────────────────────────────────────────

class DailyDeal {
  final String skinId;
  final int originalPrice;
  final int discountedPrice;
  final DateTime expiresAt;

  DailyDeal({
    required this.skinId,
    required this.originalPrice,
    required this.discountedPrice,
    required this.expiresAt,
  });

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
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
      rarity: SkinRarity.common,
      effectName: '4-Spoke Wheel',
      isUnlocked: true,
    ),
    CharacterSkin(
      id: 'dual_core',
      name: 'Dual Core',
      themeColor: const Color(0xFF00E5FF),
      price: 18000,
      rarity: SkinRarity.common,
      effectName: 'Twin Pulse Rings',
    ),
    CharacterSkin(
      id: 'solar_flare',
      name: 'Solar Flare',
      themeColor: const Color(0xFFFF8C00),
      price: 12000,
      rarity: SkinRarity.common,
      effectName: 'Radiant Corona',
    ),
    CharacterSkin(
      id: 'pulse_core',
      name: 'Pulse Core',
      themeColor: const Color(0xFFFFEA00),
      price: 40000,
      rarity: SkinRarity.rare,
      effectName: 'Rhythmic Pulse',
    ),
    CharacterSkin(
      id: 'black_hole_core',
      name: 'Black Hole Core',
      themeColor: const Color(0xFF9B30FF),
      price: 60000,
      rarity: SkinRarity.rare,
      effectName: 'Accretion Spiral',
    ),
    CharacterSkin(
      id: 'phantom_ring',
      name: 'Phantom Ring',
      themeColor: const Color(0xFF00BFA5),
      price: 50000,
      rarity: SkinRarity.rare,
      effectName: 'Ghost Echoes',
    ),
    CharacterSkin(
      id: 'prism_glass',
      name: 'Prism Glass',
      themeColor: const Color(0xFFB8F0FF),
      price: 100000,
      rarity: SkinRarity.epic,
      effectName: 'Rainbow Refraction',
    ),
    CharacterSkin(
      id: 'electric_pulse',
      name: 'Electric Pulse',
      themeColor: const Color(0xFF00FFFF),
      price: 140000,
      rarity: SkinRarity.epic,
      effectName: 'Lightning Arcs',
    ),
    CharacterSkin(
      id: 'nova_burst',
      name: 'Nova Burst',
      themeColor: const Color(0xFFFF4081),
      price: 120000,
      rarity: SkinRarity.epic,
      effectName: 'Star Explosion',
    ),
    CharacterSkin(
      id: 'cyberpunk_wheel',
      name: 'Cyberpunk Wheel',
      themeColor: const Color(0xFF00FF41),
      price: 240000,
      rarity: SkinRarity.legendary,
      effectName: 'Binary Code Flow',
    ),
    CharacterSkin(
      id: 'guardian_shield',
      name: 'Guardian Shield',
      themeColor: const Color(0xFFFFD700),
      price: 320000,
      rarity: SkinRarity.legendary,
      effectName: 'Orbital Shields',
    ),
    CharacterSkin(
      id: 'void_walker',
      name: 'Void Walker',
      themeColor: const Color(0xFFE040FB),
      price: 400000,
      rarity: SkinRarity.legendary,
      effectName: 'Dimensional Rift',
    ),
  ];

  // ── Runtime state ─────────────────────────────────────────────────────────
  int _gravityPoints = 0;
  String _equippedSkinId = 'classic_neon';
  DailyDeal? _dailyDeal;

  // Consecutive run counter (in-memory; resets on app restart)
  int _consecutiveRuns = 0;

  int get gravityPoints => _gravityPoints;
  String get equippedSkinId => _equippedSkinId;
  DailyDeal? get dailyDeal => _dailyDeal;

  CharacterSkin get equippedSkin =>
      skins.firstWhere((s) => s.id == _equippedSkinId, orElse: () => skins[0]);

  // ── Persistence ───────────────────────────────────────────────────────────
  static const _keyGP        = 'gravity_points';
  static const _keyEquipped  = 'equipped_skin';
  static const _keyUnlocked  = 'unlocked_skins';
  static const _keyDealDate  = 'daily_deal_date';
  static const _keyDealSkin  = 'daily_deal_skin';

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

    // Load or generate daily deal
    _loadOrGenerateDailyDeal(prefs);
  }

  void _loadOrGenerateDailyDeal(SharedPreferences prefs) {
    final today = _todayString();
    final savedDate = prefs.getString(_keyDealDate);
    final savedSkin = prefs.getString(_keyDealSkin);

    if (savedDate == today && savedSkin != null) {
      // Existing deal for today
      final skin = skins.firstWhere(
        (s) => s.id == savedSkin,
        orElse: () => skins[1],
      );
      if (!skin.isUnlocked) {
        final tomorrow = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day + 1,
        );
        _dailyDeal = DailyDeal(
          skinId: skin.id,
          originalPrice: skin.price,
          discountedPrice: (skin.price * 0.6).round(),
          expiresAt: tomorrow,
        );
      } else {
        _dailyDeal = null;
      }
    } else {
      // Generate new deal
      _generateNewDeal(prefs);
    }
  }

  void _generateNewDeal(SharedPreferences prefs) {
    final lockedSkins = skins.where((s) => !s.isUnlocked).toList();
    if (lockedSkins.isEmpty) {
      _dailyDeal = null;
      return;
    }

    final rng = Random();
    final skin = lockedSkins[rng.nextInt(lockedSkins.length)];
    final tomorrow = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day + 1,
    );

    _dailyDeal = DailyDeal(
      skinId: skin.id,
      originalPrice: skin.price,
      discountedPrice: (skin.price * 0.6).round(),
      expiresAt: tomorrow,
    );

    prefs.setString(_keyDealDate, _todayString());
    prefs.setString(_keyDealSkin, skin.id);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get the effective price for a skin (accounts for daily deal discount).
  int effectivePrice(String skinId) {
    if (_dailyDeal != null &&
        _dailyDeal!.skinId == skinId &&
        !_dailyDeal!.isExpired) {
      return _dailyDeal!.discountedPrice;
    }
    final skin = skins.firstWhere((s) => s.id == skinId, orElse: () => skins[0]);
    return skin.price;
  }

  bool isDailyDeal(String skinId) {
    return _dailyDeal != null &&
        _dailyDeal!.skinId == skinId &&
        !_dailyDeal!.isExpired;
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

    _gravityPoints += raw; // .clamp(1, 500);
    await _save();
  }

  // ── Purchase ─────────────────────────────────────────────────────────────
  /// Returns true if purchase succeeded. Uses daily deal price if applicable.
  Future<bool> buySkin(String id) async {
    final skin = skins.firstWhere((s) => s.id == id, orElse: () => skins[0]);
    if (skin.isUnlocked) return false;
    final price = effectivePrice(id);
    if (_gravityPoints < price) return false;
    _gravityPoints -= price;
    skin.isUnlocked = true;

    // Clear daily deal if this skin was the deal
    if (_dailyDeal != null && _dailyDeal!.skinId == id) {
      _dailyDeal = null;
    }

    await _save();
    return true;
  }

  // ── Free unlock (광고 보상) ───────────────────────────────────────────────
  Future<void> unlockSkinFree(String id) async {
    final skin = skins.firstWhere((s) => s.id == id, orElse: () => skins[0]);
    if (skin.isUnlocked) return;
    skin.isUnlocked = true;
    await _save();
  }

  // ── Equip ─────────────────────────────────────────────────────────────────
  Future<void> equipSkin(String id) async {
    final skin = skins.firstWhere((s) => s.id == id, orElse: () => skins[0]);
    if (!skin.isUnlocked) return;
    _equippedSkinId = id;
    await _save();
  }
}
