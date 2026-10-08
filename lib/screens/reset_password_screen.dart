import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auth_validation.dart';
import '../services/reset_link.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

/// Shown when the pasted text isn't a PhishNet password-reset link.
const invalidResetLinkMessage = 'This reset link isn\'t valid.';

enum _ResetStage { needsLink, verifying, invalid, form, success }

/// Applies a Firebase password reset. Opened from the reset email link
/// (see `parseResetCode`) with [oobCode], or without one so the user can
/// paste the link manually.
class ResetPasswordScreen extends StatefulWidget {
  final String? oobCode;
  final AuthService? authService;

  const ResetPasswordScreen({super.key, this.oobCode, this.authService});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _linkController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _authService = widget.authService ?? AuthService();
  _ResetStage _stage = _ResetStage.needsLink;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _code;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.oobCode != null) _verify(widget.oobCode!);
  }

  @override
  void dispose() {
    _linkController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _stage = _ResetStage.verifying;
      _error = null;
    });
    try {
      final email = await _authService.verifyPasswordResetCode(code);
      if (!mounted) return;
      setState(() {
        _code = code;
        _email = email;
        _stage = _ResetStage.form;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.messageFor(error);
        if (_isLinkError(error)) {
          _stage = _ResetStage.invalid;
        } else {
          // Keep the code so the user can retry (e.g. after a network error).
          _linkController.text = code;
          _stage = _ResetStage.needsLink;
        }
      });
    }
  }

  bool _isLinkError(Object error) =>
      error is FirebaseAuthException &&
      (error.code == 'expired-action-code' ||
          error.code == 'invalid-action-code');

  void _submitLink() {
    final code = parseResetCode(_linkController.text);
    if (code == null) {
      setState(() => _error = invalidResetLinkMessage);
      return;
    }
    _verify(code);
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _authService.confirmPasswordReset(
        code: _code!,
        newPassword: _passwordController.text,
      );
      if (mounted) setState(() => _stage = _ResetStage.success);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.messageFor(error);
        if (_isLinkError(error)) _stage = _ResetStage.invalid;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToLogin({String? notice}) {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(
        LoginScreen(
          initialEmail: _email,
          notice: notice,
          authService: widget.authService,
        ),
      ),
      (_) => false,
    );
  }

  void _requestNewLink() {
    Navigator.of(context).pushReplacement(
      fadeRoute(
        ForgotPasswordScreen(
          initialEmail: _email,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_stage) {
      _ResetStage.needsLink => _needsLink(),
      _ResetStage.verifying => _verifying(),
      _ResetStage.invalid => _invalid(),
      _ResetStage.form => _form(),
      _ResetStage.success => _success(),
    };
    return AuthPage(
      child: Column(
        children: [
          const AuthBrandHeader(),
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...content,
                if (_stage != _ResetStage.success) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: AuthLink(label: 'Back to Login', onTap: _goToLogin),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _errorBanner() => [
    if (_error != null) ...[
      AuthStatusBanner(status: AuthStatus.error, message: _error!),
      const SizedBox(height: 12),
    ],
  ];

  List<Widget> _needsLink() => [
    const AuthHeader(
      icon: Icons.link,
      title: 'Reset Password',
      subtitle:
          'Open the reset link from your email on this phone, or paste it '
          'below.',
    ),
    AuthField(
      label: 'Reset Link',
      hint: 'Paste the link from your email',
      controller: _linkController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
    ),
    const SizedBox(height: 18),
    ..._errorBanner(),
    AuthPrimaryButton(label: 'Continue', onPressed: _submitLink),
  ];

  List<Widget> _verifying() => [
    const AuthHeader(
      icon: Icons.lock_clock,
      title: 'Checking Your Link',
      subtitle: 'One moment while we confirm your reset link…',
    ),
    const Center(child: CircularProgressIndicator()),
  ];

  List<Widget> _invalid() => [
    const AuthHeader(
      icon: Icons.link_off,
      iconColor: AuthTheme.error,
      title: 'Link Expired',
      subtitle:
          'Reset links work once and expire after about an hour. '
          'Request a new one to continue.',
    ),
    ..._errorBanner(),
    AuthPrimaryButton(label: 'Request New Link', onPressed: _requestNewLink),
  ];

  List<Widget> _form() => [
    AuthHeader(
      icon: Icons.lock_reset,
      title: 'Create New Password',
      subtitle: _email == null ? null : 'For $_email',
    ),
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'New Password',
            hint: 'Enter a new password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            onToggleObscure: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: validateSignupPassword,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            'At least 8 characters with a letter, number, and symbol.',
            style: AuthTheme.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          AuthField(
            label: 'Confirm Password',
            hint: 'Re-enter your new password',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            onToggleObscure: () {
              setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              );
            },
            validator: (value) =>
                validateConfirmPassword(value, _passwordController.text),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    ..._errorBanner(),
    AuthPrimaryButton(
      label: 'Save New Password',
      isLoading: _isSubmitting,
      onPressed: _savePassword,
    ),
  ];

  List<Widget> _success() => [
    const AuthHeader(
      icon: Icons.check_circle_outline,
      iconColor: AuthTheme.success,
      title: 'Password Updated',
      subtitle: 'You can now log in with your new password.',
    ),
    AuthPrimaryButton(
      label: 'Go to Login',
      onPressed: () => _goToLogin(
        notice: 'Password updated. Log in with your new password.',
      ),
    ),
  ];
}
