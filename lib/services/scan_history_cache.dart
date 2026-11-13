import '../models/saved_scan.dart';

class ScanHistoryCache {
  ScanHistoryCache._();

  static final ScanHistoryCache instance = ScanHistoryCache._();

  static const Duration maxAge = Duration(seconds: 60);
  final Map<String, int> _revisions = {};

  int revision(String uid) => _revisions[uid] ?? 0;

  void _advanceRevision(String uid) {
    _revisions[uid] = revision(uid) + 1;
  }

  final Map<String, _CachedHistory> _entries = {};

  List<SavedScan>? get(String uid) {
    final entry = _entries[uid];
    if (entry == null) return null;

    return List<SavedScan>.unmodifiable(entry.scans);
  }

  bool isFresh(String uid) {
    final entry = _entries[uid];
    if (entry == null) return false;

    return DateTime.now().difference(entry.cachedAt) < maxAge;
  }

  void save(String uid, List<SavedScan> scans) {
    _entries[uid] = _CachedHistory(
      scans: List<SavedScan>.unmodifiable(scans),
      cachedAt: DateTime.now(),
    );
  }

  void clear(String uid) {
    _advanceRevision(uid);
    _entries.remove(uid);
  }

  void clearAll() {
    for (final uid in {..._entries.keys, ..._revisions.keys}) {
      _advanceRevision(uid);
    }

    _entries.clear();
  }
}

class _CachedHistory {
  const _CachedHistory({required this.scans, required this.cachedAt});

  final List<SavedScan> scans;
  final DateTime cachedAt;
}
