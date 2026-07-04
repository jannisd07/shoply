import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has opted into calorie tracking (Feature 7 preference).
/// Gates the Kalorien tab in the navbar; set during onboarding or from the
/// profile settings. Stored locally for now — when Feature 6/7 land a
/// server-side profile, this can sync the same way theme prefs do.
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
    if (mounted) state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
