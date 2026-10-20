import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../theme/app_typography.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'History'),
      drawer: const AppDrawer(currentPage: 'History'),
      body: FigmaGradientBackground(
        child: Center(
          child: Text(
            style: TextStyle(fontSize: AppTypography.emphasis),
            'History screen — placeholder.\nRecent captures/chats/detections go here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
