import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Live Monitoring state for the Gmail inbox, as reported by the backend.
enum MonitoringStatus {
  disconnected,
  connected,
  denied,
  error,
  reauthNeeded,
  unavailable,
  unknown;

  static MonitoringStatus fromWire(String? value) {
    switch (value) {
      case 'disconnected':
        return MonitoringStatus.disconnected;
      case 'connected':
        return MonitoringStatus.connected;
      case 'denied':
        return MonitoringStatus.denied;
      case 'error':
        return MonitoringStatus.error;
      case 'reauth_needed':
        return MonitoringStatus.reauthNeeded;
      case 'unavailable':
        return MonitoringStatus.unavailable;
      default:
        return MonitoringStatus.unknown;
    }
  }
}

class MonitoringException implements Exception {
  final String message;
  const MonitoringException(this.message);

  @override
  String toString() => message;
}

/// Talks to the phishnet-monitor-connect Lambda. The app never sees Google
/// tokens; it only gets a consent URL and a status string.
class MonitoringService {
  MonitoringService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String? endpoint,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _firebaseToken,
       _endpoint = endpoint ?? _defaultEndpoint;

  // Connect Function URL. Not a secret: every request needs a Firebase ID token.
  // The --dart-define still overrides it when set.
  static const _defaultEndpoint = String.fromEnvironment(
    'MONITOR_API_URL',
    defaultValue:
        'https://vgnizq3oywbsr2rdjvu6hrs4yi0djeyn.lambda-url.us-east-2.on.aws/',
  );

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final String _endpoint;

  static Future<String?> _firebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken();
  }

  /// False when this build has no valid MONITOR_API_URL. The UI hides
  /// monitoring entirely in that case.
  bool get isConfigured {
    final uri = Uri.tryParse(_endpoint);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Uri _uri() {
    if (!isConfigured) {
      throw const MonitoringException(
        'Live Monitoring is not set up in this build yet.',
      );
    }
    return Uri.parse(_endpoint);
  }

  Future<Map<String, dynamic>> _post(
    String action, {
    Map<String, Object?> extra = const {},
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const MonitoringException('Please sign in to use Live Monitoring.');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            _uri(),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'action': action, ...extra}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const MonitoringException(
        "Couldn't reach Live Monitoring. Check your connection and try again.",
      );
    }
    final decoded = _decode(response.body);
    if (response.statusCode != 200) {
      throw MonitoringException(
        decoded['retryable'] == true
            ? 'Something went wrong. Please try again.'
            : 'Live Monitoring is unavailable right now.',
      );
    }
    return decoded;
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<MonitoringStatus> status() async {
    final body = await _post('status');
    return MonitoringStatus.fromWire(body['status'] as String?);
  }

  /// Returns the Google consent URL. Opening it is up to the caller.
  Future<Uri> startConnect() async {
    final body = await _post('start');
    final url = Uri.tryParse(body['authorizationUrl'] as String? ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const MonitoringException(
        "Couldn't start the Gmail connection. Please try again.",
      );
    }
    return url;
  }

  /// Registers this device for high-risk alert pushes. Token is never logged.
  Future<void> registerDevice(String token, String platform) async {
    await _post(
      'register_device',
      extra: {'token': token, 'platform': platform},
    );
  }

  Future<MonitoringStatus> disconnect() async {
    final body = await _post('disconnect');
    return MonitoringStatus.fromWire(body['status'] as String?);
  }
}
