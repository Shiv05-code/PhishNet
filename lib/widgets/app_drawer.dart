import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../screens/capture_screen.dart';
import '../screens/home_screen.dart';
import '../screens/results_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/family_social_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/login_screen.dart';
import 'auth_widgets.dart';
import 'figma_gradient_background.dart';

/// Drawer matching the mockup — light-blue background, plain-text menu
/// items (no icons except Settings/Logout), hamburger toggle inside the
/// drawer itself (top-right) to close it.
class AppDrawer extends StatelessWidget {
  final String currentPage;
  final bool isGuest;

  const AppDrawer({super.key, required this.currentPage, this.isGuest = false});

  void _navigate(BuildContext context, String label, Widget screen) {
    Navigator.of(context).pop();
    if (label == currentPage) return;
    Navigator.of(context).pushReplacement(fadeRoute(screen));
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).pushAndRemoveUntil(instantRoute(const LoginScreen()), (_) => false);
  }

  Widget _menuItem(
    BuildContext context,
    String label,
    Widget screen, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? () => _navigate(context, label, screen) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: enabled ? AppColors.primary : AppColors.muted,
              fontFamily: 'monospace',
              shadows: enabled
                  ? const [
                      Shadow(
                        color: Color(0x30000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: FigmaGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListView(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const SizedBox(
                      width: 46,
                      height: 38,
                      child: CustomPaint(painter: _FigmaMenuPainter()),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 12),
                _menuItem(
                  context,
                  'Home',
                  const HomeScreen(),
                  enabled: !isGuest,
                ),
                _menuItem(context, 'Capture', CaptureScreen(isGuest: isGuest)),
                _menuItem(context, 'Results', ResultsScreen(isGuest: isGuest)),
                _menuItem(
                  context,
                  'AI Chat',
                  const AiChatScreen(),
                  enabled: !isGuest,
                ),
                _menuItem(
                  context,
                  'Family/Social',
                  const FamilySocialScreen(),
                  enabled: !isGuest,
                ),
                _menuItem(
                  context,
                  'History',
                  const HistoryScreen(),
                  enabled: !isGuest,
                ),
                const Divider(color: Color(0x6681B9CC)),
                InkWell(
                  onTap: () => _navigate(
                    context,
                    'Settings',
                    SettingsScreen(isGuest: isGuest),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: AppColors.primary,
                          shadows: [
                            Shadow(
                              color: Color(0x40000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            shadows: [
                              Shadow(
                                color: Color(0x30000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _openLogin(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isGuest ? Icons.login : Icons.logout,
                          color: AppColors.primary,
                          shadows: [
                            Shadow(
                              color: Color(0x40000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        Text(
                          isGuest ? 'Login' : 'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            shadows: [
                              Shadow(
                                color: Color(0x30000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaMenuPainter extends CustomPainter {
  const _FigmaMenuPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (final y in [6.0, 19.0, 32.0]) {
      canvas.drawLine(
        Offset(3, y + 2),
        Offset(size.width - 2, y + 2),
        shadowPaint,
      );
      canvas.drawLine(Offset(3, y), Offset(size.width - 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FigmaMenuPainter oldDelegate) => false;
}
