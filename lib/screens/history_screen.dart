import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'History screen — placeholder.\nRecent captures/chats/detections go here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
