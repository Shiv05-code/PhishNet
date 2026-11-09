import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/screens/history_screen.dart';
import 'package:phishnet_app/services/scan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/testing.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class FakeHistoryService extends ScanService {
  FakeHistoryService()
    : super(
        endpoint: 'https://example.test',
        client: MockClient(
          (_) async => throw StateError('Unexpected HTTP request'),
        ),
        auth: _FakeFirebaseAuth(),
      );
  bool shouldFail = false;
  List<SavedScan> scans = [];

  @override
  Future<List<SavedScan>> getScanHistory() async {
    if (shouldFail) {
      throw const ScanException(
        'Unable to load scan history.',
        retryable: true,
      );
    }

    return scans;
  }

  @override
  void dispose() {}
}

SavedScan sampleSavedScan() {
  return SavedScan.fromJson({
    'id': 'scan-123',
    'brief_description': 'Suspicious USPS Delivery',
    'createdAt': '2026-11-04T18:30:00Z',
    'risk_level': 'high',
    'scam_percentage': 85,
    'summary': 'The message requests an unexpected delivery payment.',
    'red_flags': [],
    'next_steps': ['Do not click the link.'],
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC 7: History shows an error and retries successfully', (
    tester,
  ) async {
    final service = FakeHistoryService()..shouldFail = true;

    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(scanService: service)),
    );

    await tester.pump();

    expect(find.text('Unable to load scan history.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    service.shouldFail = false;
    service.scans = [sampleSavedScan()];

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets('AC 8: Empty history displays a helpful message', (tester) async {
    final service = FakeHistoryService();

    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(scanService: service)),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('No scans yet.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AC 7: A failed refresh does not erase saved scans', (
    tester,
  ) async {
    final service = FakeHistoryService()..scans = [sampleSavedScan()];

    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(scanService: service)),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);

    service.shouldFail = true;

    // Trigger a refresh using the RefreshIndicator.
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    await indicator.onRefresh();
    await tester.pump();
    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);

    expect(
      find.textContaining('Your previous scans are still available.'),
      findsOneWidget,
    );

    expect(find.text('Try Again'), findsNothing);

    // The fake service failed, but its stored data remains intact.
    expect(service.scans, hasLength(1));
  });
}
