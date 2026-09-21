import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      if (await _authService.refreshEmailVerification()) {
        await _authService.signOut();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushAndRemoveUntil(fadeRoute(const LoginScreen()), (_) => false);
        return;
      }
      if (mounted) {
        _showMessage(
          'Your email is not verified yet. Check your inbox and try again.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendVerificationEmail();
      if (mounted) _showMessage('A new verification email was sent.');
    } catch (error) {
      if (mounted) _showMessage(AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backToLogin() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadeRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Check Your Email',
              textAlign: TextAlign.center,
              style: AuthTheme.heading,
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a verification link to ${widget.email}. '
              'Open it, then return here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                color: AuthTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: AuthArrowButton(
                onPressed: (_isChecking || _isResending)
                    ? null
                    : _checkVerification,
                semanticLabel: 'Check email verification',
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Tap the arrow after verifying your email.',
                      style: TextStyle(fontSize: 10, color: AuthTheme.muted),
                    ),
            ),
            const SizedBox(height: 20),
            Center(
              child: AuthLink(
                label: _isResending ? 'Sending...' : 'Resend Email',
                onTap: (_isChecking || _isResending)
                    ? () {}
                    : _resendVerification,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: AuthLink(
                label: 'Back to Login',
                onTap: () {
                  _backToLogin();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
