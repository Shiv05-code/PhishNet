import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'Analytics screen — placeholder.\nStats chart + learning outcomes go here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
