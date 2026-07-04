import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  Future<void> showRewardedAd() async {
    // Placeholder implementation for rewarded ads.
  }

  Future<void> showInterstitialAd() async {
    // Placeholder implementation for interstitial ads.
  }
}
