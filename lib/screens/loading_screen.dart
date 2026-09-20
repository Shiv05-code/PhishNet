import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../widgets/swimming_fish.dart';
import '../theme/auth_theme.dart';
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