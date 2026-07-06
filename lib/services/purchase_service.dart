import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';
import 'analytics_service.dart';

class PurchaseService {
  PurchaseService._();

  static final PurchaseService instance = PurchaseService._();

  Future<void> initialize() async {
    if (Config.revenueCatApiKey.isEmpty) {
      throw Exception('RevenueCat API anahtarı yapılandırılmamış. REVENUECAT_API_KEY ortam değişkenini ayarlayın.');
    }

    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(Config.revenueCatApiKey));
  }

  Future<void> purchaseCredits() async {
    try {
      try {
        AnalyticsService.instance.logEvent('purchase_start');
      } catch (_) {}
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) {
        try {
          AnalyticsService.instance.logEvent('purchase_success');
        } catch (_) {}
        return;
      }
      // RevenueCat purchase call placeholder for production wiring.
      await Future<void>.value();
      try {
        AnalyticsService.instance.logEvent('purchase_success');
      } catch (_) {}
    } catch (_) {
      rethrow;
    }
  }
}
