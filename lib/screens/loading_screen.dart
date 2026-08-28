import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../widgets/swimming_fish.dart';
import 'app_colors.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _goToLogin();
  }

  Future<void> _goToLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/phishnet_logo.png',
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 24),
            const Text(
              'PhishNet',
              style: TextStyle(
                fontFamily: 'SFProDisplay',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'POWERED BY PHISHERS',
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 11,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Your Shield Against Scams',
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.lightCyan,
              ),
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 220,
              height: 220,
              child: SwimmingFish(size: 220),
            ),
          ],
        ),
      ),
    );
  }
}