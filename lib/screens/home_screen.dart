import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';

class HomeScreen extends StatefulWidget {
  final AuthService? authService;

  const HomeScreen({super.key, this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _monitoring = false;

  void _toggleMonitoring() => setState(() => _monitoring = !_monitoring);

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.authService ?? AuthService()).firstName;
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
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _MonitoringCard(
              monitoring: _monitoring,
              onToggle: _toggleMonitoring
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

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.monitoring, required this.onToggle});
  final bool monitoring;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                monitoring ? Icons.shield : Icons.shield_outlined,
                size: 44,
                color: monitoring ? AppColors.primaryBlue : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitoring
                          ? 'Monitoring your inbox'
                          : 'Monitoring is off',
                      style: const TextStyle(
                        fontSize: AppTypography.emphasis,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Text(
                      'Yahoo inbox: not connected yet',
                      style: TextStyle(
                        fontSize: AppTypography.label,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (monitoring) ...[
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Last checked: sample',
                style: TextStyle(
                  fontSize: AppTypography.caption,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: monitoring
                ? OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text(
                      'Stop monitoring',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    onPressed: onToggle,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text(
                      'Start monitoring',
                      style: TextStyle(fontSize: AppTypography.emphasis),
                    ),
                  ),
          ),
        ],
      ),
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
