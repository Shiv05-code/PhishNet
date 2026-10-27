import 'package:flutter/material.dart';
import 'package:phishnet_app/widgets/auth_widgets.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';
import 'family_social_screen.dart';
import 'ai_chat_screen.dart';

class ResultsScreen extends StatelessWidget {
  final bool isGuest;

  const ResultsScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Results'),
      drawer: AppDrawer(currentPage: 'Results', isGuest: isGuest),
      body: FigmaGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.red.shade50,
              child: const ListTile(
                leading: Icon(Icons.cancel, color: Colors.red),
                title: Text(
                  'Scam Detected',
                  style: TextStyle(fontSize: AppTypography.emphasis),
                ),
                subtitle: Text(
                  '85% confidence',
                  style: TextStyle(fontSize: AppTypography.body),
                ),
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
            const SizedBox(height: 16),
            const Text(
              'Why this might be a scam',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.title,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(
                  labelStyle: TextStyle(fontSize: AppTypography.label),
                  label: Text('Unknown Sender'),
                ),
                Chip(
                  labelStyle: TextStyle(fontSize: AppTypography.label),
                  label: Text('Urgent Language'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'What should you do?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.title,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              children: [
                Chip(
                  labelStyle: TextStyle(fontSize: AppTypography.label),
                  label: Text('Do Not Click Links'),
                ),
                Chip(
                  labelStyle: TextStyle(fontSize: AppTypography.label),
                  label: Text('Block Sender'),
                ),
                Chip(
                  labelStyle: TextStyle(fontSize: AppTypography.label),
                  label: Text('Report Message'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
