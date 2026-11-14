import '../models/home_stats.dart';

/// Keeps the last Home summary per user in memory so Home paints instantly
/// and refreshes in the background. Nothing is written to disk.
class HomeStatsCache {
  HomeStatsCache._();

  static const ttl = Duration(minutes: 2);

  static final _entries = <String, _Entry>{};

  static HomeStats? peek(String uid) => _entries[uid]?.stats;

  static bool isFresh(String uid, DateTime now) {
    final entry = _entries[uid];
    return entry != null && now.difference(entry.savedAt) < ttl;
  }

  static void put(String uid, HomeStats stats, DateTime now) {
    _entries[uid] = _Entry(stats, now);
  }

  /// Call after a scan is saved so the next Home load fetches fresh counts.
  static void invalidate(String uid) => _entries.remove(uid);

  /// Test helper.
  static void clear() => _entries.clear();
}

class _Entry {
  const _Entry(this.stats, this.savedAt);
  final HomeStats stats;
  final DateTime savedAt;
}
