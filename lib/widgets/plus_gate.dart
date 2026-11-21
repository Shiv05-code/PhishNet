import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/app_colors.dart';
import '../screens/payment_plan_screen.dart';
import '../services/subscription_service.dart';
import '../theme/app_typography.dart';
import 'auth_widgets.dart';
import 'guest_prompt.dart';

/// Wraps a Plus-only feature. Active Plus members get the feature as-is.
/// Everyone else (including while the subscription is still loading) sees it
/// grayed out, and tapping it explains how to upgrade.
///
/// Matches the guest lock on Results: 0.55 opacity and a prompt on tap.
class PlusGate extends StatefulWidget {
  const PlusGate({super.key, required this.feature, required this.child});

  /// Plain-language feature name, used in the prompt, e.g. "Live Monitoring".
  final String feature;
  final Widget child;

  @override
  State<PlusGate> createState() => _PlusGateState();
}

class _PlusGateState extends State<PlusGate> {
  // Read once per widget so rebuilds don't re-subscribe.
  late final Stream<Map<String, dynamic>?> _stream = _liveStream();

  static Stream<Map<String, dynamic>?> _liveStream() {
    try {
      return SubscriptionService.instance.watchEffectiveSubscription();
    } catch (_) {
      // Firebase not initialized (tests, startup races): treat as not Plus.
      return Stream.value(null);
    }
  }

  static bool _isGuest() {
    try {
      return FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return true;
    }
  }

  void _onLockedTap() {
    if (_isGuest()) {
      showGuestPrompt(context, feature: widget.feature);
    } else {
      showPlusUpgradePrompt(context, feature: widget.feature);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (SubscriptionService.isActivePlus(snapshot.data)) {
          return widget.child;
        }

        return Semantics(
          button: true,
          label: '${widget.feature}, PhishNet Plus feature',
          hint: 'Locked. Double tap to see how to upgrade.',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onLockedTap,
            child: IgnorePointer(
              child: Opacity(opacity: 0.55, child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

/// Upgrade prompt for logged-in, non-Plus users. Mirrors showGuestPrompt.
Future<void> showPlusUpgradePrompt(
  BuildContext context, {
  String feature = 'this feature',
}) async {
  final upgrade = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(
        'Upgrade to Plus',
        style: TextStyle(
          fontSize: AppTypography.title,
          color: AppColors.primaryBlue,
        ),
      ),
      content: Text(
        '$feature is a PhishNet Plus feature. Upgrade your account for full access.',
        style: const TextStyle(fontSize: AppTypography.body, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('See Plus plans'),
        ),
      ],
    ),
  );

  if (!context.mounted || upgrade != true) return;
  Navigator.of(context).push(fadeRoute(const PaymentPlanScreen()));
}
