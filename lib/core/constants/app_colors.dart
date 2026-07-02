import 'package:flutter/material.dart';

/// Centralized color palette for consistent UI across the app
/// Based on iOS design system with dark-first approach
class AppColors {
  // ============================================
  // DARK MODE COLORS (Primary Design)
  // ============================================
  
  /// Main screen background - pure black for OLED
  static const Color darkBackground = Color(0xFF000000);
  
  /// Elevated background (e.g., auth screens)
  static const Color darkBackgroundElevated = Color(0xFF121212);
  
  /// Surface/Card background
  static const Color darkSurface = Color(0xFF1C1C1E);
  
  /// Input field fill color
  static const Color darkInputFill = Color(0xFF2C2C2E);
  
  /// Border color for inputs and cards
  static const Color darkBorder = Color(0xFF3A3A3C);
  
  /// Divider/separator color
  static const Color darkDivider = Color(0xFF38383A);
  
  /// Primary text - pure white
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  
  /// Secondary text - iOS system gray
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  
  /// Tertiary/hint text
  static const Color darkTextTertiary = Color(0xFF636366);
  
  /// Button background (secondary)
  static const Color darkButtonSecondary = Color(0xFF4A4A4A);

  // ============================================
  // LIGHT MODE COLORS
  // ============================================
  
  // "Paper" design language: warm editorial palette (see paper_colors.dart)

  /// Main screen background - warm paper
  static const Color lightBackground = Color(0xFFF7F3EC);

  /// Elevated background - brighter paper surface
  static const Color lightBackgroundElevated = Color(0xFFFFFDF8);

  /// Surface/Card background - brighter paper surface
  static const Color lightSurface = Color(0xFFFFFDF8);

  /// Input field fill color - soft cream
  static const Color lightInputFill = Color(0xFFEFE8DA);

  /// Border color for inputs and cards - paper hairline
  static const Color lightBorder = Color(0xFFE2D9C8);

  /// Divider/separator color - soft paper hairline
  static const Color lightDivider = Color(0xFFEAE3D6);

  /// Primary text - warm ink
  static const Color lightTextPrimary = Color(0xFF201D18);

  /// Secondary text - warm muted
  static const Color lightTextSecondary = Color(0xFF8A8274);

  /// Tertiary/hint text - warm faint
  static const Color lightTextTertiary = Color(0xFFB5AB97);

  /// Button background (secondary) - cream
  static const Color lightButtonSecondary = Color(0xFFE9DFCB);

  // ============================================
  // ACCENT COLORS - Paper Terracotta Palette
  // ============================================

  /// Primary accent - terracotta (light mode)
  static const Color accent = Color(0xFFC0502A);

  /// Primary accent for dark mode - brighter terracotta for contrast
  static const Color accentDark = Color(0xFFD4693F);

  /// Success - muted sage green
  static const Color success = Color(0xFF5F7D52);

  /// Warning - warm amber ink
  static const Color warning = Color(0xFFBA7517);

  /// Error/Destructive - paper danger red
  static const Color error = Color(0xFFA33B2A);

  /// Info - Same as accent
  static const Color info = Color(0xFFC0502A);
  
  /// Yellow accent
  static const Color accentYellow = Color(0xFFFFCC00);
  
  /// Purple accent
  static const Color accentPurple = Color(0xFFAF52DE);
  
  /// Teal accent
  static const Color accentTeal = Color(0xFF5AC8FA);
  
  /// Light accent variant for backgrounds - pale terracotta tint
  static const Color accentLight = Color(0xFFF3DCCF);
  
