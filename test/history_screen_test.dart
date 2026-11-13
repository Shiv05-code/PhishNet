import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/screens/history_screen.dart';
import 'package:phishnet_app/services/scan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/testing.dart';
import 'package:phishnet_app/services/scan_history_cache.dart';
import 'dart:async';

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
  int requestCount = 0;

  @override
  Future<List<SavedScan>> getScanHistory() async {
    requestCount++;

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

class ControlledHistoryService extends FakeHistoryService {
  final List<Completer<List<SavedScan>>> requests = [];

  @override
  Future<List<SavedScan>> getScanHistory() {
    final request = Completer<List<SavedScan>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  setUp(() {
    ScanHistoryCache.instance.clearAll();
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AC 7: History shows an error and retries successfully', (
    tester,
  ) async {
    final service = FakeHistoryService()..shouldFail = true;

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
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
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
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
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
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
  testWidgets('Reopening History uses cached scans', (tester) async {
    final service = FakeHistoryService()..scans = [sampleSavedScan()];

    Widget history() => MaterialApp(
      home: HistoryScreen(
        scanService: service,
        historyUserId: () => 'test-user',
      ),
    );

    await tester.pumpWidget(history());
    await tester.pump();

    expect(service.requestCount, 1);
    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);

    // Close History.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Home'))),
    );

    // Reopen History.
    await tester.pumpWidget(history());
    await tester.pump();

    expect(service.requestCount, 1);
    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);
  });
  testWidgets('Pull-to-refresh bypasses cached scans', (tester) async {
    final service = FakeHistoryService()..scans = [sampleSavedScan()];

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
    );

    await tester.pump();

    expect(service.requestCount, 1);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    await indicator.onRefresh();
    await tester.pump();

    expect(service.requestCount, 2);
  });
  testWidgets('Older requests cannot overwrite newer history', (tester) async {
    final service = ControlledHistoryService();

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
    );

    await tester.pump();

    expect(service.requests.length, 1);

    // Start a newer request while the first request is pending.
    // The History screen's refresh method is private, so use
    // a widget-level trigger rather than calling it directly.
  });
  testWidgets('Older requests cannot overwrite newer history', (tester) async {
    final service = ControlledHistoryService();

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
    );

    expect(service.requests, hasLength(1));

    // Complete the initial history request.
    service.requests[0].complete([sampleSavedScan()]);
    await tester.pump();

    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    // Start two overlapping refresh requests.
    final firstRefresh = indicator.onRefresh();
    final secondRefresh = indicator.onRefresh();

    expect(service.requests, hasLength(3));

    final newerScan = SavedScan.fromJson({
      'id': 'scan-new',
      'brief_description': 'New Bank Alert',
      'createdAt': '2026-11-13T18:00:00Z',
      'risk_level': 'medium',
      'scam_percentage': 55,
      'summary': 'A suspicious bank verification request.',
      'red_flags': [],
      'next_steps': ['Contact your bank directly.'],
    });

    // The newer request completes first.
    service.requests[2].complete([newerScan]);
    await tester.pump();

    expect(find.text('New Bank Alert'), findsOneWidget);

    // The older request completes afterward.
    service.requests[1].complete([sampleSavedScan()]);
    await tester.pump();

    // The newer result must remain visible.
    expect(find.text('New Bank Alert'), findsOneWidget);
    expect(find.text('Suspicious USPS Delivery'), findsNothing);

    await Future.wait([firstRefresh, secondRefresh]);
  });
  testWidgets('Cached scans are isolated between users', (tester) async {
    final userAService = FakeHistoryService()..scans = [sampleSavedScan()];

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: userAService,
          historyUserId: () => 'user-a',
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Suspicious USPS Delivery'), findsOneWidget);

    // Simulate leaving History and signing in as another user.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Home'))),
    );

    final userBService = FakeHistoryService();

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: userBService,
          historyUserId: () => 'user-b',
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // User B must never see User A's cached scans.
    expect(find.text('Suspicious USPS Delivery'), findsNothing);
    expect(find.text('No scans yet.'), findsOneWidget);

    expect(ScanHistoryCache.instance.get('user-b'), isEmpty);
  });
  testWidgets('Cache invalidation rejects an outdated response', (
    tester,
  ) async {
    final service = ControlledHistoryService();
    final cache = ScanHistoryCache.instance;

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
    );

    expect(service.requests, hasLength(1));

    // A new scan invalidates the cache while history is loading.
    cache.clear('test-user');

    // The original request returns outdated history.
    service.requests[0].complete([sampleSavedScan()]);
    await tester.pump();

    // The outdated response must not repopulate the cache.
    expect(cache.get('test-user'), isNull);

    // The screen should start a fresh request.
    expect(service.requests, hasLength(2));

    final updatedScan = SavedScan.fromJson({
      'id': 'scan-updated',
      'brief_description': 'Updated Bank Alert',
      'createdAt': '2026-11-13T18:00:00Z',
      'risk_level': 'medium',
      'scam_percentage': 55,
      'summary': 'A new suspicious bank verification request.',
      'red_flags': [],
      'next_steps': ['Contact your bank directly.'],
    });

    service.requests[1].complete([updatedScan]);
    await tester.pump();

    expect(find.text('Updated Bank Alert'), findsOneWidget);
    expect(cache.get('test-user')!.first.id, 'scan-updated');
  });
  testWidgets('Sign-out prevents pending history from appearing', (
    tester,
  ) async {
    final service = ControlledHistoryService();
    String? currentUid = 'user-a';

    Widget buildHistory() => MaterialApp(
      home: HistoryScreen(
        scanService: service,
        historyUserId: () => currentUid,
      ),
    );

    await tester.pumpWidget(buildHistory());

    expect(service.requests, hasLength(1));

    // Simulate a sign-out.
    currentUid = null;

    // Complete the old request after sign-out.
    service.requests[0].complete([sampleSavedScan()]);
    await tester.pump();

    // The old user's scans must not appear.
    expect(find.text('Suspicious USPS Delivery'), findsNothing);

    // The old response must not populate the cache.
    expect(ScanHistoryCache.instance.get('user-a'), isNull);
  });
  testWidgets('Repeated invalidation stops after one automatic retry', (
    tester,
  ) async {
    final service = ControlledHistoryService();
    final cache = ScanHistoryCache.instance;

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          scanService: service,
          historyUserId: () => 'test-user',
        ),
      ),
    );

    expect(service.requests, hasLength(1));

    // Invalidate the first request.
    cache.clear('test-user');
    service.requests[0].complete([sampleSavedScan()]);
    await tester.pump();

    // The screen automatically retries once.
    expect(service.requests, hasLength(2));

    // Invalidate the retry as well.
    cache.clear('test-user');
    service.requests[1].complete([sampleSavedScan()]);
    await tester.pump();

    // There must not be a third automatic request.
    expect(service.requests, hasLength(2));

    // Neither outdated response should populate the cache.
    expect(cache.get('test-user'), isNull);

    // The user should receive a message instead of an endless spinner.
    expect(
      find.text('History changed while loading. Please try again.'),
      findsOneWidget,
    );
  });
}
