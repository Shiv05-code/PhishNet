import 'saved_scan.dart';

enum StatsRange {
  week('Weekly', 'this week', 7),
  month('Monthly', 'this month', 30),
  year('Yearly', 'this year', 365);

  const StatsRange(this.label, this.phrase, this.days);
  final String label;
  final String phrase;
  final int days;
}

class RangeStats {
  const RangeStats({
    required this.total,
    required this.high,
    required this.medium,
    required this.low,
  });

  final int total;
  final int high;
  final int medium;
  final int low;

  /// Percent of scans rated high risk.
  int get scamRate => total == 0 ? 0 : (high * 100 / total).round();
}

/// Counts scans from the last [range.days] days by risk level.
RangeStats computeRangeStats(
  List<SavedScan> scans,
  StatsRange range,
  DateTime now,
) {
  final since = now.subtract(Duration(days: range.days));
  var high = 0, medium = 0, low = 0;
  for (final s in scans) {
    final at = s.createdAt;
    if (at == null || at.isBefore(since)) continue;
    switch (s.result.riskLevel) {
      case 'high':
        high++;
      case 'medium':
        medium++;
      case 'low':
        low++;
    }
  }
  return RangeStats(
    total: high + medium + low,
    high: high,
    medium: medium,
    low: low,
  );
}
