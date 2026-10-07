import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/auth_validation.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'capture_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class SignupScreen extends StatefulWidget {
  final AuthService? authService;

  const SignupScreen({super.key, this.authService});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _authService = widget.authService ?? AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _duplicateEmail = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _duplicateEmail = false;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      await _authService.createAccount(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        password: _passwordController.text,
      );
      await _authService.sendVerificationEmail();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(fadeRoute(EmailVerificationScreen(email: email)));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.code == 'email-already-in-use') {
          _duplicateEmail = true;
        } else {
          _error = AuthService.messageFor(error);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      fadeRoute(
        LoginScreen(
          initialEmail: _duplicateEmail ? _emailController.text.trim() : null,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const footerStyle = TextStyle(
      fontFamily: 'SFProText',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AuthTheme.text,
    );
    return AuthPage(
      child: Column(
        children: [
          AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Sign Up',
                    subtitle: 'Create your free PhishNet account.',
                  ),
                  AuthField(
                    label: 'First Name',
                    hint: 'Enter your first name',
                    controller: _firstNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (value) =>
                        validateSignupName(value, field: 'first name'),
                  ),
                  const SizedBox(height: _gap),
                  AuthField(
                    label: 'Last Name',
                    hint: 'Enter your last name',
                    controller: _lastNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: (value) =>
                        validateSignupName(value, field: 'last name'),
                  ),
                  const SizedBox(height: _gap),
                  AuthField(
                    label: 'Email',
                    hint: 'Gmail or Yahoo address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: validateSignupEmail,
                    onChanged: (_) {
                      if (_duplicateEmail) {
                        setState(() => _duplicateEmail = false);
                      }
                    },
                    errorText: _duplicateEmail
                        ? AuthService.duplicateAccountMessage
                        : null,
                  ),
                  if (_duplicateEmail)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AuthLink(
                        label: 'Login instead',
                        onTap: _goToLogin,
                      ),
                    ),
                  const SizedBox(height: _gap),
                  AuthField(
                    label: 'Password',
                    hint: 'Create a password',
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
                  const SizedBox(height: _gap),
                  AuthField(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    onToggleObscure: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                    validator: (value) => validateConfirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    AuthStatusBanner(
                      status: AuthStatus.error,
                      message: _error!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: AuthArrowButton(
                      semanticLabel: 'Sign Up',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: AuthLink(
                      label: 'Continue as guest',
                      underline: true,
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          fadeRoute(const CaptureScreen(isGuest: true)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Secondary links live below the card to keep the form uncluttered.
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(fontFamily: 'SFProText', fontSize: 15),
              ),
              AuthLink(label: 'Login', onTap: _goToLogin),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 3,
            runSpacing: 4,
            children: [
              const Text('By signing up, you agree to our', style: footerStyle),
              AuthLink(
                label: 'Terms & Conditions',
                legal: true,
                onTap: () => Navigator.of(
                  context,
                ).push(fadeRoute(const TermsConditionsScreen())),
              ),
              const Text('and', style: footerStyle),
              AuthLink(
                label: 'Privacy Policy',
                legal: true,
                onTap: () => Navigator.of(
                  context,
                ).push(fadeRoute(const PrivacyPolicyScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const double _gap = 16;
