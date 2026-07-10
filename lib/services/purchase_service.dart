import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Thin wrapper around the `in_app_purchase` plugin for buying diamond
/// packs via StoreKit. Never credits anything itself - it only surfaces
/// completed purchases via [onPurchaseVerified]; the caller (GameProvider)
/// is responsible for sending the receipt to the server for verification
/// before the purchase is considered real.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Called for every purchase that reaches the `purchased`/`restored`
  /// state, before [PurchaseDetails] is marked complete. Return true once
  /// the purchase has been verified and credited server-side so the
  /// pending transaction can be finished; return false to leave it pending
  /// (e.g. verification failed transiently) so StoreKit resurfaces it.
  Future<bool> Function(PurchaseDetails details)? onPurchaseVerified;

  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    final available = await _iap.isAvailable();
    if (!available) return false;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (Object error) => debugPrint('PurchaseService stream error: $error'),
    );
    _isInitialized = true;
    return true;
  }

  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    if (productIds.isEmpty) return <ProductDetails>[];
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      debugPrint('PurchaseService queryProductDetails error: ${response.error}');
    }
    return response.productDetails;
  }

  Future<void> buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: !Platform.isIOS);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        debugPrint('PurchaseService purchase error: ${purchase.error}');
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final verified = await onPurchaseVerified?.call(purchase) ?? false;
        if (verified && purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _isInitialized = false;
  }
}
