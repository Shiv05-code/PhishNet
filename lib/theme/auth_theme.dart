import 'package:flutter/material.dart';

class AuthTheme {
  AuthTheme._();

  static const background = Color(0xFFF8F5EE);
  static const card = Color(0xFFFDFCF9);
  static const text = Color(0xFF101D27);
  static const secondaryText = Color(0xFF4B97B9);
  static const accent = Color(0xFF359BCD);
  static const fieldFill = Color(0xFFF0F1F2);
  static const fieldBorder = Color(0xFF8DBED2);
  static const muted = Color(0xFF8B969D);
  static const legalLink = Color(0xFF359BCD);

  static const heading = TextStyle(
    fontFamily: 'SFProDisplay',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: text,
    shadows: [
      Shadow(
        color: Color(0x40000000),
        blurRadius: 3,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const label = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: text,
  );

  static const link = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: legalLink,
  );

  static const legalLinkStyle = TextStyle(
    fontFamily: 'SFProText',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: legalLink,
    decoration: TextDecoration.underline,
    decorationThickness: 0.8,
  );
}
