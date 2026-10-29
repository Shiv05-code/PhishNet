import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AwsSubscriptionService {
  AwsSubscriptionService._();

  static final AwsSubscriptionService instance = AwsSubscriptionService._();

  static const String _baseUrl = String.fromEnvironment('AWS_SUBSCRIPTION_URL');

  Future<String> _getFirebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('User must be signed in.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw StateError('Unable to authenticate user.');
    }

    return token;
  }

  Uri _endpoint(String path) {
    final base = Uri.tryParse(_baseUrl);

    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.query.isNotEmpty ||
        base.fragment.isNotEmpty) {
      throw StateError('AWS subscription API is not configured.');
    }

    return base.resolve(path);
  }

  Future<String> getAccountToken() async {
    final token = await _getFirebaseToken();

    final response = await http
        .get(
          _endpoint('/subscriptions/account-token'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError('Unable to retrieve Apple account token.');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic> ||
        data['appAccountToken'] is! String ||
        (data['appAccountToken'] as String).isEmpty) {
      throw const FormatException('Invalid account-token response.');
    }

    return data['appAccountToken'] as String;
  }

  Future<Map<String, dynamic>> verifyPurchase(String transactionId) async {
    if (!RegExp(r'^[0-9]{1,30}$').hasMatch(transactionId)) {
      throw ArgumentError('Invalid Apple transaction ID.');
    }

    final token = await _getFirebaseToken();

    final response = await http
        .post(
          _endpoint('/subscriptions/verify'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'transactionId': transactionId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw StateError('Subscription verification failed.');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic> || data['verified'] != true) {
      throw const FormatException('Invalid verification response.');
    }

    return data;
  }
}
