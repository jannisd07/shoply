import 'package:flutter/material.dart';

/// "Paper" design language — warm editorial light palette.
/// Auth/onboarding screens use this fixed palette in both theme modes;
/// the paper look is intentionally light.
class PaperColors {
  PaperColors._();

  static const Color paper = Color(0xFFF7F3EC);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color ink = Color(0xFF201D18);
  static const Color muted = Color(0xFF8A8274);
  static const Color faint = Color(0xFFB5AB97);
  static const Color hairline = Color(0xFFE2D9C8);
  static const Color hairlineSoft = Color(0xFFEAE3D6);
  static const Color terracotta = Color(0xFFC0502A);
  static const Color sage = Color(0xFFB7C4A9);
  static const Color sageInk = Color(0xFF42513A);
  static const Color cream = Color(0xFFE9DFCB);
  static const Color creamInk = Color(0xFF7A6E52);
  static const Color blush = Color(0xFFE0C9B4);
  static const Color blushInk = Color(0xFF6E4F38);
  static const Color plum = Color(0xFFCDB8CE);
  static const Color plumInk = Color(0xFF5C4460);
  static const Color danger = Color(0xFFA33B2A);
}

class PaperTextStyles {
  PaperTextStyles._();

  /// Georgia ships with iOS/macOS; falls back to platform serif elsewhere.
  static const String serifFamily = 'Georgia';

  static TextStyle serif(
    double size, {
    Color color = PaperColors.ink,
    double height = 1.25,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontFamilyFallback: const ['Times New Roman', 'serif'],
      fontSize: size,
      color: color,
      height: height,
      fontWeight: weight,
    );
  }

  static TextStyle kicker({Color color = PaperColors.muted}) {
    return TextStyle(
      fontSize: 11,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static TextStyle body({
    double size = 14,
    Color color = PaperColors.ink,
    double height = 1.5,
  }) {
    return TextStyle(fontSize: size, color: color, height: height);
  }
}
