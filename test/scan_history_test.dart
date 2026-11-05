import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/screens/history_screen.dart';

void main() {
  Map<String, dynamic> sampleScan() => {
    'id': 'scan-123',
    'brief_description': 'Suspicious USPS delivery message',
    'createdAt': '2026-11-04T18:30:00+00:00',
    'risk_level': 'high',
    'scam_percentage': 85,
    'summary': 'The message requests an unexpected delivery payment.',
    'red_flags': [
      {
        'label': 'Suspicious Link',
        'description': 'The link may lead to a fake payment page.',
      },
    ],
    'next_steps': ['Do not click the link.'],
  };

  group('SavedScan', () {
    test('Parses a saved scan correctly', () {
      final scan = SavedScan.fromJson(sampleScan());

      expect(scan.id, 'scan-123');
      expect(scan.description, 'Suspicious USPS delivery message');
      expect(scan.result.riskLevel, 'high');
      expect(scan.result.scamPercentage, 85);
      expect(scan.result.redFlags.length, 1);
      expect(scan.result.nextSteps.length, 1);
      expect(scan.createdAt, DateTime.utc(2026, 11, 4, 18, 30));
    });

    test('Uses a fallback description when missing', () {
      final data = sampleScan();
      data.remove('brief_description');

      final scan = SavedScan.fromJson(data);

      expect(scan.description, 'Scanned message');
    });

    test('Allows missing timestamps', () {
      final data = sampleScan();
      data['createdAt'] = null;

      final scan = SavedScan.fromJson(data);

      expect(scan.createdAt, isNull);
    });

    test('Rejects invalid scan IDs', () {
      final data = sampleScan();
      data['id'] = '';

      expect(() => SavedScan.fromJson(data), throwsFormatException);
    });

    test('Rejects invalid timestamps', () {
      final data = sampleScan();
      data['createdAt'] = 'invalid-date';

      expect(() => SavedScan.fromJson(data), throwsFormatException);
    });
  });
  group('History search', () {
    final scans = [
      SavedScan.fromJson(sampleScan()),
      SavedScan.fromJson({
        ...sampleScan(),
        'id': 'scan-456',
        'brief_description': 'Bank account verification',
        'risk_level': 'medium',
        'scam_percentage': 55,
        'summary': 'A message asking the user to verify bank details.',
      }),
    ];

    test('Filters by description', () {
      final results = filterSavedScans(scans, 'USPS');

      expect(results.length, 1);
      expect(results.first.id, 'scan-123');
    });

    test('Filters by summary', () {
      final results = filterSavedScans(scans, 'bank details');

      expect(results.length, 1);
      expect(results.first.id, 'scan-456');
    });

    test('Filters by risk level', () {
      final results = filterSavedScans(scans, 'medium');

      expect(results.length, 1);
      expect(results.first.result.riskLevel, 'medium');
    });

    test('Search is case insensitive', () {
      final results = filterSavedScans(scans, 'uSpS');

      expect(results.length, 1);
    });

    test('Empty search returns all scans', () {
      expect(filterSavedScans(scans, ''), hasLength(2));
    });

    test('Unmatched search returns no scans', () {
      expect(filterSavedScans(scans, 'restaurant'), isEmpty);
    });
  });
}