  /// Accent color getter based on theme
  static Color accentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? accentDark
        : accent;
  }

  // ============================================
  // FOOD & GROCERY COLORS - Warm, Appetizing Palette
  // ============================================
  
  /// Fresh herb green - for recipes, food-related features
  static const Color freshGreen = Color(0xFF4CAF50);
  static const Color freshGreenLight = Color(0xFF81C784);
  static const Color freshGreenDark = Color(0xFF388E3C);
  
  /// Warm orange - appetizing, inviting (like fresh produce)
  static const Color warmOrange = Color(0xFFFF8A65);
  static const Color warmOrangeLight = Color(0xFFFFAB91);
  static const Color warmOrangeDark = Color(0xFFE64A19);
  
  /// Earthy brown - natural, organic feel
  static const Color earthyBrown = Color(0xFF8D6E63);
  static const Color earthyBrownLight = Color(0xFFBCAAA4);
  static const Color earthyBrownDark = Color(0xFF5D4037);
  
  /// Cream/Warm white - cozy, homey feel
  static const Color cream = Color(0xFFFFF8E1);
  static const Color creamDark = Color(0xFFF5E6C8);
  
  /// Tomato red - appetizing accent
  static const Color tomatoRed = Color(0xFFE53935);
  
  /// Butter yellow - warm, comforting
  static const Color butterYellow = Color(0xFFFDD835);
  
  /// Sage green - herbs, natural
  static const Color sageGreen = Color(0xFF9CCC65);
  
  /// Berry purple - for desserts
  static const Color berryPurple = Color(0xFF7E57C2);
  
  /// Recipe/Food accent - paper terracotta
  static const Color recipeAccent = Color(0xFFC0502A);
  static const Color recipeAccentDark = Color(0xFFD4693F);
  
  /// Get recipe accent based on theme
  static Color recipeAccentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeAccentDark
        : recipeAccent;
  }

  /// Recipe-specific theme colors (dark mode)
  static const Color recipeDarkBg = Color(0xFF0A120A);
  static const Color recipeDarkSurface = Color(0xFF1A261A);
  static const Color recipeDarkInput = Color(0xFF2A362A);
  static const Color recipeDarkBorder = Color(0xFF3A4A3A);

  /// Recipe-specific theme colors (light mode) - paper palette
  static const Color recipeLightBg = Color(0xFFF7F3EC);
  static const Color recipeLightSurface = Color(0xFFFFFDF8);
  static const Color recipeLightBorder = Color(0xFFE2D9C8);

  /// Recipe step number accent - terracotta
  static const Color recipeStep = Color(0xFFC0502A);

  /// Recipe star rating gold - warm amber ink
  static const Color recipeStarGold = Color(0xFFBA7517);

  /// Recipe text colors
  static const Color recipeDarkTextPrimary = Color(0xFFE8F0E8);
  static const Color recipeDarkTextSecondary = Color(0xFFA0B0A0);
  static const Color recipeLightTextPrimary = Color(0xFF201D18);
  static const Color recipeLightTextSecondary = Color(0xFF8A8274);

  /// Recipe green accent (for buttons, highlights) - muted sage
  static const Color recipeGreen = Color(0xFF5F7D52);
  static const Color recipeGreenDark = Color(0xFF7A986C);
  static const Color recipeStepDark = Color(0xFFFF8A65);

  /// Get recipe text primary color based on theme
  static Color recipeTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkTextPrimary
        : recipeLightTextPrimary;
  }

  /// Get recipe text secondary color based on theme
  static Color recipeTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkTextSecondary
        : recipeLightTextSecondary;
  }

  /// Get recipe background color based on theme
  static Color recipeBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkBg
        : recipeLightBg;
  }

  /// Get recipe surface/card color based on theme
  static Color recipeSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkSurface
        : recipeLightSurface;
  }

  /// Get recipe border color based on theme
  static Color recipeBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkBorder
        : recipeLightBorder;
  }

  /// Get recipe input fill color based on theme
  static Color recipeInput(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeDarkInput
        : lightInputFill;
  }

  /// Get recipe green color based on theme
  static Color recipeGreenColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? recipeAccentDark
        : recipeAccent;
  }

  /// Get recipe star color based on theme
  static Color recipeStarColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFCA28)
        : recipeStarGold;
  }

  /// Get recipe step color based on theme
  static Color recipeStepColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF8A65)
        : recipeStep;
  }

  // ============================================
  // HELPER METHODS
  // ============================================
  
  /// Get background color based on theme
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }
  
  /// Get elevated background color based on theme
  static Color backgroundElevated(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackgroundElevated
        : lightBackgroundElevated;
  }
  
  /// Get surface/card color based on theme
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }
  
  /// Get input fill color based on theme
  static Color inputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkInputFill
        : lightInputFill;
  }
  
  /// Get border color based on theme
  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }
  
  /// Get divider color based on theme
  static Color divider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : lightDivider;
  }
  
  /// Get primary text color based on theme
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }
  
  /// Get secondary text color based on theme
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }
  
  /// Get tertiary text color based on theme
  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextTertiary
        : lightTextTertiary;
  }
  
  /// Get secondary button background based on theme
  static Color buttonSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkButtonSecondary
        : lightButtonSecondary;
  }

  // ============================================
  // LEGACY ALIASES (for backward compatibility)
  // ============================================
  
  static const Color lightPrimaryBackground = lightBackground;
  static const Color lightSecondaryBackground = lightBackgroundElevated;
  static const Color lightAccent = accent;
  static const Color lightAccentSecondary = success;
  static const Color lightCardBackground = lightSurface;
  static const Color lightShadow = Color(0x0F000000);
  
  /// List background color - warm paper
  static const Color lightListBackground = Color(0xFFF7F3EC);

  /// Item card background - brighter paper surface
  static const Color lightItemCard = Color(0xFFFFFDF8);
  
  static const Color darkPrimaryBackground = darkBackground;
  static const Color darkSecondaryBackground = darkSurface;
  static const Color darkAccent = accentDark;
  static const Color darkAccentSecondary = Color(0xFF32D74B);
  static const Color darkCardBackground = darkSurface;
  static const Color darkShadow = Color(0x33000000);
  
  /// List background color for dark mode
  static const Color darkListBackground = Color(0xFF0C0C0C);
  
  /// Item card background for dark mode - slightly elevated
  static const Color darkItemCard = Color(0xFF1A1A1C);
  
  static const Color accentBlue = accent;
  static const Color accentGreen = success;
  
  /// Get list background color based on theme
  static Color listBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkListBackground
        : lightListBackground;
  }
  
  /// Get item card color based on theme
  static Color itemCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkItemCard
        : lightItemCard;
  }

  // Gradients - terracotta tones
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC0502A), Color(0xFFD4693F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFFD4693F), Color(0xFFE07E52)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
