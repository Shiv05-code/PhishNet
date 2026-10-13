import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/swimming_fish.dart';
import '../theme/auth_theme.dart';
import 'app_colors.dart';

class LoadingScreen extends StatefulWidget {
  final AuthService? authService;

  /// Clears the back stack when routing on (used when the app is reopened
  /// from the "email verified" web page on top of existing screens).
  final bool clearStack;

  const LoadingScreen({super.key, this.authService, this.clearStack = false});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _routeFromSession();
  }

  /// Keeps the splash visible for three seconds, then opens Home for a
  /// verified session or Login otherwise. Uses `replace` on this route so a
  /// deep link pushed on top during startup (e.g. Reset Password) survives.
  Future<void> _routeFromSession() async {
    final authService = widget.authService ?? AuthService();
    await Future.wait([
      Future<void>.delayed(const Duration(seconds: 3)),
      authService.refreshSession(),
    ]);
    if (!mounted) return;
    final Widget next = authService.hasVerifiedSession
        ? HomeScreen(authService: widget.authService)
        : LoginScreen(authService: widget.authService);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (widget.clearStack) {
      navigator.pushAndRemoveUntil(fadeRoute(next), (_) => false);
    } else if (route == null || route.isCurrent) {
      navigator.pushReplacement(fadeRoute(next));
    } else {
      navigator.replace(oldRoute: route, newRoute: fadeRoute(next));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        color: AppColors.screenBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/phishnet_logo.png',
                width: 155,
                height: 155,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your Shield Against Scams',
                style: TextStyle(
                  fontFamily: 'SFProText',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AuthTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 58),
              const SizedBox(
                width: 185,
                height: 185,
                child: SwimmingFish(size: 185),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
