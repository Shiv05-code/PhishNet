import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the inbox connection and monitoring switch per account, so a
/// user who turned monitoring on still sees it on after restarting the app.
class MonitoringPrefs {
  MonitoringPrefs._();

  static String _connectedKey(String uid) => 'inbox_connected_$uid';
  static String _monitoringKey(String uid) => 'monitoring_on_$uid';

  static Future<MonitoringState> load(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return MonitoringState(
        connected: prefs.getBool(_connectedKey(uid)) ?? false,
        monitoring: prefs.getBool(_monitoringKey(uid)) ?? false,
      );
    } catch (_) {
      return const MonitoringState(connected: false, monitoring: false);
    }
  }

  static Future<void> save(String uid, MonitoringState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey(uid), state.connected);
      await prefs.setBool(_monitoringKey(uid), state.monitoring);
    } catch (_) {
      // Storage is a convenience; the screen still works without it.
    }
  }
}

class MonitoringState {
  const MonitoringState({required this.connected, required this.monitoring});
  final bool connected;
  final bool monitoring;
}
