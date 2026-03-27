import 'package:flutter/material.dart';
import 'package:shoply/data/models/user_preferences_model.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Theme Service for advanced theme customization (Prompt 5)
/// Handles: True Black, High Contrast, Warm, Cool theme variants
/// All themes and custom accent colors available to all users
class ThemeService {
  final SupabaseService _supabase;

  ThemeService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get user preferences from Supabase
  Future<UserPreferencesModel?> getUserPreferences() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create default preferences
        return await _createDefaultPreferences(userId);
      }

      return UserPreferencesModel.fromJson(response);
    } catch (e) {
      print('Error loading user preferences: $e');
      return null;
    }
  }

  /// Create default preferences for new user
  Future<UserPreferencesModel> _createDefaultPreferences(String userId) async {
    try {
      final response = await _supabase.from('user_preferences').insert({
        'user_id': userId,
        'theme_mode': 'system',
        'theme_variant': 'standard',
        'accent_color': '#2196F3',
      }).select().single();

      return UserPreferencesModel.fromJson(response);
    } catch (e) {
      print('Error creating default preferences: $e');
      rethrow;
    }
  }

  /// Save theme mode (light/dark/system)
  Future<void> saveThemeMode(String themeMode) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.from('user_preferences').upsert({
        'user_id': userId,
        'theme_mode': themeMode,
      });
    } catch (e) {
      print('Error saving theme mode: $e');
      rethrow;
    }
  }

  /// Save theme variant (standard/true_black/high_contrast/warm/cool)
  Future<void> saveThemeVariant(String themeVariant) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.from('user_preferences').upsert({
        'user_id': userId,
        'theme_variant': themeVariant,
      });
    } catch (e) {
      print('Error saving theme variant: $e');
      rethrow;
    }
  }

  /// Save accent color (hex code)
  Future<void> saveAccentColor(String accentColor) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.from('user_preferences').upsert({
        'user_id': userId,
        'accent_color': accentColor,
      });
    } catch (e) {
      print('Error saving accent color: $e');
      rethrow;
    }
  }

  /// Generate ThemeData based on variant
  ThemeData generateTheme({
    required Brightness brightness,
    required String variant,
    Color? accentColor,
  }) {
    final baseColor = accentColor ?? const Color(0xFF2196F3);

    switch (variant) {
      case 'true_black':
        return _generateTrueBlackTheme(baseColor, brightness);
      case 'high_contrast':
        return _generateHighContrastTheme(baseColor, brightness);
      case 'warm':
        return _generateWarmTheme(baseColor, brightness);
      case 'cool':
        return _generateCoolTheme(baseColor, brightness);
      case 'standard':
      default:
        return _generateStandardTheme(baseColor, brightness);
    }
  }

  /// Standard Theme (default)
  ThemeData _generateStandardTheme(Color accentColor, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      primaryColor: accentColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  /// True Black Theme (OLED-optimized)
  ThemeData _generateTrueBlackTheme(Color accentColor, Brightness brightness) {
    if (brightness == Brightness.light) {
      return _generateStandardTheme(accentColor, brightness);
    }

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF0A0A0A),
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: Colors.black,
        background: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF0A0A0A),
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }

  /// High Contrast Theme (accessibility)
  ThemeData _generateHighContrastTheme(Color accentColor, Brightness brightness) {
    if (brightness == Brightness.light) {
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: accentColor,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: accentColor,
          surface: Colors.white,
          background: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        dividerColor: Colors.black,
        useMaterial3: true,
      );
    }

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: const Color(0xFF121212),
        background: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      dividerColor: Colors.white,
      useMaterial3: true,
    );
  }

  /// Warm Theme (amber tints)
  ThemeData _generateWarmTheme(Color accentColor, Brightness brightness) {
    final warmTint = Colors.amber.shade100;

    if (brightness == Brightness.light) {
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: accentColor,
        scaffoldBackgroundColor: const Color(0xFFFFF8E1), // Light amber background
        cardColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: accentColor,
          surface: Colors.white,
          background: const Color(0xFFFFF8E1),
          onSurface: Colors.brown.shade900,
          onBackground: Colors.brown.shade900,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: warmTint,
        ),
        useMaterial3: true,
      );
    }

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: const Color(0xFF1A1610), // Dark warm background
      cardColor: const Color(0xFF2A2418),
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: const Color(0xFF2A2418),
        background: const Color(0xFF1A1610),
        onSurface: Colors.amber.shade50,
        onBackground: Colors.amber.shade50,
      ),
      useMaterial3: true,
    );
  }

  /// Cool Theme (blue tints)
  ThemeData _generateCoolTheme(Color accentColor, Brightness brightness) {
    if (brightness == Brightness.light) {
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: accentColor,
        scaffoldBackgroundColor: const Color(0xFFE3F2FD), // Light blue background
        cardColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: accentColor,
          surface: Colors.white,
          background: const Color(0xFFE3F2FD),
          onSurface: Colors.blue.shade900,
          onBackground: Colors.blue.shade900,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFBBDEFB),
        ),
        useMaterial3: true,
      );
    }

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: const Color(0xFF0D1117), // Dark cool background
      cardColor: const Color(0xFF161B22),
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: const Color(0xFF161B22),
        background: const Color(0xFF0D1117),
        onSurface: Colors.blue.shade50,
        onBackground: Colors.blue.shade50,
      ),
      useMaterial3: true,
    );
  }

  /// Get theme variant display name
  static String getVariantDisplayName(String variant) {
    switch (variant) {
      case 'true_black':
        return 'True Black (OLED)';
      case 'high_contrast':
        return 'High Contrast';
      case 'warm':
        return 'Warm';
      case 'cool':
        return 'Cool';
      case 'standard':
      default:
        return 'Standard';
    }
  }

  /// Check if theme variant is premium (deprecated - all themes are free now)
  static bool isVariantPremium(String variant) {
    return false;
  }
}
