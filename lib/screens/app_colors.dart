import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const screenBackground = Color(0xFF0B1220);
  static const cardSurface = Color(0xFF141F30);

  // Brand colors
  static const primaryBlue = Color(0xFF359BCD); // Buttons, active nav, links
  static const lightCyan = Color(0xFFB0E5FF); // Subtitles, loading accents
  static const accentGreen = Color(0xFF4ADE80); // Safe / verified states

  // Status colors
  static const dangerRed = Color(0xFFEF4444); // Scam detected, warnings
  static const cautionAmber = Color(0xFFF59E0B); // Unsure / needs review
}

class AppTextStyles {
  AppTextStyles._();

  // Headers, app title
  static const display = TextStyle(fontFamily: 'SFProDisplay');

  // Body, buttons, labels
  static const text = TextStyle(fontFamily: 'SFProText');

  // URLs, scan data, timestamps
  static const mono = TextStyle(fontFamily: 'SFMono');
}