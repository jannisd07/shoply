import 'package:flutter/material.dart';

/// The calorie colours of D2 (ring, macros, water, the "KALORIEN" kicker and
/// "kcal drüber"), in light, dark and Increase Contrast.
///
/// Teil A has no tokens for them yet (request A-T1, A-T3, A-T4 in
/// `docs/redesign/b-screens/kalorien.md` §6). Until it does, this file is the
/// one place in the calories area that holds them; every value is a D2 value
/// or derived from it so graphics reach 3:1 and text 4.5:1 on the surface
/// (§3.7). Screens read `CalorieColors.of(context)`, never a hex value.
@immutable
class CalorieColors {
  const CalorieColors._({
    required this.ring,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
    required this.waterFill,
    required this.warning,
    required this.emptyDrop,
    required this.health,
  });

  /// Ring, carbohydrate bar, week bars (`calRing`, 3.97:1 on white).
  final Color ring;

  /// Protein bar (graphic only, never text).
  final Color protein;

  /// Carbohydrate bar; same as [ring].
  final Color carbs;

  /// Fat bar (graphic only).
  final Color fat;

  /// Drop, water bar and filled drops (graphic only).
  final Color water;

  /// Background of the water symbol square.
  final Color waterFill;

  /// The "KALORIEN" kicker and "kcal drüber" (text, 5.40:1 on white).
  final Color warning;

  /// Outline of an empty drop on the water tile (3.26:1 on white).
  final Color emptyDrop;

  /// The Health heart beside "Wird auch in Apple Health gespeichert"
  /// (decorative, 3.27:1 on the grouped background).
  final Color health;

  static const _light = CalorieColors._(
    ring: Color(0xFFC8641A), // D2 #E8833A darkened to 3:1 (§3.7)
    protein: Color(0xFF3B82F6), // D2
    carbs: Color(0xFFC8641A), // D2 ring colour
    fat: Color(0xFFA855F7), // D2
    water: Color(0xFF3B82F6), // D2
    waterFill: Color(0xFFE8F0FE), // D2
    warning: Color(0xFFA8521A), // D2 kicker
    emptyDrop: Color(0xFF8E8E93), // D2 §3.7 outline
    health: Color(0xFFFF2D55), // D2 Health
  );

  static const _dark = CalorieColors._(
    ring: Color(0xFFE8833A), // D2 orange, 6.27:1 on #1C1C1E
    protein: Color(0xFF60A5FA), // D2 blue lightened, 6.69:1
    carbs: Color(0xFFE8833A), // D2
    fat: Color(0xFFC084FC), // D2 purple lightened, 6.44:1
    water: Color(0xFF60A5FA), // D2
    waterFill: Color(0xFF1E2A3D), // D2 water square, dark
    warning: Color(0xFFFF9F5A), // D2 kicker lightened, 8.39:1
    emptyDrop: Color(0xFF8E8E93), // D2, 5.22:1 on #1C1C1E
    health: Color(0xFFFF375F), // iOS pink, dark
  );

  static const _lightHighContrast = CalorieColors._(
    ring: Color(0xFFA8521A), // D2 §3.7 Increase Contrast
    protein: Color(0xFF2563EB), // D2 text blue
    carbs: Color(0xFFA8521A), // D2
    fat: Color(0xFF9333EA), // D2
    water: Color(0xFF2563EB), // D2
    waterFill: Color(0xFFE8F0FE), // D2
    warning: Color(0xFF8A4012), // D2, 7.44:1
    emptyDrop: Color(0xFF6C6C70), // D2
    health: Color(0xFFD30F45), // iOS pink, Increase Contrast
  );

  static const _darkHighContrast = CalorieColors._(
    ring: Color(0xFFFFB27A), // D2
    protein: Color(0xFF93C5FD), // D2
    carbs: Color(0xFFFFB27A), // D2
    fat: Color(0xFFD8B4FE), // D2
    water: Color(0xFF93C5FD), // D2
    waterFill: Color(0xFF1E2A3D), // D2
    warning: Color(0xFFFFC08A), // D2, 10.66:1
    emptyDrop: Color(0xFFAEAEB2), // D2
    health: Color(0xFFFF6482), // iOS pink, dark Increase Contrast
  );

  /// The colours for [context]: brightness from the theme (as `AvoColors`
  /// does under the CupertinoApp), contrast from the device setting.
  static CalorieColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final high = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (dark) return high ? _darkHighContrast : _dark;
    return high ? _lightHighContrast : _light;
  }
}
