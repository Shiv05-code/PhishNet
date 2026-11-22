import 'package:flutter/material.dart';

import '../screens/app_colors.dart';

/// Labels where a result came from: Gmail live monitoring or an in-app check.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.monitored});

  final bool monitored;

  @override
  Widget build(BuildContext context) {
    final color = monitored ? AppColors.primaryBlue : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        monitored ? 'Live Monitor' : 'In-app check',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
