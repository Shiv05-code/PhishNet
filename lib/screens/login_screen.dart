import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';
import 'capture_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? notice;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    this.initialEmail,
    this.notice,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;
  late final _authService = widget.authService ?? AuthService();

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
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _authService.signIn(email: email, password: password);
      if (!mounted) return;
      if (_authService.hasUnverifiedSession) {
        Navigator.of(context).pushReplacement(
          fadeRoute(
            EmailVerificationScreen(
              email: email,
              authService: widget.authService,
            ),
          ),
        );
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        fadeRoute(HomeScreen(authService: widget.authService)),
        (_) => false,
      );
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(title: 'Login'),
                if (widget.notice != null) ...[
                  AuthStatusBanner(
                    status: AuthStatus.success,
                    message: widget.notice!,
                  ),
                  const SizedBox(height: 16),
                ],
                AuthField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter your email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AuthField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onToggleObscure: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Enter your password.';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AuthStatusBanner(status: AuthStatus.error, message: _error!),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flexible lets the link wrap with large text sizes.
                    Flexible(
                      child: AuthLink(
                        label: 'Forgot Password?',
                        onTap: () {
                          Navigator.of(
                            context,
                          ).push(fadeRoute(const ForgotPasswordScreen()));
                        },
                      ),
                    ),
                    AuthArrowButton(
                      semanticLabel: 'Login',
                      isLoading: _isSubmitting,
                      onPressed: _continueToApp,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: AuthLink(
                    label: 'Continue as guest',
                    underline: true,
                    onTap: _continueAsGuest,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'New here? ',
                      style: TextStyle(fontFamily: 'SFProText', fontSize: 15),
                    ),
                    AuthLink(
                      label: 'Sign Up',
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          fadeRoute(
                            SignupScreen(authService: widget.authService),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
