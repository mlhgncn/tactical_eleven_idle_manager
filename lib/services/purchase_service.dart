import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  PurchaseService._();

  static final PurchaseService instance = PurchaseService._();

  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration('REVENUECAT_APP_USER_ID'));
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
