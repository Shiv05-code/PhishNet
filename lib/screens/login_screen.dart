import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'capture_screen.dart';
import 'app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _toggleAuthRecognizer;

  // Track whether we are in "Sign Up" or "Login" mode
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    _toggleAuthRecognizer = TapGestureRecognizer()..onTap = _toggleAuthMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _toggleAuthRecognizer.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
    });
  }

  void _handleAuthSubmit() {
    // Placeholder — wire up to real auth later.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CaptureScreen()),
    );
  }

  void _continueAsGuest() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CaptureScreen()),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: AppColors.screenBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.primaryBlue.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSignUp ? 'Signup' : 'Login',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'SFProDisplay',
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Card / surface container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontFamily: 'SFProText',
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightCyan,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _isSignUp ? _fieldDecoration('someone@yahoo.com') : _fieldDecoration("Enter your email"),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Password',
                      style: TextStyle(
                        fontFamily: 'SFProText',
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightCyan,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _fieldDecoration('Enter your password'),
                    ),
                    const SizedBox(height: 24),

                    // "Sign In" or "Sign Up" label + circular arrow button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isSignUp ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(
                            fontFamily: 'SFProText',
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightCyan,
                            fontSize: 16,
                          ),
                        ),
                        InkWell(
                          onTap: _handleAuthSubmit,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: _continueAsGuest,
                        child: const Text(
                          'Continue as guest',
                          style: TextStyle(
                            fontFamily: 'SFProText',
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'SFProText',
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(
                              text: _isSignUp
                                  ? 'Already have account? '
                                  : 'New here? ',
                            ),
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Create account',
                              style: const TextStyle(
                                color: AppColors.primaryBlue,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: _toggleAuthRecognizer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}