import 'package:flutter/material.dart';

import '../screens/app_colors.dart';
import '../services/subscription_service.dart';

/// Small "PLUS" pill for the app bar. Shows only for an active Plus record.
///
/// The stream is injectable for tests. The default is the live subscription
/// stream, read once per widget so rebuilds don't re-subscribe.
class PlusBadge extends StatefulWidget {
  const PlusBadge({super.key, this.stream});

  final Stream<Map<String, dynamic>?>? stream;

  @override
  State<PlusBadge> createState() => _PlusBadgeState();
}

class _PlusBadgeState extends State<PlusBadge> {
  late final Stream<Map<String, dynamic>?> _stream = widget.stream ?? _liveStream();

  /// Without Firebase (widget tests, startup races) the badge simply stays hidden.
  static Stream<Map<String, dynamic>?> _liveStream() {
    try {
      return SubscriptionService.instance.watchEffectiveSubscription();
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!SubscriptionService.isActivePlus(snapshot.data)) {
          return const SizedBox.shrink();
        }
        return Semantics(
          label: 'PhishNet Plus member',
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const ExcludeSemantics(
              child: Text(
                'PLUS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
