import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_stats.dart';

/// Keeps each user's last Home summary in memory and on disk for fast startup.
class HomeStatsCache {
  HomeStatsCache._();

  static const ttl = Duration(minutes: 2);
  static const _maxStaleAge = Duration(days: 7);
  static const _keyPrefix = 'home_stats_v1_';

  static final _entries = <String, _Entry>{};

  static HomeStats? peek(String uid) => _entries[uid]?.stats;

  static bool isFresh(String uid, DateTime now) {
    final entry = _entries[uid];
    if (entry == null) return false;
    final age = now.difference(entry.savedAt);
    return age >= Duration.zero && age < ttl;
  }

  static Future<HomeStats?> restore(String uid) async {
    final cached = peek(uid);
    if (cached != null) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('$_keyPrefix$uid');
      if (encoded == null) return null;

      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['saved_at'] is! String ||
          decoded['stats'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid cached Home stats');
      }

      final savedAt = DateTime.tryParse(decoded['saved_at'] as String);
      if (savedAt == null) {
        throw const FormatException('Invalid cached Home stats timestamp');
      }
      final age = DateTime.now().difference(savedAt);
      if (age < Duration.zero || age > _maxStaleAge) {
        await prefs.remove('$_keyPrefix$uid');
        return null;
      }

      final stats = HomeStats.fromJson(
        decoded['stats'] as Map<String, dynamic>,
      );
      _entries[uid] = _Entry(stats, savedAt);
      return stats;
    } on FormatException catch (error) {
      debugPrint('Discarding invalid cached Home stats: $error');
      await _remove(uid);
      return null;
    } catch (error) {
      debugPrint('Home stats cache restore failed: $error');
      return null;
    }
  }

  static Future<void> put(String uid, HomeStats stats, DateTime now) async {
    _entries[uid] = _Entry(stats, now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_keyPrefix$uid',
        jsonEncode({
          'saved_at': now.toIso8601String(),
          'stats': stats.toJson(),
        }),
      );
    } catch (error) {
      debugPrint('Home stats cache save failed: $error');
    }
  }

  /// Call after a scan is saved so the next Home load fetches fresh counts.
  static void invalidate(String uid) => _entries.remove(uid);

  /// Clears the in-memory cache for tests.
  static void clear() => _entries.clear();

  static Future<void> _remove(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$uid');
    } catch (error) {
      debugPrint('Home stats cache cleanup failed: $error');
    }
  }
}

class _Entry {
  const _Entry(this.stats, this.savedAt);
  final HomeStats stats;
  final DateTime savedAt;
}
