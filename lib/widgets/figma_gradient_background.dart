import 'package:flutter/material.dart';
import '../screens/app_colors.dart';

class FigmaGradientBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const FigmaGradientBackground({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.screenBackground,
            Color(0xFFF4FBFC),
            Color(0xFFBFEAF6),
          ],
          stops: [0, 0.48, 1],
        ),
      ),
      child: child,
    );
  }
}
