import 'package:flutter/material.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';
import '../models/scan_result.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'app_colors.dart';
import 'family_social_screen.dart';
import 'ai_chat_screen.dart';

class ResultsScreen extends StatelessWidget {
  final bool isGuest;
  final String message;
  final ScanResult? result;

  const ResultsScreen({
    super.key,
    this.isGuest = false,
    this.message = '',
    this.result,
  });

  static const _sample = ScanResult(
    riskLevel: 'high',
    summary:
        'PhishNet found several red flags in this message. Be very careful.',
    redFlags: [
      'Uses urgent words to pressure you into taking action.',
      'The link goes to a domain known for phishing.',
    ],
    redFlagLabels: ['Urgent Language', 'Suspicious Link'],
    redFlagIcons: ['schedule', 'link'],
    nextSteps: ['Do not click any links or reply to this message.'],
  );

  ScanResult get _r => result ?? _sample;

  IconData _iconFor(String name) => switch (name) {
    'payments' => Icons.payments_outlined,
    'lock' => Icons.lock_outline,
    'person' => Icons.person_outline,
    'schedule' => Icons.schedule,
    'link' => Icons.link,
    'person_search' => Icons.person_search,
    'currency_exchange' => Icons.currency_exchange,
    'attaach_file' => Icons.attach_file,
    'compare_arrows' => Icons.compare_arrows,
    _ => Icons.error_outline,
  };

  List<({String title, String details, IconData icon})> _flagViews() {
    return [
      for (var i = 0; i < _r.redFlags.length; i++)
        (
          title: (i < _r.redFlagLabels.length && _r.redFlagLabels[i].isNotEmpty)
              ? _r.redFlagLabels[i]
              : 'Warning sign ${i + 1}',
          details: _r.redFlags[i],
          icon: _iconFor(i < _r.redFlagIcons.length ? _r.redFlagIcons[i] : ''),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String riskLabel;
    final Color riskColor;
    switch (_r.riskLevel) {
      case 'high':
        headline = 'This looks like a phishing attempt';
        riskLabel = 'High Risk';
        riskColor = const Color(0xFFD64545);
      case 'medium':
        headline = 'This message may be a scam';
        riskLabel = 'Medium Risk';
        riskColor = const Color(0xFFE08A1E);
      default:
        headline = 'No strong warning signs found';
        riskLabel = 'Low Risk';
        riskColor = const Color(0xFF2E9E5B);
    }

    final flags = _flagViews();

    return Scaffold(
      appBar: const FigmaAppBar(title: 'Results'),
      drawer: AppDrawer(currentPage: 'Results', isGuest: isGuest),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          headline,
                          style: const TextStyle(
                            fontSize: AppTypography.title,
                            color: AppColors.primaryBlue,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (_r.scamPercentage != null || result == null) ...[
                        const SizedBox(width: 12),
                        _ScoreBadge(
                          score: _r.scamPercentage ?? 0,
                          color: riskColor,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _r.summary,
                    style: const TextStyle(
                      fontSize: AppTypography.body,
                      height: 1.35,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      riskLabel,
                      style: TextStyle(
                        fontSize: AppTypography.label,
                        fontWeight: FontWeight.w600,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Still unsure?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.title,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(fadeRoute(const FamilySocialScreen())),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share, size: 26),
                          SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Share with Family',
                                style: TextStyle(
                                  fontSize: AppTypography.emphasis + 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(fadeRoute(const AiChatScreen())),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, size: 26),
                          SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Ask PhishNet AI',
                                style: TextStyle(
                                  fontSize: AppTypography.emphasis + 2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What should you do?',
                          style: TextStyle(
                            fontSize: AppTypography.title,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        SizedBox(height: 8),
                        for (final step in _r.nextSteps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: AppTypography.body,
                                height: 1.35,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _r.riskLevel == 'low'
                  ? 'What we checked'
                  : 'Why this might be a scam',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.title,
              ),
            ),
            const SizedBox(height: 10),
            if (flags.isEmpty)
              const Text(
                'We did not find strong warning signs. Still, only click '
                'links or share information if you trust the sender.',
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: AppColors.text,
                ),
              )
            else
              for (final f in flags)
                _RedFlagTile(title: f.title, details: f.details, icon: f.icon),
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Risk score $score out of 100',
      child: ExcludeSemantics(
        child: Container(
          width: 86,
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 7),
          ),
          child: Text(
            '$score/100',
            style: TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _RedFlagTile extends StatelessWidget {
  const _RedFlagTile({
    required this.title,
    required this.details,
    required this.icon,
  });

  final String title;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, size: 28, color: AppColors.primaryBlue),
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.primaryBlue,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: AppTypography.emphasis,
            color: AppColors.primaryBlue,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details,
            style: const TextStyle(
              fontSize: AppTypography.body,
              height: 1.35,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
