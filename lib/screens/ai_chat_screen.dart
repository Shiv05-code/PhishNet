import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'AI Chat screen — placeholder.\nChat UI goes here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
