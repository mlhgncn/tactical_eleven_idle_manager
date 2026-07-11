import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ödüllü (rewarded) reklamları yükler ve gösterir. Oyuncu/kulüp
/// geliştirmelerinde "reklam izle, süreyi %25 azalt" akışı için kullanılır.
///
/// AdMob App ID'ler android/app/src/main/AndroidManifest.xml (com.google.
/// android.gms.ads.APPLICATION_ID) ve ios/Runner/Info.plist
/// (GADApplicationIdentifier) içinde ayarlı. Ad Unit ID'ler App Store/Play
/// Store listing'inde zaten görünür olduğundan gizli bilgi değildir.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const String _rewardedAdUnitId = 'ca-app-pub-3621419452103208/9196793731';

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadAd();
  }

  bool get isAdReady => _rewardedAd != null;

  void _loadAd() {
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
        },
      ),
    );
  }

  /// Reklamı gösterir ve kullanıcı ödülü hak ederse `true` döner. Reklam
  /// hazır değilse (yükleniyor veya yüklenemedi) `false` döner ve bir
  /// sonraki gösterim için yeniden yükleme dener.
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) {
      _loadAd();
      return false;
    }
    _rewardedAd = null;

    final completer = Completer<bool>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        _loadAd();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        _loadAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (_, __) {
      earnedReward = true;
    });

    return completer.future;
  }
}
