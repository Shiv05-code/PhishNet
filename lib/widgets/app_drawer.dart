import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../screens/capture_screen.dart';
import '../screens/results_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/family_social_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/login_screen.dart';

/// Drawer matching the mockup — light-blue background, plain-text menu
/// items (no icons except Settings/Logout), hamburger toggle inside the
/// drawer itself (top-right) to close it.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Widget _menuItem(BuildContext context, String label, Widget screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _navigate(context, screen),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            color: AppColors.black,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.highlight,
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hamburger icon top-right, closes the drawer.
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 12),
              _menuItem(context, 'Capture', const CaptureScreen()),
              _menuItem(context, 'Results', const ResultsScreen()),
              _menuItem(context, 'AI Chat', const AiChatScreen()),
              _menuItem(context, 'Family/Social', const FamilySocialScreen()),
              _menuItem(context, 'History', const HistoryScreen()),
              _menuItem(context, 'Analytics', const AnalyticsScreen()),
              const Spacer(),
              InkWell(
                onTap: () => _navigate(context, const SettingsScreen()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: AppColors.black),
                      SizedBox(width: 10),
                      Text('Settings',
                          style: TextStyle(fontSize: 18, color: AppColors.black)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _navigate(context, const LoginScreen()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: AppColors.black),
                      SizedBox(width: 10),
                      Text('Logout',
                          style: TextStyle(fontSize: 18, color: AppColors.black)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
