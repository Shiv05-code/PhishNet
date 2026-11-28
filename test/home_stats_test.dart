import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phishnet_app/models/home_stats.dart';
import 'package:phishnet_app/screens/home_screen.dart';
import 'package:phishnet_app/services/home_stats_cache.dart';
import 'package:phishnet_app/services/scan_service.dart';
import 'package:phishnet_app/models/saved_scan.dart';

import 'support/fake_auth_service.dart';
import 'support/test_helpers.dart';

Map<String, dynamic> _payload({
  int total = 10,
  int high = 3,
  int attention = 0,
  String source = 'claude',
}) => {
  'week_total': total,
  'week_high': high,
  'week_medium': 2,
  'week_low': total - high - 2,
  'scam_rate': total == 0 ? 0 : high * 100 ~/ total,
  'attention_48h': attention,
  'recent_high': [
    {
      'id': 'a1',
      'brief_description': 'Prize notice',
      'summary': 'Looks fake.',
      'risk_level': 'high',
      'scam_percentage': 90,
      'red_flags': [],
      'next_steps': [],
      'createdAt': '2026-11-14T12:00:00+00:00',
    },
  ],
  'last_checked_at': '2026-11-14T12:00:00+00:00',
  'data_source': source,
};

Map<String, dynamic> _scanJson(String id, String risk, {int daysAgo = 1}) => {
  'id': id,
  'brief_description': 'Scan $id',
  'summary': 'Summary $id',
  'risk_level': risk,
  'scam_percentage': risk == 'high' ? 90 : (risk == 'medium' ? 50 : 5),
  'red_flags': [],
  'next_steps': [],
  'createdAt': DateTime.now()
      .subtract(Duration(days: daysAgo))
      .toUtc()
      .toIso8601String(),
  'monitored': true,
};

/// 10 monitored scans this week: 3 high, 2 medium, 5 low.
List<SavedScan> _history() => [
  for (var i = 0; i < 3; i++) SavedScan.fromJson(_scanJson('h$i', 'high')),
  for (var i = 0; i < 2; i++) SavedScan.fromJson(_scanJson('m$i', 'medium')),
  for (var i = 0; i < 5; i++) SavedScan.fromJson(_scanJson('l$i', 'low')),
];

class FakeScanService extends Fake implements ScanService {
  FakeScanService(this.stats);
  final HomeStats stats;
  int calls = 0;
  List<SavedScan> history = const [];

  @override
  Future<HomeStats> getHomeStats() async {
    calls++;
    if (transientFailuresRemaining > 0) {
      transientFailuresRemaining--;
      throw const ScanException('Temporary stats failure', retryable: true);
    }
    return stats;
  }

  @override
  Future<List<SavedScan>> getScanHistory() async => history;

  int transientFailuresRemaining = 0;
}

// Attention is Plus-only, so the Home test must provide an active Plus record.
final _activePlus = <String, dynamic>{
  'plan': 'plus',
  'status': 'active',
  'environment': 'production',
  'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeStatsCache.clear();
  });

  group('HomeStats.fromJson', () {
    test('parses counts, attention items, and mock flag', () {
      final stats = HomeStats.fromJson(_payload(source: 'mock_analysis'));
      expect(stats.weekTotal, 10);
      expect(stats.weekHigh, 3);
      expect(stats.scamRate, 30);
      expect(stats.recentHigh.single.description, 'Prize notice');
      expect(stats.mockAnalysis, isTrue);
      expect(stats.lastCheckedAt, isNotNull);
    });

    test('rejects a payload missing counts', () {
      expect(
        () => HomeStats.fromJson({'week_total': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('HomeStatsCache', () {
    test('entry is fresh within the TTL and stale after it', () async {
      final t0 = DateTime(2026, 11, 14, 12);
      await HomeStatsCache.put('u1', HomeStats.empty, t0);
      expect(
        HomeStatsCache.isFresh('u1', t0.add(const Duration(seconds: 30))),
        isTrue,
      );
      expect(HomeStatsCache.isFresh('u1', t0.add(HomeStatsCache.ttl)), isFalse);
    });

    test(
      'invalidate removes the entry and other users are unaffected',
      () async {
        final t0 = DateTime(2026, 11, 14, 12);
        await HomeStatsCache.put('u1', HomeStats.empty, t0);
        await HomeStatsCache.put('u2', HomeStats.empty, t0);
        HomeStatsCache.invalidate('u1');
        expect(HomeStatsCache.peek('u1'), isNull);
        expect(HomeStatsCache.peek('u2'), isNotNull);
      },
    );

    test(
      'restores a saved summary after the in-memory cache is cleared',
      () async {
        final stats = HomeStats.fromJson(_payload(attention: 1));
        await HomeStatsCache.put('u1', stats, DateTime.now());
        HomeStatsCache.clear();

        final restored = await HomeStatsCache.restore('u1');
        expect(restored?.weekTotal, stats.weekTotal);
        expect(restored?.recentHigh.single.description, 'Prize notice');
      },
    );
  });

  testWidgets('Home shows counts from the summary service', (tester) async {
    final service = FakeScanService(HomeStats.fromJson(_payload(attention: 1)))
      ..history = _history();
    await pumpScreen(
      tester,
      HomeScreen(
        authService: FakeAuthService(displayName: 'Ana Lopez'),
        scanService: service,
        subscriptionStream: Stream.value(_activePlus),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(service.calls, 1);
    expect(find.text('Review 1 flagged message below.'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('10'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('10'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('1 message needs your attention'), findsOneWidget);
    expect(find.textContaining('Prize notice'), findsOneWidget);
    expect(find.textContaining('Demo analysis'), findsNothing);
  });

  testWidgets('Home hides the demo caption by default', (tester) async {
    final service = FakeScanService(
      HomeStats.fromJson(_payload(source: 'mock_analysis')),
    );
    await pumpScreen(
      tester,
      HomeScreen(
        authService: FakeAuthService(displayName: 'Ana Lopez'),
        scanService: service,
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Demo analysis'), findsNothing);
  });

  testWidgets('Home uses the cached summary without a second request', (
    tester,
  ) async {
    final cached = HomeStats.fromJson(_payload());
    final service = FakeScanService(cached);
    // No signed-in user, so the cache key is null and Home fetches once.
    await pumpScreen(
      tester,
      HomeScreen(authService: FakeAuthService(), scanService: service),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(service.calls, 1);
  });

  testWidgets('Home automatically retries a transient stats failure', (
    tester,
  ) async {
    final service = FakeScanService(HomeStats.fromJson(_payload()));
    service.transientFailuresRemaining = 1;
    await pumpScreen(
      tester,
      HomeScreen(authService: FakeAuthService(), scanService: service),
    );
    await tester.pump();
    expect(service.calls, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(service.calls, 2);
    expect(
      find.text('Hooray! No messages need your attention.'),
      findsOneWidget,
    );
  });
}
