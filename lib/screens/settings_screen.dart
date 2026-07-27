import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: ListView(
        children: const [
          ListTile(title: Text('Delete my Data')),
          ListTile(title: Text('Accessibility')),
          ListTile(title: Text('Terms & Conditions')),
          ListTile(title: Text('Change Password')),
        ],
      ),
    );
  }
}
