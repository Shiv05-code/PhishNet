import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _isSubmitting = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) setState(() => _emailSent = true);
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

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: Form(
        key: _formKey,
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
              textInputAction: TextInputAction.done,
              validator: _validateEmail,
            ),
            const SizedBox(height: 18),
            if (_emailSent)
              const Text(
                'If an account exists for this email, a password reset link '
                'has been sent. Check your inbox and spam folder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SFProText',
                  fontSize: 11,
                  color: AuthTheme.secondaryText,
                ),
              )
            else
              Align(
                alignment: Alignment.center,
                child: AuthArrowButton(
                  semanticLabel: 'Send reset email',
                  onPressed: _isSubmitting ? null : _sendResetEmail,
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
      ),
    );
  }
}
