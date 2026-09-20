import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_app_bar.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/figma_glass_button.dart';
import '../widgets/auth_widgets.dart';
import 'app_colors.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'payment_plan_screen.dart';
import 'privacy_policy_screen.dart';
import 'signup_screen.dart';
import 'terms_conditions_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool isGuest;

  const SettingsScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FigmaAppBar(title: 'Settings'),
      drawer: AppDrawer(currentPage: 'Settings', isGuest: isGuest),
      body: FigmaGradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const _ProfileAvatar(),
                  const SizedBox(height: 26),
                  _settingButton(
                    context,
                    'Delete My Data',
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      fadeRoute(const SignupScreen()),
                      (_) => false,
                    ),
                  ),
                  _settingButton(
                    context,
                    'Terms & Conditions',
                    onPressed: () => Navigator.of(context).push(
                      fadeRoute(const TermsConditionsScreen()),
                    ),
                  ),
                  _settingButton(
                    context,
                    'Privacy Policy',
                    onPressed: () => Navigator.of(context).push(
                      fadeRoute(const PrivacyPolicyScreen()),
                    ),
                  ),
                  _settingButton(
                    context,
                    'Payment Plan',
                    onPressed: () => Navigator.of(context).push(
                      fadeRoute(const PaymentPlanScreen()),
                    ),
                  ),
                  _settingButton(
                    context,
                    'Change Password',
                    enabled: !isGuest,
                    onPressed: isGuest
                        ? null
                        : () => Navigator.of(context).push(
                            fadeRoute(const ForgotPasswordScreen()),
                          ),
                  ),
                  const SizedBox(height: 8),
                  FigmaGlassButton(
                    width: 170,
                    height: 54,
                    semanticLabel: 'Log out',
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      instantRoute(const LoginScreen()),
                      (_) => false,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout,
                          size: 28,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingButton(
    BuildContext context,
    String label, {
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: FigmaGlassButton(
            width: 250,
            height: 54,
            semanticLabel: label,
            onPressed: onPressed ?? () {},
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.primaryBlue : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xBDE6F6FC),
        border: Border.all(color: Colors.white70, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x350B718E),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        size: 92,
        color: Color(0xFFFDFCF9),
      ),
    );
  }
}
