import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';

class HomeScreen extends StatelessWidget {
  final AuthService? authService;

  const HomeScreen({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    final firstName = (authService ?? AuthService()).firstName;
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: const FigmaAppBar(title: 'Home'),
      drawer: const AppDrawer(currentPage: 'Home'),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Text(
              firstName == null ? 'Hello there' : 'Hello, $firstName',
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stay protected from scams.',
              style: TextStyle(
                fontFamily: 'SFProDisplay',
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 22),
            Card(
              elevation: 3,
              shadowColor: const Color(0x26000000),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Use Capture to check a suspicious message, link, or email.',
                  style: TextStyle(
                    fontFamily: 'SFProText',
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
