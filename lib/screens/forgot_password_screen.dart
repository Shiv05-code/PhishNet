import 'package:flutter/material.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot Password',
            textAlign: TextAlign.center,
            style: AuthTheme.heading,
          ),
          const SizedBox(height: 5),
          const Text(
            'Enter the email associated with your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SFProText',
              fontSize: 10,
              color: AuthTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 22),
          AuthField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: AuthArrowButton(
              semanticLabel: 'Send reset email',
              onPressed: () {
                Navigator.of(context).push(
                  fadeRoute(const VerificationScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 170),
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
