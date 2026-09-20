import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/auth_theme.dart';
import '../widgets/auth_widgets.dart';
import 'reset_password_screen.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      child: Column(
        children: [
          const Text('Verification', style: AuthTheme.heading),
          const SizedBox(height: 6),
          const Text(
            'We sent a 4-digit code to your email',
            style: TextStyle(
              fontFamily: 'SFProText',
              fontSize: 10,
              color: AuthTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 16,
                      color: AuthTheme.text,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        _focusNodes[index + 1].requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AuthTheme.fieldFill,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AuthTheme.fieldBorder),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 17),
          AuthArrowButton(onPressed: _submit, semanticLabel: 'Verify code'),
          const SizedBox(height: 180),
          AuthLink(
            label: 'Resend Code',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('A new verification code was requested.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
