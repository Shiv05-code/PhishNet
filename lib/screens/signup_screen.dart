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
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _authService.createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _authService.sendVerificationEmail();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        fadeRoute(EmailVerificationScreen(email: _emailController.text.trim())),
      );
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
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Signup',
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
                validator: validateSignupEmail,
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
                textInputAction: TextInputAction.next,
                validator: validateSignupPassword,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              AuthField(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AuthTheme.text,
                    ),
                  ),
                  AuthArrowButton(
                    onPressed: _isSubmitting ? () {} : _submit,
                    semanticLabel: 'Sign up',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: AuthLink(
                  label: 'Continue as guest',
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const CaptureScreen(isGuest: true),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have account? ',
                    style: TextStyle(fontFamily: 'SFProText', fontSize: 10),
                  ),
                  AuthLink(
                    label: 'Sign In',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushReplacement(fadeRoute(const LoginScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 3,
                runSpacing: 2,
                children: [
                  const Text(
                    'By signing up, you agree to our',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AuthTheme.text,
                    ),
                  ),
                  AuthLink(
                    label: 'Terms & Conditions',
                    legal: true,
                    onTap: () => Navigator.of(
                      context,
                    ).push(fadeRoute(const TermsConditionsScreen())),
                  ),
                  const Text(
                    'and',
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AuthTheme.text,
                    ),
                  ),
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
        ),
      ),
    );
  }
}
