import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the user has opted into calorie tracking (Feature 7 preference).
/// Gates the Kalorien tab in the navbar; set during onboarding or from the
/// profile settings. SharedPreferences is the fast/offline-safe mirror;
/// `nutrition_goals.calorie_tracking_enabled` (same row goal setup writes
/// to) is the source of truth once logged in, so the preference survives a
/// reinstall or a second device instead of silently resetting to off.
final calorieTrackingEnabledProvider =
    StateNotifierProvider<CalorieTrackingNotifier, bool>((ref) {
  return CalorieTrackingNotifier();
});

class CalorieTrackingNotifier extends StateNotifier<bool> {
  static const String _key = 'calorie_tracking_enabled';

  CalorieTrackingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getBool(_key) ?? false;
    if (mounted) state = local;

    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      final goal = await NutritionGoalService.instance.getGoal();
      if (goal == null) return; // No server row yet — local value stands.
      if (mounted) state = goal.calorieTrackingEnabled;
      await prefs.setBool(_key, goal.calorieTrackingEnabled);
    } catch (e) {
      debugPrint('⚠️ [CalorieTracking] Server sync failed, using local: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);

    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      await NutritionGoalService.instance.setTrackingEnabled(enabled);
    } catch (e) {
      debugPrint('⚠️ [CalorieTracking] Failed to sync to server: $e');
    }
  }
}
