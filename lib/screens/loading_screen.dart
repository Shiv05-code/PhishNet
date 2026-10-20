import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/swimming_fish.dart';
import '../theme/auth_theme.dart';
import 'app_colors.dart';
import '../theme/app_typography.dart';

class LoadingScreen extends StatefulWidget {
  final AuthService? authService;

  /// Clears the back stack when routing on (used when the app is reopened
  /// from the "email verified" web page on top of existing screens).
  final bool clearStack;

  const LoadingScreen({super.key, this.authService, this.clearStack = false});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _routeFromSession();
  }

  /// Fades the splash in, holds one fish rotation, then fades the next page in
  /// over the still-visible splash (Home for a verified session, else Login). Uses `replace` on
  /// this route so a
  /// deep link pushed on top during startup (e.g. Reset Password) survives.
  Future<void> _routeFromSession() async {
    final authService = widget.authService ?? AuthService();
    await Future.wait([
      _fadeController.forward(),
      authService.refreshSession(),
      // Hold for one full fish rotation so the splash never cuts off early.
      Future<void>.delayed(const Duration(milliseconds: 3600)),
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
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Container(
        color: AppColors.screenBackground,
        child: FadeTransition(
          opacity: _fadeController,
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
                    fontSize: AppTypography.heading,
                    fontWeight: FontWeight.bold,
                    color: AuthTheme.secondaryText,
                  ),
                ),
                const SizedBox(height: 58),
                SizedBox(
                  width: 185,
                  height: 185,
                  child: SwimmingFish(size: 185),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
