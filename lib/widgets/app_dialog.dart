import 'package:flutter/material.dart';
import '../screens/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/auth_theme.dart';
import 'auth_widgets.dart';
import 'figma_glass_button.dart';

/// App-styled modal that matches the auth cards and the Settings buttons:
/// rounded card, icon badge, section-sized title, and glass action buttons.
/// Pass [actions] as [AppDialogButton]s.
class AppDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.iconColor = AuthTheme.buttonFill,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AuthCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTypography.title,
                    fontWeight: FontWeight.w700,
                    color: AuthTheme.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: AuthTheme.body),
              const SizedBox(height: 20),
              for (final action in actions) ...[
                action,
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width glass dialog action, matching the Settings buttons. [color]
/// sets the label color; use [AuthTheme.error] for destructive confirms.
class AppDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const AppDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return FigmaGlassButton(
      width: double.infinity,
      height: 56,
      semanticLabel: label,
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.emphasis,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
