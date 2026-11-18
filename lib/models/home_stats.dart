import 'saved_scan.dart';

/// Home screen summary returned by the `scan_home` action.
class HomeStats {
  const HomeStats({
    required this.weekTotal,
    required this.weekHigh,
    required this.weekMedium,
    required this.weekLow,
    required this.scamRate,
    required this.attention48h,
    required this.recentHigh,
    required this.lastCheckedAt,
    required this.mockAnalysis,
  });

  final int weekTotal;
  final int weekHigh;
  final int weekMedium;
  final int weekLow;
  final int scamRate;
  final int attention48h;

  /// Unreviewed high-risk scans from the last 48 hours (up to 3).
  final List<SavedScan> recentHigh;
  final DateTime? lastCheckedAt;
  final bool mockAnalysis;

  /// Shown before any data loads, and for guests or offline use.
  static const empty = HomeStats(
    weekTotal: 0,
    weekHigh: 0,
    weekMedium: 0,
    weekLow: 0,
    scamRate: 0,
    attention48h: 0,
    recentHigh: [],
    lastCheckedAt: null,
    mockAnalysis: false,
  );

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final value = json[key];
      if (value is! num) throw FormatException('Missing $key');
      return value.toInt();
    }

    final rawRecent = json['recent_high'];
    if (rawRecent is! List) throw const FormatException('Missing recent_high');

    final rawChecked = json['last_checked_at'];
    final checked = rawChecked is String ? DateTime.tryParse(rawChecked) : null;

    return HomeStats(
      weekTotal: readInt('week_total'),
      weekHigh: readInt('week_high'),
      weekMedium: readInt('week_medium'),
      weekLow: readInt('week_low'),
      scamRate: readInt('scam_rate'),
      attention48h: readInt('attention_48h'),
      recentHigh: rawRecent
          .whereType<Map<String, dynamic>>()
          .map(SavedScan.fromJson)
          .toList(),
      lastCheckedAt: checked,
      mockAnalysis: json['data_source'] == 'mock_analysis',
    );
  }

  Map<String, dynamic> toJson() => {
    'week_total': weekTotal,
    'week_high': weekHigh,
    'week_medium': weekMedium,
    'week_low': weekLow,
    'scam_rate': scamRate,
    'attention_48h': attention48h,
    'recent_high': recentHigh.map((scan) => scan.toJson()).toList(),
    'last_checked_at': lastCheckedAt?.toIso8601String(),
    'data_source': mockAnalysis ? 'mock_analysis' : 'claude',
  };
}
