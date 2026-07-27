import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../widgets/swimming_fish.dart';

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
    await Future.delayed(const Duration(seconds: 2, milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Light blue background matching the mockup.
      backgroundColor: const Color(0xFFEAF1FB),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Real logo asset — circular, transparent background.
            Image.asset(
              'assets/images/phishnet_logo.png',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 20),
            const Text(
              'PhishNet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Shield Against Scams',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 50),
            // Swimming fish loading animation, replacing the generic spinner.
            const SwimmingFish(width: 220),
          ],
        ),
      ),
    );
  }
}
