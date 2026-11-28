import 'package:flutter_test/flutter_test.dart';
import 'package:phishnet_app/models/saved_scan.dart';
import 'package:phishnet_app/models/stats_range.dart';

SavedScan _scan(String id, String risk, DateTime? at) => SavedScan.fromJson({
  'id': id,
  'brief_description': 'Scan $id',
  'summary': 'Summary $id',
  'risk_level': risk,
  'scam_percentage': 50,
  'red_flags': [],
  'next_steps': [],
  'createdAt': at?.toUtc().toIso8601String(),
});

void main() {
  final now = DateTime(2026, 11, 27, 12);
  final scans = [
    _scan('a', 'high', now.subtract(const Duration(days: 2))),
    _scan('b', 'low', now.subtract(const Duration(days: 10))),
    _scan('c', 'medium', now.subtract(const Duration(days: 100))),
  ];

  test('weekly counts only the last 7 days', () {
    final s = computeRangeStats(scans, StatsRange.week, now);
    expect((s.total, s.high, s.medium, s.low), (1, 1, 0, 0));
  });

  test('monthly includes scans from 10 days ago', () {
    final s = computeRangeStats(scans, StatsRange.month, now);
    expect((s.total, s.high, s.medium, s.low), (2, 1, 0, 1));
  });

  test('yearly includes older scans', () {
    final s = computeRangeStats(scans, StatsRange.year, now);
    expect((s.total, s.high, s.medium, s.low), (3, 1, 1, 1));
  });

  test('scam rate is the percent of high-risk scans', () {
    final s = computeRangeStats(scans, StatsRange.year, now);
    expect(s.scamRate, 33);
  });

  test('scans with no date are ignored', () {
    final s = computeRangeStats([_scan('x', 'high', null)], StatsRange.year, now);
    expect(s.total, 0);
  });

  test('no scans gives a zero scam rate', () {
    final s = computeRangeStats([], StatsRange.week, now);
    expect((s.total, s.scamRate), (0, 0));
  });
}