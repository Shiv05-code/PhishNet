import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'AI Chat'),
      drawer: const AppDrawer(currentPage: 'AI Chat'),
      body: FigmaGradientBackground(
        child: const Center(
          child: Text(
          'AI Chat screen — placeholder.\nChat UI goes here.',
          textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
