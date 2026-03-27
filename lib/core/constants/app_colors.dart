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
  
  /// Main screen background - pure white for clean look
  static const Color lightBackground = Color(0xFFFFFFFF);
  
  /// Elevated background
  static const Color lightBackgroundElevated = Color(0xFFFFFFFF);
  
  /// Surface/Card background - subtle warm gray
  static const Color lightSurface = Color(0xFFF8F8F8);
  
  /// Input field fill color
  static const Color lightInputFill = Color(0xFFF5F5F5);
  
  /// Border color for inputs and cards
  static const Color lightBorder = Color(0xFFEAEAEA);
  
  /// Divider/separator color
  static const Color lightDivider = Color(0xFFE8E8E8);
  
  /// Primary text - soft black
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  
  /// Secondary text - iOS system gray
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  
  /// Tertiary/hint text
  static const Color lightTextTertiary = Color(0xFF8E8E93);
  
  /// Button background (secondary)
  static const Color lightButtonSecondary = Color(0xFFEFEFEF);

  // ============================================
  // ACCENT COLORS - Modern Blue Palette
  // ============================================
  
  /// Primary accent - Modern vibrant blue (light mode)
  static const Color accent = Color(0xFF2563EB);
  
  /// Primary accent for dark mode - Brighter blue for contrast
  static const Color accentDark = Color(0xFF3B82F6);
  
  /// Success - iOS Green
  static const Color success = Color(0xFF34C759);
  
  /// Warning - iOS Orange  
  static const Color warning = Color(0xFFFF9500);
  
  /// Error/Destructive - iOS Red
  static const Color error = Color(0xFFFF3B30);
  
  /// Info - Same as accent
  static const Color info = Color(0xFF2563EB);
  
  /// Yellow accent
  static const Color accentYellow = Color(0xFFFFCC00);
  
  /// Purple accent
  static const Color accentPurple = Color(0xFFAF52DE);
  
  /// Teal accent
  static const Color accentTeal = Color(0xFF5AC8FA);
  
  /// Light accent variant for backgrounds
  static const Color accentLight = Color(0xFFDBEAFE);
  
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
  
  /// Recipe/Food accent - primary color for recipe features
  static const Color recipeAccent = Color(0xFF4CAF50); // Fresh green
  static const Color recipeAccentDark = Color(0xFF66BB6A); // Brighter for dark mode
  
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

  /// Recipe-specific theme colors (light mode)
  static const Color recipeLightBg = Color(0xFFF5F9F5);
  static const Color recipeLightSurface = Color(0xFFF0F5F0);
  static const Color recipeLightBorder = Color(0xFFD8E8D8);

  /// Recipe step number accent - warm orange
  static const Color recipeStep = Color(0xFFFF7043);

  /// Recipe star rating gold
  static const Color recipeStarGold = Color(0xFFFFB300);

  /// Recipe text colors
  static const Color recipeDarkTextPrimary = Color(0xFFE8F0E8);
  static const Color recipeDarkTextSecondary = Color(0xFFA0B0A0);
  static const Color recipeLightTextPrimary = Color(0xFF1A2E1A);
  static const Color recipeLightTextSecondary = Color(0xFF5A6E5A);

  /// Recipe green accent (for buttons, highlights)
  static const Color recipeGreen = Color(0xFF4CAF50);
  static const Color recipeGreenDark = Color(0xFF66BB6A);
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
  
  /// List background color - slightly off-white for item contrast
  static const Color lightListBackground = Color(0xFFF5F6F8);
  
  /// Item card background - soft white for subtle contrast
  static const Color lightItemCard = Color(0xFFFEFEFE);
  
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

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
