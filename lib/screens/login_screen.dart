import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'capture_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueToApp() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isSubmitting = true);
    try {
      await _authService.signIn(email: email, password: password);
      if (!mounted) return;
      final user = _authService.currentUser;
      if (user != null && !user.emailVerified) {
        Navigator.of(
          context,
        ).pushReplacement(fadeRoute(EmailVerificationScreen(email: email)));
        return;
      }
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeRoute(const HomeScreen()), (_) => false);
    } catch (error) {
      if (mounted) _showMessage(AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _continueAsGuest() {
    Navigator.of(
      context,
    ).pushReplacement(fadeRoute(const CaptureScreen(isGuest: true)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Login',
                textAlign: TextAlign.center,
                style: AuthTheme.heading,
              ),
              const SizedBox(height: 12),
              AuthField(
                label: 'Email',
                hint: 'Enter your email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Enter your email.';
                  return null;
                },
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
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Enter your password.';
                  return null;
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
                      Navigator.of(
                        context,
                      ).push(fadeRoute(const ForgotPasswordScreen()));
                    },
                  ),
                  AuthArrowButton(
                    onPressed: _isSubmitting ? () {} : _continueToApp,
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
                      Navigator.of(
                        context,
                      ).pushReplacement(fadeRoute(const SignupScreen()));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
