import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final AuthService? authService;

  const ForgotPasswordScreen({super.key, this.initialEmail, this.authService});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _formKey = GlobalKey<FormState>();
  late final _authService = widget.authService ?? AuthService();
  bool _isSubmitting = false;
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) setState(() => _sentTo = email);
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _backToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        fadeRoute(LoginScreen(authService: widget.authService)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: AuthCard(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _sentTo == null ? _buildForm() : _buildConfirmation(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeader(
            icon: Icons.lock_reset,
            title: 'Forgot Password',
            subtitle:
                "Enter the email you signed up with and we'll send you a "
                'link to reset your password.',
          ),
          AuthField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            AuthStatusBanner(status: AuthStatus.error, message: _error!),
            const SizedBox(height: 12),
          ],
          AuthPrimaryButton(
            label: 'Send Reset Link',
            isLoading: _isSubmitting,
            onPressed: _sendResetEmail,
          ),
          const SizedBox(height: 16),
          Center(
            child: AuthLink(label: 'Back to Login', onTap: _backToLogin),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader(
          icon: Icons.mark_email_read_outlined,
          iconColor: AuthTheme.success,
          title: 'Check Your Email',
          subtitle:
              "If an account exists for $_sentTo, you'll get a reset link "
              "shortly. Not in your inbox? Check spam.",
        ),
        AuthPrimaryButton(label: 'Back to Login', onPressed: _backToLogin),
        const SizedBox(height: 14),
        Center(
          child: AuthLink(
            label: 'I have a reset link',
            onTap: () => Navigator.of(context).push(
              fadeRoute(ResetPasswordScreen(authService: widget.authService)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: AuthLink(
            label: 'Try a different email',
            onTap: () => setState(() => _sentTo = null),
          ),
        ),
      ],
    );
  }
}
