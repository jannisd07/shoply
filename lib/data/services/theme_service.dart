import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/user_preferences_model.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Syncs the user's theme mode, theme variant and accent color to the
/// `user_preferences` table (one row per user, UNIQUE(user_id)).
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
      debugPrint('❌ [THEME] Error loading user preferences: $e');
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
      debugPrint('❌ [THEME] Error creating default preferences: $e');
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
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('❌ [THEME] Error saving theme mode: $e');
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
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('❌ [THEME] Error saving theme variant: $e');
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
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('❌ [THEME] Error saving accent color: $e');
      rethrow;
    }
  }
}
