import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final AuthService? authService;

  /// Seconds the user must wait between resend requests.
  static const resendCooldown = 60;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.authService,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final _authService = widget.authService ?? AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  bool _verified = false;
  int _cooldown = EmailVerificationScreen.resendCooldown;
  Timer? _timer;
  AuthStatusBanner? _banner;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = EmailVerificationScreen.resendCooldown;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _show(AuthStatus status, String message) {
    setState(
      () => _banner = AuthStatusBanner(status: status, message: message),
    );
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      if (await _authService.refreshEmailVerification()) {
        _timer?.cancel();
        setState(() {
          _verified = true;
          _banner = null;
        });
        return;
      }
      _show(
        AuthStatus.error,
        "We couldn't confirm your email yet. Open the link in the email we "
        'sent, then try again.',
      );
    } catch (error) {
      if (mounted) _show(AuthStatus.error, AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendVerificationEmail();
      if (!mounted) return;
      _show(AuthStatus.success, 'A new verification email is on its way.');
      _startCooldown();
    } catch (error) {
      if (mounted) _show(AuthStatus.error, AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _continueToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(HomeScreen(authService: widget.authService)),
      (_) => false,
    );
  }

  Future<void> _backToLogin() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(
        LoginScreen(
          initialEmail: widget.email,
          authService: widget.authService,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: Column(
        children: [
          const AuthBrandHeader(),
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VerificationProgress(verified: _verified),
                const SizedBox(height: 20),
                if (_verified) ..._successContent() else ..._pendingContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _successContent() => [
    const AuthHeader(
      icon: Icons.verified_user,
      iconColor: AuthTheme.success,
      title: 'Email Verified',
      subtitle: 'Your account is ready. Welcome to PhishNet!',
    ),
    AuthPrimaryButton(
      label: 'Continue to PhishNet',
      onPressed: _continueToHome,
    ),
  ];

  List<Widget> _pendingContent() {
    final busy = _isChecking || _isResending;
    return [
      const AuthHeader(
        icon: Icons.mark_email_unread_outlined,
        title: 'Check Your Email',
        subtitle: 'We sent a verification link to',
      ),
      Transform.translate(
        offset: const Offset(0, -12),
        child: Text(
          widget.email,
          textAlign: TextAlign.center,
          style: AuthTheme.label.copyWith(fontSize: 17),
        ),
      ),
      const _Step(number: 1, text: 'Open the email from PhishNet.'),
      const _Step(number: 2, text: 'Tap the verification link.'),
      const _Step(number: 3, text: 'Come back here and tap the button below.'),
      const SizedBox(height: 14),
      if (_banner != null) ...[_banner!, const SizedBox(height: 14)],
      AuthPrimaryButton(
        label: "I've Verified My Email",
        isLoading: _isChecking,
        onPressed: busy ? null : _checkVerification,
      ),
      const SizedBox(height: 14),
      Center(
        child: _cooldown > 0
            ? Text(
                'Didn\'t get it? Check spam, or resend in ${_cooldown}s',
                textAlign: TextAlign.center,
                style: AuthTheme.body.copyWith(
                  fontSize: 14,
                  color: AuthTheme.muted,
                ),
              )
            : AuthLink(
                label: _isResending ? 'Sending...' : 'Resend Email',
                onTap: busy ? () {} : _resendVerification,
              ),
      ),
      const SizedBox(height: 8),
      Center(
        child: AuthLink(label: 'Back to Login', onTap: _backToLogin),
      ),
    ];
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AuthTheme.infoFill,
            child: Text(
              '$number',
              style: AuthTheme.label.copyWith(
                fontSize: 14,
                color: AuthTheme.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AuthTheme.body.copyWith(color: AuthTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-stage indicator: Account created → Verify email → Ready.
class _VerificationProgress extends StatelessWidget {
  final bool verified;

  const _VerificationProgress({required this.verified});

  @override
  Widget build(BuildContext context) {
    final stages = ['Account', 'Verify', 'Ready'];
    final current = verified ? 2 : 1;
    return Semantics(
      label: 'Step ${current + 1} of 3: ${stages[current]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < stages.length; i++)
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= current
                          ? (verified
                                ? AuthTheme.success
                                : AuthTheme.buttonFill)
                          : AuthTheme.fieldFill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stages[i],
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 13,
                      fontWeight: i == current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i <= current ? AuthTheme.text : AuthTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
