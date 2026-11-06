import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/services/monitoring_service.dart';

const _endpoint = 'https://example.test/monitor';

MonitoringService _service(
  http.Response Function(http.Request request) handler, {
  Future<String?> Function()? token,
  String endpoint = _endpoint,
}) {
  return MonitoringService(
    client: MockClient((request) async => handler(request)),
    tokenProvider: token ?? () async => 'fake-id-token',
    endpoint: endpoint,
  );
}

void main() {
  test('status maps backend values and sends the Firebase token', () async {
    late http.Request seen;
    final service = _service((request) {
      seen = request;
      return http.Response(jsonEncode({'status': 'connected'}), 200);
    });

    expect(await service.status(), MonitoringStatus.connected);
    expect(seen.headers['Authorization'], 'Bearer fake-id-token');
    expect(jsonDecode(seen.body), {'action': 'status'});
  });

  test('unknown status values map to unknown, not connected', () async {
    final service = _service(
      (_) => http.Response(jsonEncode({'status': 'weird'}), 200),
    );
    expect(await service.status(), MonitoringStatus.unknown);
  });

  test('startConnect returns the Yahoo https consent URL', () async {
    final service = _service(
      (_) => http.Response(
        jsonEncode({
          'authorizationUrl':
              'https://api.login.yahoo.com/oauth2/request_auth?state=x',
        }),
        200,
      ),
    );
    final url = await service.startConnect();
    expect(url.host, 'api.login.yahoo.com');
  });

  test('startConnect rejects a non-https or missing URL', () async {
    final service = _service(
      (_) => http.Response(
        jsonEncode({'authorizationUrl': 'http://evil.example/'}),
        200,
      ),
    );
    await expectLater(
      service.startConnect(),
      throwsA(isA<MonitoringException>()),
    );
  });

  test('signed-out users get a clear error and no request is sent', () async {
    var called = false;
    final service = _service((_) {
      called = true;
      return http.Response('{}', 200);
    }, token: () async => null);
    await expectLater(
      service.status(),
      throwsA(
        isA<MonitoringException>().having(
          (e) => e.message,
          'message',
          contains('sign in'),
        ),
      ),
    );
    expect(called, isFalse);
  });

  test(
    'an unset endpoint fails safely instead of calling a default URL',
    () async {
      final service = _service((_) => http.Response('{}', 200), endpoint: '');
      await expectLater(service.status(), throwsA(isA<MonitoringException>()));
    },
  );

  test('retryable backend failures ask the user to try again', () async {
    final service = _service(
      (_) => http.Response(
        jsonEncode({'error': 'disconnect_failed', 'retryable': true}),
        503,
      ),
    );
    await expectLater(
      service.disconnect(),
      throwsA(
        isA<MonitoringException>().having(
          (e) => e.message,
          'message',
          'Something went wrong. Please try again.',
        ),
      ),
    );
  });

  test('network errors are reported without leaking details', () async {
    final service = MonitoringService(
      client: MockClient((_) async => throw Exception('socket detail')),
      tokenProvider: () async => 'fake-id-token',
      endpoint: _endpoint,
    );
    await expectLater(
      service.status(),
      throwsA(
        isA<MonitoringException>().having(
          (e) => e.message.contains('socket'),
          'leaks detail',
          isFalse,
        ),
      ),
    );
  });

  test('disconnect returns the backend status and never tokens', () async {
    final service = _service(
      (_) => http.Response(jsonEncode({'status': 'disconnected'}), 200),
    );
    final status = await service.disconnect();
    expect(status, MonitoringStatus.disconnected);
  });
}
