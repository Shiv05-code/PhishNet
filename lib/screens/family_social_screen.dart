import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';

class FamilySocialScreen extends StatelessWidget {
  const FamilySocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Family/Social'),
      drawer: const AppDrawer(currentPage: 'Family/Social'),
      body: FigmaGradientBackground(
        child: const Center(
          child: Text(
          'Family/Social screen — placeholder.\nContacts list goes here.',
          textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
