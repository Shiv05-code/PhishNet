import 'package:flutter/material.dart';

/// Shared auth styling. Contrast ratios noted are against [fieldFill]/[card]
/// and meet WCAG AA (4.5:1 for text, 3:1 for borders/large text).
class AuthTheme {
  AuthTheme._();

  static const background = Color(0xFFF8F5EE);
  static const card = Color(0xFFFDFCF9);
  static const text = Color(0xFF101D27);
  static const secondaryText = Color(0xFF2C6E8E); // ~5.6:1 on card
  static const accent = Color(0xFF359BCD); // decorative only
  static const buttonFill = Color(0xFF2479A6); // ~4.8:1 with white text
  static const fieldFill = Color(0xFFF0F1F2);
  static const fieldBorder = Color(0xFF2E6E8C); // ~5:1 on fieldFill
  static const muted = Color(0xFF5F6B73); // ~5:1 on fieldFill
  static const legalLink = Color(0xFF1F6A92);
  static const success = Color(0xFF2E7D57);
  static const successFill = Color(0xFFE6F4EC);
  static const error = Color(0xFFB3261E);
  static const errorFill = Color(0xFFFBEAEA);
  static const infoFill = Color(0xFFE6F2F8);

  /// Minimum size for text the user types or reads as body copy.
  static const fieldFontSize = 18.0;

  static const heading = TextStyle(
    fontFamily: 'SFProDisplay',
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: text,
  );

  static const body = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 16,
    height: 1.4,
    color: secondaryText,
  );

  static const label = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: text,
  );

  static const fieldText = TextStyle(
    fontFamily: 'SFProText',
    fontSize: fieldFontSize,
    color: text,
  );

  static const link = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: legalLink,
  );

  static const legalLinkStyle = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: legalLink,
    decoration: TextDecoration.underline,
    decorationThickness: 0.8,
  );
}
