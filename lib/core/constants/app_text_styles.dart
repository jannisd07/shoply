import 'package:flutter/material.dart';

class AppTextStyles {
  // Font Family - Satoshi
  static const String fontFamily = 'Satoshi';
  static const String fontFamilyText = 'Satoshi';
  
  // Heading Styles - SF Pro Display für große Texte
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // Body Styles - SF Pro Text für Fließtext
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.35,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.35,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // Caption & Label
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // Button Text - Kräftig und lesbar
  static const TextStyle button = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.2,
  );

  // Special Styles
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.35,
  );
  
  static const TextStyle footnote = TextStyle(
    fontFamily: fontFamilyText,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.3,
  );
}
