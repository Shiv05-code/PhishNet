import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymentBackendService {
  PaymentBackendService._();

  static final PaymentBackendService instance = PaymentBackendService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  Future<Map<String, dynamic>> verifySubscription(String productId) async {
    final callable = _functions.httpsCallable('verifySubscription');

    final result = await callable.call<Map<String, dynamic>>({
      'productId': productId,
    });

    return result.data;
  }

  Future<void> initializeSubscription() async {
    final callable = _functions.httpsCallable('initializeSubscription');
    await callable.call();
  }

  Future<Map<String, dynamic>> demoUpgradeSubscription(String productId) async {
    const useEmulators = bool.fromEnvironment(
      'USE_FIREBASE_EMULATORS',
      defaultValue: false,
    );

    if (!kDebugMode || !useEmulators) {
      throw StateError(
        'Demo upgrades are only available in local emulator mode.',
      );
    }

    final callable = _functions.httpsCallable('demoUpgradeSubscription');

    final result = await callable.call<Map<String, dynamic>>({
      'productId': productId,
    });

    return result.data;
  }
}
