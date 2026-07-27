import 'package:flutter/material.dart';
import '../screens/capture_screen.dart';
import '../screens/results_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/family_social_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/login_screen.dart';

/// The hamburger-menu drawer shown on every main screen once logged in.
/// Matches the menu items from the IA diagram:
/// Capture, Results, AI Chat, Family/Social, History, Analytics, Settings.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close the drawer first
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: Colors.indigo),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'PhishNet',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Capture'),
                    onTap: () => _navigate(context, const CaptureScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Results'),
                    onTap: () => _navigate(context, const ResultsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: const Text('AI Chat'),
                    onTap: () => _navigate(context, const AiChatScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Family/Social'),
                    onTap: () => _navigate(context, const FamilySocialScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('History'),
                    onTap: () => _navigate(context, const HistoryScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_outlined),
                    title: const Text('Analytics'),
                    onTap: () => _navigate(context, const AnalyticsScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _navigate(context, const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log Out'),
              onTap: () => _navigate(context, const LoginScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
