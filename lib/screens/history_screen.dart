import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'History'),
      drawer: const AppDrawer(currentPage: 'History'),
      body: FigmaGradientBackground(
        child: const Center(
          child: Text(
          'History screen — placeholder.\nRecent captures/chats/detections go here.',
          textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
