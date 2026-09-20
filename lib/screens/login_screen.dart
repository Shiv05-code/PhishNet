import 'package:flutter/material.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'capture_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continueToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const HomeScreen()),
      (_) => false,
    );
  }

  void _continueAsGuest() {
    Navigator.of(context).pushReplacement(
      fadeRoute(const CaptureScreen(isGuest: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Login', textAlign: TextAlign.center, style: AuthTheme.heading),
            const SizedBox(height: 12),
            AuthField(
              label: 'Email',
              hint: 'Enter your email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            AuthField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              onToggleObscure: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AuthLink(
                  label: 'Forgot Password?',
                  onTap: () {
                    Navigator.of(context).push(
                      fadeRoute(const ForgotPasswordScreen()),
                    );
                  },
                ),
                AuthArrowButton(
                  onPressed: _continueToApp,
                  semanticLabel: 'Sign in',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: AuthLink(
                label: 'Continue as guest',
                onTap: _continueAsGuest,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'New here? ',
                  style: TextStyle(fontFamily: 'SFProText', fontSize: 10),
                ),
                AuthLink(
                  label: 'Create account',
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      fadeRoute(const SignupScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
