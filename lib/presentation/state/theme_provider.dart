import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/theme_service.dart';
import 'package:shoply/data/models/user_preferences_model.dart';

// Theme Service Provider
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

// User Preferences Provider (from Supabase)
final userPreferencesProvider = FutureProvider<UserPreferencesModel?>((ref) async {
  final themeService = ref.watch(themeServiceProvider);
  return themeService.getUserPreferences();
});

// Theme Mode Provider (local - SharedPreferences for offline)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

// Theme Variant Provider
final themeVariantProvider = StateNotifierProvider<ThemeVariantNotifier, String>((ref) {
  return ThemeVariantNotifier(ref);
});

// Accent Color Provider
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  return AccentColorNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  static const String _themeModeKey = 'theme_mode';

  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _loadThemeMode();
    _loadFromSupabase();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey);
    
    if (themeModeString != null) {
      switch (themeModeString) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> _loadFromSupabase() async {
    final userPrefs = await _ref.read(userPreferencesProvider.future);
    if (userPrefs != null) {
      state = userPrefs.themeModeEnum;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    
    // Save to SharedPreferences (local)
    final prefs = await SharedPreferences.getInstance();
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await prefs.setString(_themeModeKey, modeString);

    // Save to Supabase
    try {
      final themeService = _ref.read(themeServiceProvider);
      await themeService.saveThemeMode(modeString);
      _ref.invalidate(userPreferencesProvider);
    } catch (e) {
      print('Error saving theme mode to Supabase: $e');
    }
  }
}

class ThemeVariantNotifier extends StateNotifier<String> {
  final Ref _ref;
  static const String _themeVariantKey = 'theme_variant';

  ThemeVariantNotifier(this._ref) : super('midnight') {
    _loadThemeVariant();
  }

  Future<void> _loadThemeVariant() async {
    // Try to load from Supabase first
    final userPrefs = await _ref.read(userPreferencesProvider.future);
    if (userPrefs != null) {
      state = userPrefs.themeVariant;
      // Also save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeVariantKey, userPrefs.themeVariant);
    } else {
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_themeVariantKey) ?? 'midnight';
    }
  }

  Future<void> setThemeVariant(String variant) async {
    // Update state immediately for responsive UI
    state = variant;
    
    // Save to local storage first (always works)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeVariantKey, variant);
    
    // Try to save to Supabase (optional, don't fail if it doesn't work)
    try {
      final themeService = _ref.read(themeServiceProvider);
      await themeService.saveThemeVariant(variant);
      _ref.invalidate(userPreferencesProvider);
    } catch (e) {
      // Silently fail - local storage is enough
      debugPrint('Note: Could not sync theme to cloud: $e');
    }
  }
}

class AccentColorNotifier extends StateNotifier<Color> {
  final Ref _ref;
  static const String _accentColorKey = 'accent_color';

  AccentColorNotifier(this._ref) : super(const Color(0xFF007AFF)) {
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    // Try to load from Supabase first
    final userPrefs = await _ref.read(userPreferencesProvider.future);
    if (userPrefs != null) {
      state = userPrefs.accentColorValue;
      // Also save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentColorKey, userPrefs.accentColor);
    } else {
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final colorHex = prefs.getString(_accentColorKey);
      if (colorHex != null) {
        try {
          final hex = colorHex.replaceFirst('#', '');
          state = Color(int.parse('FF$hex', radix: 16));
        } catch (e) {
          state = const Color(0xFF007AFF);
        }
      }
    }
  }

  Future<void> setAccentColor(Color color) async {
    // Update state immediately for responsive UI
    state = color;
    
    final colorHex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    
    // Save to local storage first (always works)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentColorKey, colorHex);
    
    // Try to save to Supabase (optional, don't fail if it doesn't work)
    try {
      final themeService = _ref.read(themeServiceProvider);
      await themeService.saveAccentColor(colorHex);
      _ref.invalidate(userPreferencesProvider);
    } catch (e) {
      // Silently fail - local storage is enough
      debugPrint('Note: Could not sync accent color to cloud: $e');
    }
  }
}

// Combined Theme Data Provider
final customThemeDataProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  final themeVariant = ref.watch(themeVariantProvider);
  final accentColor = ref.watch(accentColorProvider);
  final themeService = ref.watch(themeServiceProvider);

  // Get current brightness
  Brightness brightness;
  if (themeMode == ThemeMode.light) {
    brightness = Brightness.light;
  } else if (themeMode == ThemeMode.dark) {
    brightness = Brightness.dark;
  } else {
    // System - would need BuildContext to determine, default to light
    brightness = Brightness.light;
  }

  return themeService.generateTheme(
    brightness: brightness,
    variant: themeVariant,
    accentColor: accentColor,
  );
});
