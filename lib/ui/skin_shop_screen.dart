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
  }

  @override
  void dispose() {
    _previewRotCtrl.dispose();
    _cardRotCtrl.dispose();
    _glowCtrl.dispose();
    _gpScaleCtrl.dispose();
    _gpCountCtrl.dispose();
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
    _gpScaleCtrl.forward(from: 0); // ── 7️⃣ GP scale pop
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
                _buildPreviewPanel(),   // ── 6️⃣
                const SizedBox(height: 14),
                Expanded(child: _buildSkinGrid()), // ── 1️⃣ 4️⃣
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 7️⃣ Header / GP Badge ─────────────────────────────────────────────────
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
                // Neon ring icon (not hexagon)
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

  // ── 6️⃣ Preview Panel ─────────────────────────────────────────────────────
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
                    // ── 6️⃣ Very dim background rings ──
                    CustomPaint(
                      size: const Size(148, 165),
                      painter: _BgRingPainter(color: skin.themeColor),
                    ),
                    // ── 6️⃣ Larger icon — self-animating via repaint notifier ──
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
                      Text(
                        skin.name.toUpperCase(),
                        style: TextStyle(
                          color: skin.themeColor, fontSize: 13,
                          fontWeight: FontWeight.w900, letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildSkinDesc(skin),
                      const SizedBox(height: 12),
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

  Widget _buildSkinDesc(CharacterSkin skin) {
    final desc = switch (skin.id) {
      'classic_neon'    => 'The original cyber runner.\nClean cyan 4-spoke wheel.',
      'dual_core'       => 'Twin pulsing rings in sync.\nCyan energy resonance.',
      'pulse_core'      => 'Rhythmic core that beats\nfaster as speed increases.',
      'black_hole_core' => 'Accretion disk swirls inward.\nFlip reverses the spiral.',
      'prism_glass'     => 'Crystal hex refracts light.\nRainbow lines fill with speed.',
      'electric_pulse'  => 'Unstable lightning arcs crackle.\nMassive spark burst on flip.',
      'cyberpunk_wheel' => 'Binary code flows inside\na neon spoke wheel.',
      'guardian_shield' => 'Twin counter-rotating shields\norbit and flare on flip.',
      _                 => '',
    };
    return Text(desc,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 10.5, height: 1.55, letterSpacing: 0.2,
        ));
  }

  Widget _buildActionButton(CharacterSkin skin) {
    final isEquipped = SkinManager.instance.equippedSkinId == skin.id;
    final isOwned    = skin.isUnlocked;
    final canAfford  = SkinManager.instance.gravityPoints >= skin.price;

    if (isEquipped) {
      return _ActionChip(label: 'EQUIPPED', color: _cyan,
          filled: true, onTap: null);
    } else if (isOwned) {
      return _ActionChip(label: 'EQUIP', color: skin.themeColor,
          filled: false, onTap: () => _onEquip(skin));
    } else if (canAfford) {
      return _ActionChip(label: 'BUY  ${skin.price} GP',
          color: skin.themeColor, filled: true, onTap: () => _onBuy(skin));
    } else {
      return _ActionChip(label: '${skin.price} GP',
          color: Colors.white24, filled: false, onTap: null);
    }
  }

  // ── 1️⃣ 4️⃣ Skin Grid ─────────────────────────────────────────────────────
  Widget _buildSkinGrid() {
    final skins = SkinManager.instance.skins;
    return AnimatedBuilder(
      animation: _cardRotCtrl,
      builder: (ctx, child) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.95,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: skins.length,
          itemBuilder: (_, i) {
            final skin     = skins[i];
            final selected = _selectedSkinId == skin.id;
            final equipped = SkinManager.instance.equippedSkinId == skin.id;
            return _SkinCard(
              skin: skin,
              isSelected: selected,
              isEquipped: equipped,
              gravityPoints: SkinManager.instance.gravityPoints,
              repaint: _cardRotCtrl,
              onTap: () => _selectSkin(skin),
              onBuy:   () => _onBuy(skin),
              onEquip: () => _onEquip(skin),
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

// ── 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ Skin Card ─────────────────────────────────────────────

class _SkinCard extends StatelessWidget {
  final CharacterSkin skin;
  final bool isSelected;
  final bool isEquipped;
  final int gravityPoints;
  final Listenable repaint;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  final VoidCallback? onEquip;

  const _SkinCard({
    required this.skin,
    required this.isSelected,
    required this.isEquipped,
    required this.gravityPoints,
    required this.repaint,
    required this.onTap,
    this.onBuy,
    this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final owned     = skin.isUnlocked;
    final canAfford = gravityPoints >= skin.price;
    final locked    = !owned;

    // ── 3️⃣ Border: quiet unselected, strong selected ──
    final borderColor = isSelected
        ? skin.themeColor.withValues(alpha: 0.85)
        : skin.themeColor.withValues(alpha: locked ? 0.15 : 0.30);
    final borderWidth = isSelected ? 1.4 : 0.8;

    // ── 4️⃣ Icon color ──
    final iconColor = locked
        ? skin.themeColor.withValues(alpha: 0.50)
        : (isSelected ? skin.themeColor : skin.themeColor.withValues(alpha: 0.65));

    // Icon — self-animating via repaint notifier (same controller as preview)
    Widget iconWidget = SizedBox(
      width: 45, height: 45,
      child: CustomPaint(
        painter: SkinPreviewPainter(
          color: iconColor,
          glowT: isSelected ? 0.85 : (locked ? 0.18 : 0.45),
          skinId: skin.id,
          repaint: repaint,
        ),
      ),
    );

    // ── 5️⃣ Desaturate locked skins ──
    if (locked) {
      iconWidget = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          0.25, 0.60, 0.15, 0, 0,
          0.25, 0.60, 0.15, 0, 0,
          0.25, 0.60, 0.15, 0, 0,
          0,    0,    0,    0.55, 0,
        ]),
        child: iconWidget,
      );
    }

    // ── 버튼 라벨 & 색 결정 ──
    String? btnLabel;
    Color   btnColor = skin.themeColor;
    bool    btnFilled = false;
    VoidCallback? btnAction;

    if (isEquipped) {
      // 버튼 없음 — 상태 행에 표시
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

    // 상태 행 텍스트
    final String statusText;
    final Color  statusColor;
    if (isEquipped) {
      statusText  = '● EQUIPPED';
      statusColor = const Color(0xFF00E5FF);
    } else if (owned) {
      statusText  = 'OWNED';
      statusColor = skin.themeColor.withValues(alpha: 0.65);
    } else {
      statusText  = '${skin.price} GP';
      statusColor = canAfford
          ? skin.themeColor.withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.28);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF0D1528),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isSelected
              ? [BoxShadow(color: skin.themeColor.withValues(alpha: 0.20),
                    blurRadius: 10, spreadRadius: 0)]
              : [],
        ),
        // ── 4행 구조: 위로 당기기 ──
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ① 링 애니메이션 (38px)
              iconWidget,
              const SizedBox(height: 4),

              // ② 이름
              Text(
                skin.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),

              // ③ 가격 or 상태
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),

              // ④ 버튼 (EQUIP / BUY / 없음)
              if (btnLabel != null)
                GestureDetector(
                  onTap: btnAction,
                  child: Container(
                    height: 19,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 11,
                  child: Center(
                    child: Container(
                      height: 1,
                      width: 20,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

/// GP 뱃지 네온 링 아이콘
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

/// 미리보기 패널 뒤쪽 희미한 배경 링
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


/// 그리드 배경 패턴
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
