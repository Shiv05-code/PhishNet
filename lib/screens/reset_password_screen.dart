import 'package:flutter/material.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Reset Password', textAlign: TextAlign.center, style: AuthTheme.heading),
          const SizedBox(height: 5),
          const Text(
            'Create a new password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFProText',
              fontSize: 10,
              color: AuthTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 22),
          AuthField(
            label: 'New Password',
            hint: 'New Password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            onToggleObscure: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          const SizedBox(height: 10),
          AuthField(
            label: 'Confirm Password',
            hint: 'Confirm Password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            onToggleObscure: () {
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            },
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: AuthArrowButton(
              semanticLabel: 'Save new password',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 165),
          Center(
            child: AuthLink(
              label: 'Back to Login',
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
