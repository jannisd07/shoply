import 'package:flutter/material.dart';

/// Former "Paper" palette. Since A2 (07.11.2026) the values follow the D2
/// tokens (`lib/core/design/avo_colors.dart`) so the Paper look is gone from
/// screens not rebuilt yet. Light-only: rebuilt screens use `context.colors`.
/// Deleted once nothing imports it any more.
class PaperColors {
  PaperColors._();

  static const Color paper = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF6C6C70);
  static const Color faint = Color(0xFF8A8A8E);
  static const Color hairline = Color(0xFFE5E5EA);
  static const Color hairlineSoft = Color(0xFFEEEEF0);
  static const Color terracotta = Color(0xFF1F7A3A);
  static const Color sage = Color(0xFFE7F3EA);
  static const Color sageInk = Color(0xFF1F7A3A);
  static const Color cream = Color(0xFFF2F2F7);
  static const Color creamInk = Color(0xFF6C6C70);
  static const Color blush = Color(0xFFE0C9B4);
  static const Color blushInk = Color(0xFF6E4F38);
  static const Color plum = Color(0xFFCDB8CE);
  static const Color plumInk = Color(0xFF5C4460);
  static const Color danger = Color(0xFFD70015);
}

class PaperTextStyles {
  PaperTextStyles._();

  /// No serif any more (D2 is SF Pro only). Kept as a name so old call
  /// sites compile; null means the system font.
  static const String? serifFamily = null;

  static TextStyle serif(
    double size, {
    Color color = PaperColors.ink,
    double height = 1.25,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: size,
      color: color,
      height: height,
      fontWeight: weight,
    );
  }

  static TextStyle kicker({Color color = PaperColors.muted}) {
    return TextStyle(
      fontSize: 11,
      letterSpacing: 0.3,
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
