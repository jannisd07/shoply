import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

// Local-first state for the diary (S1), "Essen eintragen" (S3) and the Home
// sections (S0) of `docs/redesign/b-screens/kalorien.md`. Every provider
// here answers in the first frame from this device and refines afterwards.

/// The "+250 ml" quick amount. Fixed until the settings screen (S23) makes
/// it a choice.
final calorieWaterQuickMlProvider = Provider<int>((ref) => 250);

/// Water goal in ml: the goal's `water_target_ml` when a goal is set, none
/// otherwise ("1,25 l" without "von", S12).
final calorieWaterGoalMlProvider = Provider.autoDispose<int?>((ref) {
  final goal = ref.watch(calorieGoalStateProvider);
  final ml = goal.goal?.waterTargetMl;
  return ml == null || ml <= 0 ? null : ml;
});

// ── "Ohne Ziel eintragen" (S1a) ─────────────────────────────────────────

String _withoutGoalKey(String userId) => 'cal_without_goal_v1_$userId';

/// The person chose "Ohne Ziel eintragen": the diary shows without a goal
/// instead of S1a, as long as no goal is set. Stored per account.
final calorieWithoutGoalProvider =
    StateNotifierProvider.autoDispose<CalorieWithoutGoalNotifier, bool>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  return CalorieWithoutGoalNotifier(
    userId == null ? null : _withoutGoalKey(userId),
    prefs?.getBool,
    prefs?.setBool,
  );
});

class CalorieWithoutGoalNotifier extends StateNotifier<bool> {
  CalorieWithoutGoalNotifier(
    this._key,
    bool? Function(String key)? read,
    this._write,
  ) : super(_key == null ? false : (read?.call(_key) ?? false));

  final String? _key;
  final Future<bool> Function(String key, bool value)? _write;

  void choose() {
    state = true;
    final key = _key;
    if (key != null) _write?.call(key, true);
  }
}

// ── "Zuletzt gegessen" (S3) ─────────────────────────────────────────────

/// One distinct food from the history: the newest entry stands for it.
@immutable
class RecentFood {
  const RecentFood({
    required this.key,
    required this.template,
    required this.count,
    required this.lastUsed,
  });

  /// Name and brand, lower case: entries with the same key are one food.
  final String key;

  /// The newest entry of this food (amount, kcal, macros, source).
  final FoodLogEntry template;

  /// How often it was logged in the loaded history.
  final int count;
  final DateTime lastUsed;
}

/// Key that makes two entries the same food in "Zuletzt gegessen".
String recentFoodKey(FoodLogEntry e) =>
    '${e.foodName.trim().toLowerCase()}|${(e.brand ?? '').trim().toLowerCase()}';

/// Distinct foods of [entries] without [hidden], recent and frequent mixed
/// (newest, most often, second newest, …), no food twice.
List<RecentFood> rankRecentFoods(
  Iterable<FoodLogEntry> entries, {
  Set<String> hidden = const {},
}) {
  final byKey = <String, RecentFood>{};
  for (final e in entries) {
    if (e.foodName.trim().isEmpty) continue;
    final key = recentFoodKey(e);
    if (hidden.contains(key)) continue;
    final used = e.createdAt;
    final known = byKey[key];
    if (known == null) {
      byKey[key] = RecentFood(key: key, template: e, count: 1, lastUsed: used);
    } else {
      final newer = used.isAfter(known.lastUsed);
      byKey[key] = RecentFood(
        key: key,
        template: newer ? e : known.template,
        count: known.count + 1,
        lastUsed: newer ? used : known.lastUsed,
      );
    }
  }
  final recent = byKey.values.toList()..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  final frequent = byKey.values.toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : b.lastUsed.compareTo(a.lastUsed);
    });
  final out = <RecentFood>[];
  final seen = <String>{};
  for (var i = 0; out.length < byKey.length; i++) {
    for (final list in [recent, frequent]) {
      if (i < list.length && seen.add(list[i].key)) out.add(list[i]);
    }
  }
  return out;
}

String _recentCacheKey(String userId) => 'cal_recent_v1_$userId';
String _recentHiddenKey(String userId) => 'cal_recent_hidden_v1_$userId';

/// Loads the newest diary rows from the server; override in tests.
final calorieRecentRemoteProvider = Provider<Future<List<FoodLogEntry>> Function()>(
  (ref) => () => FoodLogService.instance.getRecentEntries(limit: 60),
);

/// The newest rows from the server, also stored on the device for the next
/// first frame and for offline use. Null when signed out.
final _recentServerProvider = FutureProvider.autoDispose<List<FoodLogEntry>?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) return null;
  final prefs = await ref.watch(calorieSharedPreferencesProvider.future);
  final rows = await ref.watch(calorieRecentRemoteProvider)();
  await prefs.setString(
    _recentCacheKey(userId),
    jsonEncode([for (final e in rows) e.toJson()]),
  );
  return rows;
});

/// Foods removed with "Aus „Zuletzt“ entfernen", per account.
final recentFoodsHiddenProvider =
    StateNotifierProvider.autoDispose<RecentFoodsHiddenNotifier, Set<String>>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final key = userId == null ? null : _recentHiddenKey(userId);
  return RecentFoodsHiddenNotifier(
    key == null ? const {} : {...?prefs?.getStringList(key)},
    key == null || prefs == null ? null : (v) => prefs.setStringList(key, v.toList()),
  );
});

