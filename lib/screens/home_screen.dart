import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Text(
              'Hello,',
              style: TextStyle(
                fontSize: AppTypography.heading,
                color: AppColors.primaryBlue,
              ),
            ),
            Text(
              firstName ?? 'there',
              style: const TextStyle(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '148',
                    label: 'Emails scanned in the past week',
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    value: '36',
                    label: 'Emails flagged',
                    color: AppColors.dangerRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '112',
                    label: 'Safe emails',
                    color: AppColors.accentGreen,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    value: '24%',
                    label: 'Phishing rate',
                    color: AppColors.cautionAmber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300B718E),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: AppTypography.title, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.label,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
