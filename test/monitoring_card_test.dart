import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phishnet_app/services/monitoring_service.dart';
import 'package:phishnet_app/widgets/monitoring_card.dart';

MonitoringService _service({required String endpoint, http.Client? client}) {
  return MonitoringService(
    client: client ?? MockClient((_) async => throw Exception('offline')),
    tokenProvider: () async => 'fake-id-token',
    endpoint: endpoint,
  );
}

Future<void> _pumpCard(WidgetTester tester, MonitoringService service) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MonitoringCard(service: service)),
    ),
  );
}

void main() {
  testWidgets('card is hidden when no monitoring endpoint is configured', (
    tester,
  ) async {
    await _pumpCard(tester, _service(endpoint: ''));
    await tester.pump();

    expect(find.text('Checking Yahoo email…'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Connect Yahoo'), findsNothing);
    expect(find.byType(MonitoringCard), findsOneWidget);
  });

  testWidgets('a failed connection shows a clear message and Try again', (
    tester,
  ) async {
    await _pumpCard(tester, _service(endpoint: 'https://example.test/monitor'));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(
      find.textContaining("Couldn't reach Live Monitoring"),
      findsOneWidget,
    );
  });

  testWidgets('disconnected users see a Connect Yahoo action', (tester) async {
    final client = MockClient(
      (_) async => http.Response('{"status":"disconnected"}', 200),
    );
    await _pumpCard(
      tester,
      _service(endpoint: 'https://example.test/monitor', client: client),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check my Yahoo email for scams'), findsOneWidget);
    expect(find.text('Connect Yahoo'), findsOneWidget);
  });

  testWidgets('connected users see Turn off', (tester) async {
    final client = MockClient(
      (_) async => http.Response('{"status":"connected"}', 200),
    );
    await _pumpCard(
      tester,
      _service(endpoint: 'https://example.test/monitor', client: client),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yahoo email is connected'), findsOneWidget);
    expect(find.textContaining('not active yet'), findsOneWidget);
    expect(find.text('Turn off'), findsOneWidget);
  });
}
