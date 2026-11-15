import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/services/scan_history_cache.dart';

SavedScan sampleScan(String id) {
  return SavedScan.fromJson({
    'id': id,
    'brief_description': 'Suspicious delivery message',
    'createdAt': '2026-11-04T18:30:00Z',
    'risk_level': 'high',
    'scam_percentage': 85,
    'summary': 'A suspicious delivery payment request.',
    'red_flags': [],
    'next_steps': ['Do not click the link.'],
  });
}

void main() {
  final cache = ScanHistoryCache.instance;

  setUp(() {
    cache.clearAll();
  });

  test('Stores and retrieves cached scans', () {
    cache.save('user-a', [sampleScan('scan-1')]);

    final scans = cache.get('user-a');

    expect(scans, isNotNull);
    expect(scans, hasLength(1));
    expect(scans!.first.id, 'scan-1');
  });

  test('Keeps different users separated', () {
    cache.save('user-a', [sampleScan('scan-a')]);
    cache.save('user-b', [sampleScan('scan-b')]);

    expect(cache.get('user-a')!.first.id, 'scan-a');
    expect(cache.get('user-b')!.first.id, 'scan-b');
  });

  test('Newly cached scans are fresh', () {
    cache.save('user-a', [sampleScan('scan-1')]);

    expect(cache.isFresh('user-a'), isTrue);
  });

  test('Missing cache is not fresh', () {
    expect(cache.isFresh('unknown-user'), isFalse);
  });

  test('Clearing one user preserves another', () {
    cache.save('user-a', [sampleScan('scan-a')]);
    cache.save('user-b', [sampleScan('scan-b')]);

    cache.clear('user-a');

    expect(cache.get('user-a'), isNull);
    expect(cache.get('user-b'), isNotNull);
  });

  test('Cached lists cannot be modified', () {
    cache.save('user-a', [sampleScan('scan-1')]);

    expect(() => cache.get('user-a')!.clear(), throwsUnsupportedError);
  });
}
