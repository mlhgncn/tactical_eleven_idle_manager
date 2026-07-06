import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../repositories/supabase_repository.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

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
    final interstitialAdUnitId = kReleaseMode
      ? (Config.interstitialAdUnitId.isNotEmpty
        ? Config.interstitialAdUnitId
        : (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910'))
      : (Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910');

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
    final rewardedAd = _rewardedAd;
    if (rewardedAd == null) return;
    await rewardedAd.show(onUserEarnedReward: (ad, reward) async {
      // Only award when rewarded callback is invoked (user watched the ad)
      try {
        final repo = SupabaseRepository();
        final rewardType = reward.type.isNotEmpty ? reward.type : 'extra_para';
        final amount = reward.amount.toInt();

        final result = await repo.awardAdReward(rewardType: rewardType, amount: amount);

        if (result != null && (result['awarded'] == true || result['awarded'] == 'true')) {
          final type = result['type'] ?? rewardType;
          final amt = result['amount'];
          final body = amt != null ? 'Ödül: $type (+$amt GP)' : 'Ödül: $type';
          NotificationService.instance.sendNotification('Ödül alındı', body);
          try {
            AnalyticsService.instance.logEvent('rewarded_ad_watched', parameters: {
              'type': type,
              if (amt != null) 'amount': amt,
            });
          } catch (_) {}
        } else if (result != null && result['awarded'] == false) {
          final reason = result['reason'] ?? '';
          if (reason == 'rate_limited') {
            NotificationService.instance.sendNotification('Ödül verilmedi', 'Reklam izleme limiti aşıldı. Lütfen daha sonra tekrar deneyin.');
          } else {
            NotificationService.instance.sendNotification('Ödül verilmedi', 'Ödül kaydı sırasında bir sorun oluştu.');
          }
          try {
            AnalyticsService.instance.logEvent('rewarded_ad_watched', parameters: {
              'type': rewardType,
              'awarded': false,
            });
          } catch (_) {}
        }
      } catch (e) {
        NotificationService.instance.sendNotification('Ödül Hatası', e.toString());
      }
    });
    _rewardedAd = null;
    _loadRewardedAd();
  }

  Future<void> showInterstitialAd() async {
    final interstitialAd = _interstitialAd;
    if (interstitialAd == null) return;

    await interstitialAd.show();
    _interstitialAd = null;
    _loadInterstitialAd();
  }
}