class RecentFoodsHiddenNotifier extends StateNotifier<Set<String>> {
  RecentFoodsHiddenNotifier(super.state, this._save);

  final Future<bool> Function(Set<String> value)? _save;

  void hide(String key) {
    state = {...state, key};
    _save?.call(state);
  }

  void unhide(String key) {
    state = {...state}..remove(key);
    _save?.call(state);
  }
}

/// "Zuletzt gegessen": every distinct food the person logged (the screen
/// shows the first 8 and searches all), from today's local day and the
/// server history, stored history first.
class RecentFoods {
  const RecentFoods(this.foods, {required this.known, this.failed = false});

  final List<RecentFood> foods;

  /// False on a first start until the server answered (or failed).
  final bool known;

  /// The history could not be loaded and none is stored: never shown as
  /// "nothing eaten yet" (§3.1).
  final bool failed;
}

final recentFoodsProvider = Provider.autoDispose<RecentFoods>((ref) {
  final today = ref.watch(calorieTodayKeyProvider);
  final local = ref.watch(calorieDayProvider(today)).day?.entries ?? const [];
  final hidden = ref.watch(recentFoodsHiddenProvider);
  final server = ref.watch(_recentServerProvider);
  var history = server.valueOrNull;
  if (history == null) {
    final userId = ref.watch(authUserIdProvider);
    final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
    final raw = userId == null ? null : prefs?.getString(_recentCacheKey(userId));
    if (raw != null) {
      try {
        history = [
          for (final row in jsonDecode(raw) as List) FoodLogEntry.fromJson(row as Map<String, dynamic>),
        ];
      } catch (e) {
        // The type only: the stored text holds food names.
        debugPrint('⚠️ [CalorieRecent] Stored history unreadable: ${e.runtimeType}');
      }
    }
  }
  final byId = <String, FoodLogEntry>{
    for (final e in history ?? const <FoodLogEntry>[]) e.id: e,
    for (final e in local) e.id: e,
  };
  return RecentFoods(
    rankRecentFoods(byId.values, hidden: hidden),
    known: history != null || server.hasError || local.isNotEmpty,
    failed: history == null && server.hasError,
  );
});

/// Asks the server for the history again ("Erneut versuchen").
void retryRecentFoods(WidgetRef ref) => ref.invalidate(_recentServerProvider);

// ── "Was passt noch?" (S0, S1) ─────────────────────────────────────────

/// Remaining kcal rounded down to 50, so the ideas are not fetched again
/// after every bite.
int calorieIdeasBucket(int remainingKcal) => remainingKcal - remainingKcal % 50;

String _ideasCacheKey(String userId) => 'cal_ideas_v1_$userId';

/// Recipes that fit [bucket] remaining kcal (up to 15, ranked by
/// [CalorieRecipeNudgeService]); empty under 150 kcal. Stores today's count
/// on the device for the evening hint on Home.
final calorieIdeasProvider =
    FutureProvider.autoDispose.family<List<RecipeSuggestion>, int>((ref, bucket) async {
  if (bucket < CalorieRecipeNudgeService.minRemainingCalories) return const [];
  final user = await ref.watch(currentUserProvider.future);
  final ideas = await CalorieRecipeNudgeService.instance.getRankedSuggestions(
    remainingCalories: bucket,
    dietPreferences: user?.dietPreferences ?? const [],
    allergies: user?.allergies ?? const [],
    limit: 15,
  );
  final userId = ref.read(authUserIdProvider);
  final prefs = ref.read(calorieSharedPreferencesProvider).valueOrNull;
  if (userId != null && prefs != null) {
    await prefs.setString(
      _ideasCacheKey(userId),
      jsonEncode({'date': ref.read(calorieTodayKeyProvider), 'count': ideas.length}),
    );
  }
  return ideas;
});

/// Today's count of fitting recipes as last stored on this device (the
/// Home hint decides in the first frame); null when unknown.
final calorieStoredIdeasCountProvider = Provider.autoDispose<int?>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final prefs = ref.watch(calorieSharedPreferencesProvider).valueOrNull;
  final raw = userId == null ? null : prefs?.getString(_ideasCacheKey(userId));
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['date'] != ref.watch(calorieTodayKeyProvider)) return null;
    return json['count'] as int?;
  } catch (_) {
    return null;
  }
});

// ── Date menu (S2) ──────────────────────────────────────────────────────

/// Server sums of today and the six days before (the date menu shows the
/// kcal of each day). The diary watches it so it is there when the menu
/// opens.
final calorieRecentDayTotalsProvider =
    FutureProvider.autoDispose.family<Map<String, DailyNutritionTotals>, String>((ref, today) {
  return ref.watch(calorieRemoteProvider).fetchFoodTotals(shiftCalorieDayKey(today, -6), today);
});

/// Eaten kcal of [today] and the six days before, read when the date menu
/// opens: local days first (they include waiting writes), the server's
/// sums for the rest. A missing day has nothing logged (or is unknown).
Map<String, int> calorieMenuDaysKcal(WidgetRef ref, String today) {
  final server = ref.read(calorieRecentDayTotalsProvider(today)).valueOrNull ?? const {};
  final backend = ref.read(calorieBackendProvider).valueOrNull;
  final out = <String, int>{};
  for (var i = 0; i < 7; i++) {
    final key = shiftCalorieDayKey(today, -i);
    final local = backend?.store.read(key);
    final kcal = local != null ? local.eatenKcal : server[key]?.calories;
    if (kcal != null && kcal > 0) out[key] = kcal;
  }
  return out;
}
