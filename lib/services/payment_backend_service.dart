import 'package:cloud_functions/cloud_functions.dart';

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
}
