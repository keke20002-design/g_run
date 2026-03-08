import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../systems/skin_manager.dart';
import 'skin_preview_painter.dart';

// ── Skin Shop Screen ──────────────────────────────────────────────────────────

class SkinShopScreen extends StatefulWidget {
  const SkinShopScreen({super.key});

  @override
  State<SkinShopScreen> createState() => _SkinShopScreenState();
}

class _SkinShopScreenState extends State<SkinShopScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  late final AnimationController _previewRotCtrl; // preview panel (6 s)
  late final AnimationController _cardRotCtrl;    // card icons    (8 s slow)
  late final AnimationController _glowCtrl;       // glow pulse    (2 s)
  late final AnimationController _gpScaleCtrl;    // GP badge pop  (0.35 s)
  late final AnimationController _gpCountCtrl;    // GP count-up   (0.8 s)

  String _selectedSkinId = SkinManager.instance.equippedSkinId;

  late int _targetGP;
  int _displayGP = 0;

  // Daily deal timer
  Timer? _dealTimer;
  String _dealTimeLeft = '';

  static const Color _bg    = Color(0xFF070B14);
  static const Color _panel = Color(0xFF0D1528);
  static const Color _cyan  = Color(0xFF00E5FF);
  static const Color _viol  = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _targetGP = SkinManager.instance.gravityPoints;

    _previewRotCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 6),
    )..repeat();

    _cardRotCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _gpScaleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350),
    );

    _gpCountCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _gpCountCtrl.addListener(() {
      setState(() => _displayGP = (_targetGP * _gpCountCtrl.value).round());
    });

    // Start daily deal countdown timer
    _startDealTimer();
  }

  void _startDealTimer() {
    _updateDealTimeLeft();
    _dealTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateDealTimeLeft();
    });
  }

  void _updateDealTimeLeft() {
    final deal = SkinManager.instance.dailyDeal;
    if (deal == null || deal.isExpired) {
      _dealTimeLeft = '';
    } else {
      final remaining = deal.timeRemaining;
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      final s = remaining.inSeconds % 60;
      _dealTimeLeft = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _previewRotCtrl.dispose();
    _cardRotCtrl.dispose();
    _glowCtrl.dispose();
    _gpScaleCtrl.dispose();
    _gpCountCtrl.dispose();
    _dealTimer?.cancel();
    super.dispose();
  }

  CharacterSkin get _selectedSkin =>
      SkinManager.instance.skins.firstWhere((s) => s.id == _selectedSkinId);

  void _selectSkin(CharacterSkin skin) {
    setState(() => _selectedSkinId = skin.id);
    if (skin.isUnlocked) _onEquip(skin);
  }

  Future<void> _onBuy(CharacterSkin skin) async {
    final ok = await SkinManager.instance.buySkin(skin.id);
    if (!ok || !mounted) return;
    await _showBurstDialog(skin);
    setState(() {
      _targetGP  = SkinManager.instance.gravityPoints;
      _displayGP = _targetGP;
    });
    _gpScaleCtrl.forward(from: 0);
  }

  Future<void> _onEquip(CharacterSkin skin) async {
    await SkinManager.instance.equipSkin(skin.id);
    setState(() {});
  }

  Future<void> _showBurstDialog(CharacterSkin skin) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, anim, anim2) =>
          _BurstOverlay(skin: skin, onComplete: () => Navigator.of(ctx).pop()),
    );
  }

  void _showTryDialog(CharacterSkin skin) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _TryPreviewDialog(
        skin: skin,
        previewRepaint: _previewRotCtrl,
        glowCtrl: _glowCtrl,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _GridPainter()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildPreviewPanel(),
                const SizedBox(height: 14),
                Expanded(child: _buildSkinGrid()),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header / GP Badge ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _cyan.withValues(alpha: 0.30), width: 1.0),
                color: _cyan.withValues(alpha: 0.04),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: _cyan, size: 15),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'SKIN SHOP',
            style: TextStyle(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.w900, letterSpacing: 6,
            ),
          ),
          const Spacer(),
          _buildGPBadge(),
        ],
      ),
    );
  }

  Widget _buildGPBadge() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowCtrl, _gpScaleCtrl]),
      builder: (ctx, child) {
        final glow  = 0.5 + _glowCtrl.value * 0.5;
        final scale = 1.0 + sin(_gpScaleCtrl.value * pi).clamp(0.0, 1.0) * 0.14;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _viol.withValues(alpha: 0.12),
              border: Border.all(color: _viol.withValues(alpha: glow * 0.60), width: 1.0),
              boxShadow: [
                BoxShadow(color: _viol.withValues(alpha: glow * 0.18),
                    blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 13, height: 13,
                  child: CustomPaint(
                    painter: _NeonRingIconPainter(color: _viol, glowT: glow),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$_displayGP GP',
                    style: const TextStyle(
                      color: _viol, fontSize: 12,
                      fontWeight: FontWeight.w800, letterSpacing: 1,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Preview Panel ─────────────────────────────────────────────────────────
  Widget _buildPreviewPanel() {
    return AnimatedBuilder(
      animation: Listenable.merge([_previewRotCtrl, _glowCtrl]),
      builder: (ctx, child) {
        final glow = 0.5 + _glowCtrl.value * 0.5;
        final skin = _selectedSkin;

        return Container(
          height: 165,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _panel,
            border: Border.all(
              color: skin.themeColor.withValues(alpha: 0.22), width: 1.0),
            boxShadow: [
              BoxShadow(color: skin.themeColor.withValues(alpha: glow * 0.10),
                  blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Row(
            children: [
              // Left: icon + dim bg rings
              SizedBox(
                width: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(148, 165),
                      painter: _BgRingPainter(color: skin.themeColor),
                    ),
                    CustomPaint(
                      size: const Size(108, 108),
                      painter: SkinPreviewPainter(
                        color: skin.themeColor,
                        glowT: glow,
                        skinId: skin.id,
                        repaint: _previewRotCtrl,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rarity badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: skin.rarity.color.withValues(alpha: 0.15),
                          border: Border.all(color: skin.rarity.color.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          skin.rarity.label,
                          style: TextStyle(
                            color: skin.rarity.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        skin.name.toUpperCase(),
                        style: TextStyle(
                          color: skin.themeColor, fontSize: 13,
                          fontWeight: FontWeight.w900, letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Effect name
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: skin.themeColor.withValues(alpha: 0.6), size: 11),
                          const SizedBox(width: 4),
                          Text(
                            skin.effectName,
                            style: TextStyle(
                              color: skin.themeColor.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildActionButton(skin),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(CharacterSkin skin) {
    final isEquipped = SkinManager.instance.equippedSkinId == skin.id;
    final isOwned    = skin.isUnlocked;
    final price      = SkinManager.instance.effectivePrice(skin.id);
    final canAfford  = SkinManager.instance.gravityPoints >= price;

    if (isEquipped) {
      return _ActionChip(label: '\u2713 EQUIPPED', color: _cyan,
          filled: true, onTap: null);
    } else if (isOwned) {
      return _ActionChip(label: 'EQUIP', color: skin.themeColor,
          filled: false, onTap: () => _onEquip(skin));
    } else if (canAfford) {
      // Show TRY + BUY row
      return Row(
        children: [
          Expanded(
            child: _ActionChip(label: 'TRY', color: skin.themeColor,
                filled: false, onTap: () => _showTryDialog(skin)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionChip(label: 'BUY  $price GP',
                color: skin.themeColor, filled: true, onTap: () => _onBuy(skin)),
          ),
        ],
      );
    } else {
      // Locked, can't afford — still show TRY
      return Row(
        children: [
          _ActionChip(label: 'TRY', color: skin.themeColor.withValues(alpha: 0.5),
              filled: false, onTap: () => _showTryDialog(skin)),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionChip(label: '$price GP',
                color: Colors.white24, filled: false, onTap: null),
          ),
        ],
      );
    }
  }

  // ── Skin Grid (2-column) ──────────────────────────────────────────────────
  Widget _buildSkinGrid() {
    final skins = SkinManager.instance.skins;
    final deal = SkinManager.instance.dailyDeal;

    return AnimatedBuilder(
      animation: _cardRotCtrl,
      builder: (ctx, child) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: skins.length,
          itemBuilder: (_, i) {
            final skin     = skins[i];
            final selected = _selectedSkinId == skin.id;
            final equipped = SkinManager.instance.equippedSkinId == skin.id;
            final isDeal   = deal != null && deal.skinId == skin.id && !deal.isExpired;
            return _SkinCard(
              skin: skin,
              isSelected: selected,
              isEquipped: equipped,
              gravityPoints: SkinManager.instance.gravityPoints,
              repaint: _cardRotCtrl,
              glowAnimation: _glowCtrl,
              isDailyDeal: isDeal,
              dealTimeLeft: isDeal ? _dealTimeLeft : null,
              onTap: () => _selectSkin(skin),
              onBuy:   () => _onBuy(skin),
              onEquip: () => _onEquip(skin),
              onTry:   () => _showTryDialog(skin),
            ).animate()
              .fadeIn(delay: (i * 55).ms, duration: 220.ms)
              .slideY(begin: 0.12, end: 0,
                  delay: (i * 55).ms, duration: 250.ms, curve: Curves.easeOut);
          },
        );
      },
    );
  }
}

// ── Action Chip ───────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.label, required this.color,
    required this.filled, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: color, width: 1.0),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: color, fontSize: 10.5,
                fontWeight: FontWeight.w800, letterSpacing: 2,
              )),
        ),
      ),
    );
  }
}

// ── Skin Card (2-col, rarity, locked overlay, daily deal) ─────────────────────

class _SkinCard extends StatelessWidget {
  final CharacterSkin skin;
  final bool isSelected;
  final bool isEquipped;
  final int gravityPoints;
  final Listenable repaint;
  final Animation<double> glowAnimation;
  final bool isDailyDeal;
  final String? dealTimeLeft;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;
  final VoidCallback? onTry;

  const _SkinCard({
    required this.skin,
    required this.isSelected,
    required this.isEquipped,
    required this.gravityPoints,
    required this.repaint,
    required this.glowAnimation,
    this.isDailyDeal = false,
    this.dealTimeLeft,
    required this.onTap,
    this.onBuy,
    this.onEquip,
    this.onTry,
  });

  @override
  Widget build(BuildContext context) {
    final owned     = skin.isUnlocked;
    final price     = SkinManager.instance.effectivePrice(skin.id);
    final canAfford = gravityPoints >= price;
    final locked    = !owned;

    // Border glow for epic/legendary or selected
    final bool glowBorder = isSelected ||
        (!locked && (skin.rarity == SkinRarity.epic || skin.rarity == SkinRarity.legendary));
    final glowColor = isSelected ? skin.themeColor : skin.rarity.color;

    final borderColor = isSelected
        ? skin.themeColor.withValues(alpha: 0.85)
        : glowBorder
            ? skin.rarity.color.withValues(alpha: 0.50)
            : skin.themeColor.withValues(alpha: locked ? 0.15 : 0.30);
    final borderWidth = isSelected ? 1.6 : (glowBorder ? 1.2 : 0.8);

    // Icon color
    final iconColor = locked
        ? skin.themeColor.withValues(alpha: 0.50)
        : (isSelected ? skin.themeColor : skin.themeColor.withValues(alpha: 0.65));

    // Icon — enlarged for 2-col layout
    Widget iconWidget = SizedBox(
      width: 42, height: 42,
      child: CustomPaint(
        painter: SkinPreviewPainter(
          color: iconColor,
          glowT: isSelected ? 0.85 : (locked ? 0.18 : 0.45),
          skinId: skin.id,
          repaint: repaint,
        ),
      ),
    );

    // Locked: desaturate + hologram overlay
    if (locked) {
      iconWidget = Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0.25, 0.60, 0.15, 0, 0,
              0.25, 0.60, 0.15, 0, 0,
              0.25, 0.60, 0.15, 0, 0,
              0,    0,    0,    0.55, 0,
            ]),
            child: iconWidget,
          ),
          // Hologram/scan line overlay
          SizedBox(
            width: 42, height: 42,
            child: AnimatedBuilder(
              animation: repaint,
              builder: (_, _) => CustomPaint(
                painter: _LockedOverlayPainter(
                  color: skin.themeColor,
                  time: DateTime.now().millisecondsSinceEpoch / 1000.0,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Button label & color
    String? btnLabel;
    Color   btnColor = skin.themeColor;
    bool    btnFilled = false;
    VoidCallback? btnAction;

    if (isEquipped) {
      // No button — status row shows it
    } else if (owned) {
      btnLabel  = 'EQUIP';
      btnFilled = false;
      btnAction = onEquip;
    } else if (canAfford) {
      btnLabel  = 'BUY';
      btnFilled = true;
      btnAction = onBuy;
    } else {
      btnColor = Colors.white.withValues(alpha: 0.20);
    }

    // Status text
    final String statusText;
    final Color  statusColor;
    if (isEquipped) {
      statusText  = '\u2713 EQUIPPED';
      statusColor = const Color(0xFF00E5FF);
    } else if (owned) {
      statusText  = 'OWNED';
      statusColor = skin.themeColor.withValues(alpha: 0.65);
    } else {
      statusText  = '$price GP';
      statusColor = canAfford
          ? skin.themeColor.withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.28);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (_, _) {
          final glowT = glowAnimation.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF0D1528),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: skin.themeColor.withValues(alpha: 0.15 + glowT * 0.15),
                    blurRadius: 14, spreadRadius: 1,
                  ),
                if (glowBorder && !isSelected)
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.08 + glowT * 0.08),
                    blurRadius: 10, spreadRadius: 0,
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Daily deal banner
                  if (isDailyDeal) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF2D87)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'DAILY DEAL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          if (dealTimeLeft != null && dealTimeLeft!.isNotEmpty)
                            Text(
                              dealTimeLeft!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Rarity label
                  Text(
                    skin.rarity.label,
                    style: TextStyle(
                      color: skin.rarity.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Skin icon
                  iconWidget,
                  const SizedBox(height: 4),

                  // Name (locked = "?????")
                  Text(
                    locked ? '?????' : skin.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locked
                          ? Colors.white.withValues(alpha: 0.30)
                          : Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),

                  // "LOCKED" label for locked skins
                  if (locked) ...[
                    const SizedBox(height: 1),
                    Text(
                      'LOCKED',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.18),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],

                  // Effect name for unlocked
                  if (!locked) ...[
                    const SizedBox(height: 1),
                    Text(
                      skin.effectName,
                      style: TextStyle(
                        color: skin.themeColor.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],

                  // Price row (with daily deal strikethrough)
                  if (isDailyDeal && locked) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${skin.price}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$price GP',
                          style: const TextStyle(
                            color: Color(0xFFFF6B00),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ] else ...[
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Button (EQUIP / BUY / nothing)
                  if (btnLabel != null)
                    GestureDetector(
                      onTap: btnAction,
                      child: Container(
                        height: 22,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: btnFilled
                              ? btnColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          border: Border.all(color: btnColor, width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            btnLabel,
                            style: TextStyle(
                              color: btnColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 14,
                      child: Center(
                        child: Container(
                          height: 1,
                          width: 24,
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Locked Overlay Painter (scan lines + hologram tint) ───────────────────────

class _LockedOverlayPainter extends CustomPainter {
  final Color color;
  final double time;

  _LockedOverlayPainter({required this.color, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Hologram color shift overlay
    final hologramPaint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..blendMode = BlendMode.screen;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), hologramPaint);

    // Moving scan lines
    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final lineSpacing = 4.0;
    final offset = (time * 30.0) % lineSpacing;
    for (double y = -lineSpacing + offset; y < size.height; y += lineSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        scanPaint,
      );
    }

    // Brighter scan band that moves down
    final bandY = (time * 25.0) % (size.height + 20) - 10;
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, bandY - 8, size.width, 16));
    canvas.drawRect(
      Rect.fromLTWH(0, bandY - 8, size.width, 16),
      bandPaint,
    );
  }

  @override
  bool shouldRepaint(_LockedOverlayPainter old) => true;
}

// ── Try Preview Dialog ────────────────────────────────────────────────────────

class _TryPreviewDialog extends StatelessWidget {
  final CharacterSkin skin;
  final Listenable previewRepaint;
  final Animation<double> glowCtrl;

  const _TryPreviewDialog({
    required this.skin,
    required this.previewRepaint,
    required this.glowCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([previewRepaint, glowCtrl]),
        builder: (ctx, child) {
          final glow = 0.5 + glowCtrl.value * 0.5;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rarity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: skin.rarity.color.withValues(alpha: 0.2),
                  border: Border.all(color: skin.rarity.color.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  skin.rarity.label,
                  style: TextStyle(
                    color: skin.rarity.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Large preview
              Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D1528),
                  border: Border.all(
                    color: skin.themeColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: skin.themeColor.withValues(alpha: glow * 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(180, 180),
                    painter: SkinPreviewPainter(
                      color: skin.themeColor,
                      glowT: glow,
                      skinId: skin.id,
                      repaint: previewRepaint,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                skin.name.toUpperCase(),
                style: TextStyle(
                  color: skin.themeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: skin.themeColor.withValues(alpha: 0.7), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    skin.effectName,
                    style: TextStyle(
                      color: skin.themeColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Purchase Burst Overlay ────────────────────────────────────────────────────

class _BurstOverlay extends StatefulWidget {
  final CharacterSkin skin;
  final VoidCallback onComplete;

  const _BurstOverlay({required this.skin, required this.onComplete});

  @override
  State<_BurstOverlay> createState() => _BurstOverlayState();
}

class _BurstOverlayState extends State<_BurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final t     = _ctrl.value;
        final alpha = (t < 0.3 ? t / 0.3 : (1 - t) / 0.7).clamp(0.0, 1.0);
        final scale = 0.1 + t * 3.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black.withValues(alpha: (alpha * 0.6).clamp(0, 0.8))),
            Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.skin.themeColor.withValues(alpha: (alpha * 0.55).clamp(0, 1)),
                    boxShadow: [
                      BoxShadow(
                        color: widget.skin.themeColor.withValues(alpha: (alpha * 0.8).clamp(0, 1)),
                        blurRadius: 60, spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (t > 0.25 && t < 0.90)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('UNLOCKED',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: (
                              ((t - 0.25) / 0.65).clamp(0, 1) *
                              ((0.90 - t) / 0.65).clamp(0, 1) * 2.5).clamp(0, 1)),
                          fontSize: 28, fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        )),
                    const SizedBox(height: 8),
                    Text(widget.skin.name.toUpperCase(),
                        style: TextStyle(
                          color: widget.skin.themeColor.withValues(alpha: (
                              ((t - 0.25) / 0.65).clamp(0, 1) *
                              ((0.90 - t) / 0.65).clamp(0, 1) * 2.5).clamp(0, 1)),
                          fontSize: 15, fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        )),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _NeonRingIconPainter extends CustomPainter {
  final Color color;
  final double glowT;

  _NeonRingIconPainter({required this.color, required this.glowT});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 0.5;

    canvas.drawCircle(c, r,
        Paint()
          ..color = color.withValues(alpha: glowT * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawCircle(c, 2.0,
        Paint()..color = color.withValues(alpha: glowT));
  }

  @override
  bool shouldRepaint(_NeonRingIconPainter old) =>
      old.glowT != glowT || old.color != color;
}

class _BgRingPainter extends CustomPainter {
  final Color color;

  _BgRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(c, size.width * (0.38 + i * 0.22),
          Paint()
            ..color = color.withValues(alpha: 0.05 - i * 0.012)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(_BgRingPainter old) => old.color != color;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.022)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
