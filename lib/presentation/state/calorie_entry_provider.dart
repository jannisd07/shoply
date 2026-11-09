import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

// State for logging food (S4–S10) and the goal screens (S13, S14) of
// `docs/redesign/b-screens/kalorien.md`, split by topic; this file keeps the
// S3 input method and the entry lookup and exports the rest.

export 'package:shoply/presentation/state/calorie_ai_provider.dart';
export 'package:shoply/presentation/state/calorie_camera_provider.dart';
export 'package:shoply/presentation/state/calorie_food_provider.dart';
export 'package:shoply/presentation/state/calorie_person_provider.dart';

// ── "Essen eintragen" ───────────────────────────────────────────────────

/// The segments of S3.
enum CalorieInputMethod { photo, barcode, search }

String _inputMethodKey(String userId) => 'cal_input_method_v1_$userId';

/// The last segment the person used on S3 (first time: "Suche").
final calorieInputMethodProvider = StateNotifierProvider.autoDispose<CalorieInputMethodNotifier, CalorieInputMethod>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final key = userId == null ? null : _inputMethodKey(userId);
  final stored = key == null ? null : prefs?.getString(key);
  return CalorieInputMethodNotifier(
    CalorieInputMethod.values.where((m) => m.name == stored).firstOrNull ?? CalorieInputMethod.search,
    key == null || prefs == null ? null : (m) => prefs.setString(key, m.name),
  );
});

class CalorieInputMethodNotifier extends StateNotifier<CalorieInputMethod> {
  CalorieInputMethodNotifier(super.state, this._save);

  final Future<bool> Function(CalorieInputMethod)? _save;

  void choose(CalorieInputMethod method) {
    state = method;
    unawaited(_save?.call(method));
  }
}

/// A logged entry of [dateKey] by id, or null when it is gone (deleted
/// here or on another device).
final calorieEntryProvider =
    Provider.autoDispose.family<FoodLogEntry?, ({String dateKey, String id})>((ref, key) {
  final day = ref.watch(calorieDayProvider(key.dateKey)).day;
  return day?.entries.where((e) => e.id == key.id).firstOrNull;
});
