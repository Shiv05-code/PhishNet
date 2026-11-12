import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../models/saved_scan.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/scan_result.dart';
import 'daily_limit.dart';

class ScanException implements Exception {
  final String message;
  final bool retryable;

  /// Set when a free user has used up today's requests.
  final DailyLimitInfo? dailyLimit;

  const ScanException(this.message, {this.retryable = false, this.dailyLimit});

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
    } on TimeoutException {
      throw const ScanException(
        'The check is taking longer than expected. Please try again.',
        retryable: true,
      );
    } on SocketException {
      throw const ScanException(
        'No internet connection. Check your connection and try again.',
        retryable: true,
      );
    } catch (_) {
      throw const ScanException(
        'We could not reach PhishNet. Please try again.',
        retryable: true,
      );
    }

    if (response.statusCode == 429) {
      final limit = DailyLimitInfo.fromBody(response.body);
      if (limit != null) {
        throw ScanException(limit.message(), dailyLimit: limit);
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ScanException(
        'Your session could not be verified. Please sign in again.',
      );
    }

    if (response.statusCode >= 500) {
      throw const ScanException(
        'PhishNet could not check this message right now. Please try again.',
        retryable: true,
      );
    }

    if (response.statusCode != 200) {
      throw const ScanException('Something went wrong. Please try again.');
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

  Future<List<SavedScan>> getScanHistory() async {
    final uri = Uri.tryParse(_endpoint);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ScanException('The scan service is not configured.');
    }

    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) {
      throw const ScanException('Please sign in to view your scan history.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const ScanException(
        'Unable to authenticate your scan history request.',
      );
    }

    late final http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': 'scan_history'}),
          )
          .timeout(const Duration(seconds: 35));
    } on TimeoutException {
      throw const ScanException(
        'Loading scan history took too long. Please try again.',
        retryable: true,
      );
    } on SocketException {
      throw const ScanException(
        'No internet connection. Check your connection and try again.',
        retryable: true,
      );
    } catch (_) {
      throw const ScanException(
        'Unable to load scan history. Please try again.',
        retryable: true,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ScanException(
        'Your session could not be verified. Please sign in again.',
      );
    }

    if (response.statusCode != 200) {
      throw const ScanException(
        'Unable to load scan history. Please try again.',
        retryable: true,
      );
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> || decoded['scans'] is! List) {
        throw const FormatException('Invalid history response');
      }

      return (decoded['scans'] as List).map((scan) {
        if (scan is! Map<String, dynamic>) {
          throw const FormatException('Invalid saved scan');
        }
        return SavedScan.fromJson(scan);
      }).toList();
    } on FormatException {
      throw const ScanException(
        'The scan service returned invalid history data.',
      );
    } on TypeError {
      throw const ScanException(
        'The scan service returned invalid history data.',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
