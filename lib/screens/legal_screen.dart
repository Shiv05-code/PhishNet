import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../widgets/figma_gradient_background.dart';
import '../widgets/figma_app_bar.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: FigmaAppBar(title: title, showBackButton: true),
      body: FigmaGradientBackground(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
          primary: true,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Card(
            color: AppColors.surface,
            elevation: 3,
            shadowColor: const Color(0x26000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _LegalText(body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  final String body;

  const _LegalText(this.body);

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    return Text.rich(
      TextSpan(
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            TextSpan(
              text: lines[index],
              style: TextStyle(
                fontFamily: 'SFProText',
                fontSize: 12,
                height: 1.5,
                color: AppColors.text,
                fontWeight: _isEmphasized(lines[index])
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            if (index < lines.length - 1) const TextSpan(text: '\n'),
          ],
        ],
      ),
      softWrap: true,
    );
  }

  bool _isEmphasized(String line) {
    final trimmed = line.trimLeft();
    return RegExp(r'^\d+\.\s').hasMatch(trimmed) ||
        trimmed.startsWith('- ') ||
        trimmed.endsWith(':') ||
        trimmed.startsWith('PhishNet ');
  }
}
