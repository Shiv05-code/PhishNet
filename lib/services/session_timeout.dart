import 'package:shared_preferences/shared_preferences.dart';

/// Signs a user out after a period with no activity in the app.
///
/// Firebase keeps a session signed in until it is explicitly ended, so this
/// records the last time the user interacted with the app. The timestamp is
/// stored on the device so a session also expires across app restarts.
class SessionTimeout {
  /// How long the app can sit idle before the session ends.
  static const idleLimit = Duration(minutes: 60);

  static const _lastActiveKey = 'session_last_active_ms';

  /// Records that the user is active right now.
  Future<void> markActive() => _write(DateTime.now());

  /// Forgets the stored activity time, e.g. after sign-out.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastActiveKey);
    } catch (_) {
      // Storage is best-effort; a missing timestamp just means no expiry.
    }
  }

  /// True when the last recorded activity is older than [idleLimit].
  /// With no record, the session is treated as not expired.
  Future<bool> hasExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActive = prefs.getInt(_lastActiveKey);
      if (lastActive == null) return false;
      final idle = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastActive),
      );
      return idle > idleLimit;
    } catch (_) {
      return false;
    }
  }

  Future<void> _write(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastActiveKey, at.millisecondsSinceEpoch);
    } catch (_) {
      // Ignored for the same reason as above.
    }
  }
}
