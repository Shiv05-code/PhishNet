import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../theme/app_typography.dart';
import 'auth_widgets.dart';

enum _GuestChoice { login, signup }

Future<void> showGuestPrompt(
  BuildContext context, {
  String feature = 'this feature',
}) async {
  final choice = await showDialog<_GuestChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Account needed',
        style: TextStyle(
          fontSize: AppTypography.title,
          color: AppColors.primaryBlue,
        ),
      ),
      content: Text(
        'Log in or create a new account to use $feature.',
        style: const TextStyle(fontSize: AppTypography.body, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(_GuestChoice.login),
          child: const Text('Login'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(_GuestChoice.signup),
          child: const Text('Sign Up'),
        ),
      ],
    ),
  );

  if (!context.mounted || choice == null) return;
  Navigator.of(context).push(
    fadeRoute(
      choice == _GuestChoice.login ? const LoginScreen() : const SignupScreen(),
    ),
  );
}
