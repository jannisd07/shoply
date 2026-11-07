import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/user_preferences_model.dart';
import 'package:shoply/data/services/theme_service.dart';

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

// Accent Color Provider
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  return AccentColorNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  static const String _themeModeKey = 'theme_mode';

  // Paper design is light-first; users can still switch in settings.
  ThemeModeNotifier(this._ref) : super(ThemeMode.light) {
    _load();
  }

  /// Set once the user picks a theme this session; the account copy loaded
  /// afterwards must not overwrite that choice.
  bool _changedThisSession = false;

  /// Local preference first (offline-safe), then the account's saved theme
  /// (sync across devices) — applied only when it differs, in that order,
  /// so the app switches theme at most once per launch.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _parse(prefs.getString(_themeModeKey));
    if (local != null && mounted && !_changedThisSession) state = local;

    final userPrefs = await _ref.read(userPreferencesProvider.future);
    if (userPrefs == null || !mounted || _changedThisSession) return;
    final remote = userPrefs.themeModeEnum;
    if (remote != state) {
      state = remote;
      await prefs.setString(_themeModeKey, remote.name);
    }
  }

  static ThemeMode? _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
    }
    return null;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _changedThisSession = true;
    state = mode;
    final modeString = mode.name; // 'light' | 'dark' | 'system'

    // Save to SharedPreferences (local)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, modeString);

    // Save to Supabase
    try {
      final themeService = _ref.read(themeServiceProvider);
      await themeService.saveThemeMode(modeString);
      _ref.invalidate(userPreferencesProvider);
    } catch (e) {
      debugPrint('⚠️ [THEME] Error saving theme mode to Supabase: $e');
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

    final colorHex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

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
      debugPrint('⚠️ [THEME] Could not sync accent color to cloud: $e');
    }
  }
}
