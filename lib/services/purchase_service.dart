import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  PurchaseService._();

  static final PurchaseService instance = PurchaseService._();

  static const String monthlyProductId = 'com.phishnet.plus.monthly';
  static const String yearlyProductId = 'com.phishnet.plus.yearly';

  static const Set<String> productIds = {
    monthlyProductId,
    yearlyProductId,
  };

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  List<ProductDetails> products = [];

  bool storeAvailable = false;
  bool purchasePending = false;
  String? errorMessage;

  Future<void> initialize({
    required void Function() onChanged,
    required Future<void> Function(PurchaseDetails purchase)
        onVerifiedPurchase,
  }) async {
    storeAvailable = await _iap.isAvailable();

    if (!storeAvailable) {
      errorMessage = 'The App Store is currently unavailable.';
      onChanged();
      return;
    }

    _purchaseSubscription ??= _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          await _handlePurchase(
            purchase,
            onChanged: onChanged,
            onVerifiedPurchase: onVerifiedPurchase,
          );
        }
      },
      onError: (error) {
        purchasePending = false;
        errorMessage = error.toString();
        onChanged();
      },
    );

    await loadProducts();
    onChanged();
  }

  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      errorMessage = response.error!.message;
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      errorMessage =
          'Missing App Store products: ${response.notFoundIDs.join(', ')}';
    }

    products = response.productDetails;
  }

  ProductDetails? productFor(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  Future<void> purchase(ProductDetails product) async {
    errorMessage = null;

    final purchaseParam = PurchaseParam(
      productDetails: product,
    );

    await _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    errorMessage = null;
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchase(
    PurchaseDetails purchase, {
    required void Function() onChanged,
    required Future<void> Function(PurchaseDetails purchase)
        onVerifiedPurchase,
  }) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        purchasePending = true;
        break;

      case PurchaseStatus.error:
        purchasePending = false;
        errorMessage =
            purchase.error?.message ?? 'Purchase failed.';
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        purchasePending = false;

        // TODO: Replace with secure backend verification.
        await onVerifiedPurchase(purchase);
        break;

      case PurchaseStatus.canceled:
        purchasePending = false;
        break;
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }

    onChanged();
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }
}