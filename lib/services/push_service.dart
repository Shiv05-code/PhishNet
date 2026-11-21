import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../widgets/auth_widgets.dart';
import 'attention_state.dart';
import 'monitoring_service.dart';
import 'scan_service.dart';

/// Shared with MaterialApp so a notification tap can open Home from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Pushes for high-risk live-monitoring alerts only. Never shows email content.
class PushService {
  PushService._();

  static bool _started = false;
  static StreamSubscription<String>? _refreshSub;

  /// Fires when an alert arrives while the app is open. Home refreshes on it.
  static final StreamController<void> _alerts = StreamController<void>.broadcast();
  static Stream<void> get alerts => _alerts.stream;

  /// Updates the menu badge from any screen, not only Home.
  static Future<void> _refreshAttentionCount() async {
    try {
      final stats = await ScanService().getHomeStats();
      attentionCount.value = stats.attention48h;
    } catch (_) {
      // The badge catches up on the next Home load.
    }
  }

  static bool _isAlert(RemoteMessage message) => message.data['type'] == 'monitor_alert';

  /// Called once at startup. Handles taps on system notifications, including
  /// the app being opened from a terminated state.
  static Future<void> attachTapHandlers() async {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onTap(initial);
    } catch (e) {
      debugPrint('Push tap handler setup failed: ${e.runtimeType}');
    }
  }

  static void _onTap(RemoteMessage message) {
    if (!_isAlert(message)) return;
    // Only open Home for a signed-in user. Otherwise the alert shows next time.
    if (_currentUserOrNull() == null) return;
    _alerts.add(null);
    unawaited(_refreshAttentionCount());
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      fadeRoute(const HomeScreen()),
      (_) => false,
    );
  }

  static User? _currentUserOrNull() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Call once a Plus user is confirmed. Asks for permission and registers this device.
  static Future<void> start(MonitoringService monitor) async {
    if (kIsWeb || _started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;

      // Show the banner even when the app is open, so older users see the alert.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      if (token != null) await _register(monitor, token);
      _refreshSub ??= messaging.onTokenRefresh.listen((t) => _register(monitor, t));

      FirebaseMessaging.onMessage.listen((message) {
        if (_isAlert(message)) {
          _alerts.add(null);
          unawaited(_refreshAttentionCount());
        }
      });
    } catch (e) {
      // Push is a convenience. Failing here must never break Home.
      debugPrint('Push setup failed: ${e.runtimeType}');
    }
  }

  static Future<void> _register(MonitoringService monitor, String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await monitor.registerDevice(token, platform);
    } catch (e) {
      debugPrint('Device registration failed: ${e.runtimeType}');
    }
  }

  /// Background and terminated messages are shown by the system. Nothing to do here.
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {}
}
