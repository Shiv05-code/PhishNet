import 'package:flutter/material.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'app_colors.dart';
import 'family_social_screen.dart';
import 'ai_chat_screen.dart';


class ResultsScreen extends StatelessWidget {
  final bool isGuest;
  
  const ResultsScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    const riskColor = Color(0xFFD64545);
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
                          'This looks like a phishing attempt',
                          style: const TextStyle(
                            fontSize: AppTypography.title,
                            color: AppColors.primaryBlue,
                            height:  1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ScoreBadge(score: 85, color: riskColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'FishNet found several red flags in this message. '
                    'Be very careful',
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
                      'High Risk',
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                style: TextStyle(fontSize: AppTypography.emphasis + 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                style: TextStyle(fontSize: AppTypography.emphasis + 2),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            ),
            const SizedBox(height: 18),
            _SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.shield_outlined,
                      size: 44, color: AppColors.primaryBlue),
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
                        Text(
                          'Do not click on any links or reply to this message.',
                          style: TextStyle(
                            fontSize: AppTypography.body,
                            height: 1.35,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Why this might be a scam',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.title,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.error_outline,
                        size: 28, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Urgent Language',
                            style: TextStyle(
                              fontSize: AppTypography.emphasis,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Uses urgent words to pressure you into taking action.',
                            style: TextStyle(
                              fontSize: AppTypography.body,
                              height: 1.35,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.link, size: 28, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suspicious Link',
                            style: TextStyle(
                              fontSize: AppTypography.emphasis,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'The link goes to a domain known for phishing.',
                            style: TextStyle(
                              fontSize: AppTypography.body,
                              height: 1.35,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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