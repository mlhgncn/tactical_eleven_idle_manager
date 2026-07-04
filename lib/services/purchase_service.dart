import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

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
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) {
        return;
      }
      // RevenueCat purchase call placeholder for production wiring.
      await Future<void>.value();
    } catch (_) {
      rethrow;
    }
  }
}
