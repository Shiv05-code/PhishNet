import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/session_timeout.dart';
import 'auth_widgets.dart';

/// Ends a signed-in session after [SessionTimeout.idleLimit] without taps,
/// and checks again whenever the app comes back to the foreground.
class SessionTimeoutGuard extends StatefulWidget {
  const SessionTimeoutGuard({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<SessionTimeoutGuard> createState() => _SessionTimeoutGuardState();
}

class _SessionTimeoutGuardState extends State<SessionTimeoutGuard>
    with WidgetsBindingObserver {
  /// Writing to storage on every tap would be wasteful, so activity is saved
  /// at most this often. The idle timer still resets on every tap.
  static const _saveInterval = Duration(seconds: 30);

  final _session = SessionTimeout();
  Timer? _idleTimer;
  DateTime? _lastSaved;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _idleTimer?.cancel();
      } else {
        _recordActivity();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOnResume();
    } else if (state == AppLifecycleState.paused) {
      // Save the time the app went to the background so a later cold start
      // can still tell how long it was idle.
      _lastSaved = null;
      _recordActivity();
    }
  }

  Future<void> _checkOnResume() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (await _session.hasExpired()) {
      await _endSession();
    } else {
      _recordActivity();
    }
  }

  void _recordActivity() {
    if (FirebaseAuth.instance.currentUser == null) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(SessionTimeout.idleLimit, _endSession);

    final now = DateTime.now();
    final last = _lastSaved;
    if (last == null || now.difference(last) >= _saveInterval) {
      _lastSaved = now;
      _session.markActive();
    }
  }

  Future<void> _endSession() async {
    _idleTimer?.cancel();
    if (FirebaseAuth.instance.currentUser == null) return;
    await _session.clear();
    await FirebaseAuth.instance.signOut();

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      instantRoute(
        LoginScreen(
          notice: 'You were signed out after 1 hour of inactivity.',
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      child: widget.child,
    );
  }
}
