import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Figma light surface palette
  static const screenBackground = Color(0xFFF8F5EE);
  static const cardSurface = Color(0xFFFDFCF9);
  static const surface = Color(0xFFFDFCF9);

  // Brand colors
  static const primaryBlue = Color(0xFF359BCD); // Buttons, active nav, links
  static const lightCyan = Color(0xFFB0E5FF); // Subtitles, loading accents
  static const accentGreen = Color(0xFF4EAF83); // Safe / verified states

  // Status colors
  static const dangerRed = Color(0xFFD95E65); // Scam detected, warnings
  static const cautionAmber = Color(0xFFD69439); // Unsure / needs review
  static const text = Color(0xFF101D27);
  static const muted = Color(0xFF71808A);
  static const fieldFill = Color(0xFFF0F1F2);
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