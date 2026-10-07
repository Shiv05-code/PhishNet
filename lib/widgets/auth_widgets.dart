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
      final outgoingOffset =
          Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0))
              .chain(CurveTween(curve: Curves.easeInOutCubic))
              .animate(secondaryAnimation);

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

/// PhishNet logo and wordmark shown above auth cards that users reach from
/// emails, so the page is recognizably PhishNet.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PhishNet',
      excludeSemantics: true,
      child: Column(
        children: [
          Image.asset('assets/images/phishnet_logo.png', width: 72, height: 72),
          const SizedBox(height: 6),
          const Text(
            'PhishNet',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AuthTheme.text,
            ),
          ),
          const SizedBox(height: 16),
        ],
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
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

/// Icon badge, title and optional subtitle used at the top of auth cards.
class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = AuthTheme.buttonFill,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) ...[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(height: 14),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AuthTheme.heading,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, textAlign: TextAlign.center, style: AuthTheme.body),
        ],
        const SizedBox(height: 20),
      ],
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
  final String? errorText;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onToggleObscure,
    this.errorText,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AuthTheme.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: AuthTheme.fieldText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AuthTheme.fieldText.copyWith(color: AuthTheme.muted),
            filled: true,
            fillColor: AuthTheme.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscureText ? 'Show password' : 'Hide password',
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 22,
                      color: AuthTheme.fieldBorder,
                    ),
                  ),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(width: 2.5),
            errorBorder: _border(color: AuthTheme.error),
            focusedErrorBorder: _border(color: AuthTheme.error, width: 2.5),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 14, color: AuthTheme.error),
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border({
    Color color = AuthTheme.fieldBorder,
    double width = 1.5,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Full-width, clearly labeled primary action with a loading state.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthTheme.buttonFill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthTheme.buttonFill.withAlpha(150),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'SFProText',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: isLoading
            ? Semantics(
                label: '$label, loading',
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(label),
      ),
    );
  }
}

enum AuthStatus { info, success, error }

/// Inline feedback banner announced to screen readers.
class AuthStatusBanner extends StatelessWidget {
  final AuthStatus status;
  final String message;
  final Widget? action;

  const AuthStatusBanner({
    super.key,
    required this.status,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final (fill, color, icon) = switch (status) {
      AuthStatus.success => (
        AuthTheme.successFill,
        AuthTheme.success,
        Icons.check_circle,
      ),
      AuthStatus.error => (AuthTheme.errorFill, AuthTheme.error, Icons.error),
      AuthStatus.info => (
        AuthTheme.infoFill,
        AuthTheme.secondaryText,
        Icons.info,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(110)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'SFProText',
                      fontSize: 15,
                      height: 1.35,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          ],
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
    final baseStyle = widget.legal ? AuthTheme.legalLinkStyle : AuthTheme.link;

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
