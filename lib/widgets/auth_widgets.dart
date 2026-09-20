import 'package:flutter/material.dart';
import '../theme/auth_theme.dart';
import 'figma_gradient_background.dart';

Route<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    opaque: true,
    maintainState: true,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, _, child) {
      final opacity = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(opacity: opacity, child: child);
    },
  );
}

Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, _, _, child) => child,
  );
}

Route<T> slideToLoginRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final incomingOffset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(animation);
      final outgoingOffset = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1, 0),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(
        secondaryAnimation,
      );

      return SlideTransition(
        position: incomingOffset,
        child: SlideTransition(position: outgoingOffset, child: child),
      );
    },
  );
}

class AuthPage extends StatelessWidget {
  final Widget child;

  const AuthPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.background,
      body: FigmaGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 56,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 430),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: AuthTheme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final VoidCallback? onToggleObscure;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AuthTheme.label),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: 'SFProText',
            fontSize: 13,
            color: AuthTheme.text,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'SFProText',
              fontSize: 13,
              color: AuthTheme.muted,
            ),
            filled: true,
            fillColor: AuthTheme.fieldFill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 10,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 17,
                      color: AuthTheme.secondaryText,
                    ),
                  ),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(width: 1.5),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border({double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide(color: AuthTheme.fieldBorder, width: width),
    );
  }
}

class AuthArrowButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String semanticLabel;

  const AuthArrowButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AuthTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool legal;

  const AuthLink({
    super.key,
    required this.label,
    required this.onTap,
    this.legal = false,
  });

  @override
  State<AuthLink> createState() => _AuthLinkState();
}

class _AuthLinkState extends State<AuthLink> {
  bool _isHovered = false;
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _isHovered || _hasFocus;
    final baseStyle = widget.legal
        ? AuthTheme.legalLinkStyle
        : AuthTheme.link;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: FocusableActionDetector(
        onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: isHighlighted && !widget.legal
                ? Border.all(color: AuthTheme.legalLink.withAlpha(140))
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: widget.onTap,
            child: Text(
              widget.label,
              style: baseStyle.copyWith(
                decoration: isHighlighted && !widget.legal
                    ? TextDecoration.underline
                    : baseStyle.decoration,
                decorationThickness: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSubmitRow extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AuthSubmitRow({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SFProText',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AuthTheme.text,
          ),
        ),
        AuthArrowButton(onPressed: onPressed, semanticLabel: label),
      ],
    );
  }
}
