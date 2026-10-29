import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/scan_result.dart';

class ScanException implements Exception {
  final String message;

  const ScanException(this.message);

  @override
  String toString() => message;
}

class ScanService {
  ScanService({http.Client? client, FirebaseAuth? auth, String? endpoint})
    : _client = client ?? http.Client(),
      _auth = auth ?? FirebaseAuth.instance,
      _endpoint =
          endpoint ??
          const String.fromEnvironment(
            'SCAN_API_URL',
            defaultValue:
                'https://i2wkmhdclm5epiws4k53bcv35e0jcpmb.lambda-url.us-east-2.on.aws/',
          );

  final http.Client _client;
  final FirebaseAuth _auth;
  final String _endpoint;

  Future<ScanResult> analyzeMessage(String message) async {
    final text = message.trim();

    if (text.isEmpty) {
      throw const ScanException('Please enter a message to scan.');
    }

    if (text.length > 8000) {
      throw const ScanException('Message exceeds the 8000-character limit.');
    }

    final uri = Uri.tryParse(_endpoint);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ScanException('The scan service is not configured.');
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw const ScanException('Please sign in before scanning a message.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const ScanException('Unable to authenticate the scan request.');
    }

    http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 35));
    } catch (_) {
      throw const ScanException(
        'Unable to reach the scan service. Please try again.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ScanException(
        'Your session could not be verified. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw ScanException(
        'Scan failed (HTTP ${response.statusCode}). Please try again.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response');
      }

      return ScanResult.fromJson(decoded);
    } on FormatException {
      throw const ScanException('The scan service returned an invalid result.');
    } on TypeError {
      throw const ScanException('The scan service returned an invalid result.');
    }
  }

  void dispose() {
    _client.close();
  }
}
