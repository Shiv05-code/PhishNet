import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import '../widgets/auth_widgets.dart';
import 'capture_screen.dart';

class _FlaggedEmail {
  const _FlaggedEmail(this.subject, this.from, this.score);
  final String subject;
  final String from;
  final int score;
}

const _sampleFlagged = [
  _FlaggedEmail(
    'Account Suspended - Action Required',
    'security@yah00-support.com',
    81,
  ),
  _FlaggedEmail(
    "Congrats! You've won the giveaway",
    'rewards@prize-now.net',
    97,
  ),
];

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
              onToggle: _toggleMonitoring,
            ),
            const SizedBox(height: 16),
            if (_monitoring) ...[
              const _AttentionCard(emails: _sampleFlagged),
              const SizedBox(height: 16),
            ],
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
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(
                  context,
                ).push(fadeRoute(const CaptureScreen())),
                icon: const Icon(Icons.content_paste),
                label: const Text(
                  'Check something manually',
                  style: TextStyle(fontSize: AppTypography.emphasis),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xD9FDFCF9),
        borderRadius: BorderRadius.circular(22),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.2),
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
                'Last checked: 5 minutes ago',
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

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.emails});
  final List<_FlaggedEmail> emails;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      borderColor: AppColors.dangerRed.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread, color: AppColors.dangerRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${emails.length} emails need your attention',
                  style: const TextStyle(
                    fontSize: AppTypography.emphasis,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in emails) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x80FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x330B718E)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${e.subject}"',
                          style: const TextStyle(
                            fontSize: AppTypography.body,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${e.from}',
                          style: const TextStyle(
                            fontSize: AppTypography.caption,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Risk score ${e.score} percent',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${e.score}%',
                        style: const TextStyle(
                          fontSize: AppTypography.caption,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
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
