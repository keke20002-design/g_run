import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ── AdManager singleton ───────────────────────────────────────────────────────
// Rewarded Interstitial ad for both skin unlock and game-over revive.

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  /// Test mode: when true, skips the real ad and returns success immediately.
  static const bool kTestMode = false;

  static const _adUnitId = 'ca-app-pub-5381891295736795/5146612634';

  RewardedInterstitialAd? _rewardedInterstitialAd;

  bool get isAdReady => _rewardedInterstitialAd != null;

  static bool get _adsSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ── Load ──────────────────────────────────────────────────────────────────
  void loadRewardedAd() => _load();
  void loadInterstitialAd() => _load();

  void _load() {
    if (!_adsSupported) return;
    if (_rewardedInterstitialAd != null) return; // already loaded
    RewardedInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) => _rewardedInterstitialAd = ad,
        onAdFailedToLoad: (error) {
          _rewardedInterstitialAd = null;
          // Retry after a short delay
          Future.delayed(const Duration(seconds: 30), _load);
        },
      ),
    );
  }

  // ── Show (rewarded — skin unlock) ─────────────────────────────────────────
  /// Returns true if the user watched the ad and earned the reward.
  Future<bool> showRewardedAd() async {
    if (kTestMode) return true;
    if (_rewardedInterstitialAd == null) return false;
    final completer = Completer<bool>();
    bool earned = false;
    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _load();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _load();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await _rewardedInterstitialAd!
        .show(onUserEarnedReward: (_, __) => earned = true);
    _rewardedInterstitialAd = null;
    return completer.future;
  }

  // ── Show (interstitial — game-over revive) ────────────────────────────────
  /// Returns true only if the user watched the full ad and earned the reward.
  Future<bool> showInterstitialAd() async {
    if (kTestMode) return true;
    if (_rewardedInterstitialAd == null) return false;
    final completer = Completer<bool>();
    bool earned = false;
    _rewardedInterstitialAd!.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _load();
        // 광고를 끝까지 봤을 때만 true
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        _load();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await _rewardedInterstitialAd!
        .show(onUserEarnedReward: (_, __) => earned = true);
    _rewardedInterstitialAd = null;
    return completer.future;
  }
}
