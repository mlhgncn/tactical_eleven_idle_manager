import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: Config.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    final interstitialAdUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> showRewardedAd() async {
    if (_rewardedAd == null) return;

    await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {});
    _rewardedAd = null;
    _loadRewardedAd();
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) return;

    await _interstitialAd!.show();
    _interstitialAd = null;
    _loadInterstitialAd();
  }
}
