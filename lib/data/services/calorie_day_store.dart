import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/data/services/diet_challenge_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/user_food_service.dart';
import 'package:shoply/data/services/water_log_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';
import 'package:shoply/data/services/workout_log_service.dart';

/// `QueuedWrite.kind` values of the calories module.
abstract final class CalorieWriteKinds {
  static const food = 'food';
  static const water = 'water';
  static const workout = 'workout';

  /// payload `{weight_kg, logged_date, note}`; delete by day.
  static const weight = 'weight';

  /// payload = full `NutritionGoal` JSON incl. timestamps.
  static const goal = 'goal';

  /// entity = `<challenge id>|<date>`, payload `{challenge_id, date, kept}`
  /// (kept null = clear).
  static const checkin = 'checkin';
  static const userFood = 'user_food';
}

/// Local state per day in SharedPreferences (concept 15 2.1): today and
/// [daysBack] days before are kept on the device, so the diary opens with
/// numbers in the first frame and works offline. Older days live in memory
/// only. Keys are per account.
class CalorieDayStore {
  CalorieDayStore({
    required SharedPreferences prefs,
    required this.userId,
    DateTime Function()? now,
    this.daysBack = 14,
  })  : _prefs = prefs,
        _now = now ?? DateTime.now;

  static const _prefix = 'cal_day_v1_';

  static String keyFor(String userId, String dateKey) => '$_prefix${userId}_$dateKey';

  final SharedPreferences _prefs;
  final String userId;
  final int daysBack;
  final DateTime Function() _now;
  final Map<String, CalorieDay> _memory = {};

  String get todayKey => calorieDayKey(_now());

  /// Whether [dateKey] is kept on the device (today and [daysBack] before).
  bool isPersisted(String dateKey) {
    final today = todayKey;
    return dateKey.compareTo(today) <= 0 &&
        dateKey.compareTo(shiftCalorieDayKey(today, -daysBack)) >= 0;
  }

  /// The local state of [dateKey], or null when this device knows nothing
  /// about that day (unknown, not empty).
  CalorieDay? read(String dateKey) {
    final cached = _memory[dateKey];
    if (cached != null) return cached;
    final raw = _prefs.getString(keyFor(userId, dateKey));
    if (raw == null) return null;
    try {
      final day = CalorieDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _memory[dateKey] = day;
      return day;
    } catch (e) {
      debugPrint('⚠️ [CalorieStore] Dropping unreadable day $dateKey: $e');
      _prefs.remove(keyFor(userId, dateKey));
      return null;
    }
  }

  Future<void> save(CalorieDay day) async {
    _memory[day.dateKey] = day;
    if (!isPersisted(day.dateKey)) return;
    await _prefs.setString(keyFor(userId, day.dateKey), jsonEncode(day.toJson()));
  }

  /// Removes this account's stored days that left the window.
  Future<void> prune() async {
    final mine = '$_prefix${userId}_';
    for (final key in _prefs.getKeys().where((k) => k.startsWith(mine)).toList()) {
      final dateKey = key.substring(mine.length);
      if (!isPersisted(dateKey)) await _prefs.remove(key);
    }
  }

  /// Sign-out: forget everything of this account on the device.
  Future<void> clear() async {
    _memory.clear();
    final mine = '$_prefix${userId}_';
    for (final key in _prefs.getKeys().where((k) => k.startsWith(mine)).toList()) {
      await _prefs.remove(key);
    }
  }
}

/// The server's view of [server]'s day with all still-waiting [writes]
/// applied on top, so a refresh never undoes an optimistic change. Health
/// workouts of [local] stay (they never come from the server).
CalorieDay mergeServerDay({
  required CalorieDay server,
  required List<QueuedWrite> writes,
  CalorieDay? local,
  required DateTime syncedAt,
}) {
  final day = server.dateKey;
  final entries = LinkedHashMap<String, FoodLogEntry>.fromIterable(server.entries, key: (e) => (e as FoodLogEntry).id);
  final water = LinkedHashMap<String, WaterLogEntry>.fromIterable(server.water, key: (w) => (w as WaterLogEntry).id);
  final workouts = LinkedHashMap<String, Workout>.fromIterable(
    server.workouts.where((w) => !w.isReadOnly),
    key: (w) => (w as Workout).id,
  );
  final states = <String, CalorieSyncState>{};

  void apply<T>(Map<String, T> target, QueuedWrite w, T Function(Map<String, dynamic>) parse) {
    if (w.op == QueuedWriteOp.upsert && w.dateKey == day) {
      target[w.entityId] = parse(w.payload);
    } else {
      target.remove(w.entityId);
    }
  }

  for (final w in writes) {
    switch (w.kind) {
      case CalorieWriteKinds.food:
        apply(entries, w, FoodLogEntry.fromJson);
      case CalorieWriteKinds.water:
        apply(water, w, WaterLogEntry.fromJson);
      case CalorieWriteKinds.workout:
        apply(workouts, w, Workout.fromJson);
      default:
        continue;
    }
    if (w.dateKey == day) {
      final s = w.status == QueuedWriteStatus.failed ? CalorieSyncState.failed : CalorieSyncState.pending;
      if (states[w.entityId] != CalorieSyncState.failed) states[w.entityId] = s;
    }
  }

  return CalorieDay(
    dateKey: day,
    entries: entries.values.toList(growable: false),
    water: water.values.toList(growable: false),
    workouts: [
      ...workouts.values,
      ...?local?.workouts.where((w) => w.isReadOnly),
    ],
    syncStates: states,
    syncedAt: syncedAt,
  );
}

/// The four meal sections in the order of the day (concept 15 3.1):
/// Frühstück, Mittagessen, Snacks, Abendessen. Empty meals are included.
Map<MealType, List<FoodLogEntry>> entriesByMeal(CalorieDay day) {
  final result = LinkedHashMap<MealType, List<FoodLogEntry>>.fromIterable(
    const [MealType.breakfast, MealType.lunch, MealType.snack, MealType.dinner],
    value: (_) => <FoodLogEntry>[],
  );
  for (final e in day.entries) {
    result[e.mealType]!.add(e);
  }
  return result;
}

/// The server side of the diary. One implementation talks to Supabase,
/// tests use a fake.
abstract class CalorieRemote {
  /// Own rows of [dateKey]. Throws [CalorieDataException].
  Future<CalorieDay> fetchDay(String dateKey);

  /// Runs one queued write. Throws [CalorieDataException].
  Future<void> execute(QueuedWrite write);

  Future<Map<String, DailyNutritionTotals>> fetchFoodTotals(String startKey, String endKey);

  Future<Map<String, int>> fetchWaterTotals(String startKey, String endKey);
}

class SupabaseCalorieRemote implements CalorieRemote {
  const SupabaseCalorieRemote();

  @override
  Future<CalorieDay> fetchDay(String dateKey) async {
    final food = FoodLogService.instance.getEntriesForDay(dateKey);
    final water = WaterLogService.instance.getEntriesForDay(dateKey);
    final workouts = WorkoutLogService.instance.getForDay(dateKey).catchError(
      (Object _) => const <Workout>[],
      // Before the B6 migration the table is missing; the diary still loads.
      test: (e) => e is CalorieDataException && e.code == CalorieErrorCode.rejected,
    );
    return CalorieDay(
      dateKey: dateKey,
      entries: await food,
      water: await water,
      workouts: await workouts,
    );
  }

  @override
  Future<Map<String, DailyNutritionTotals>> fetchFoodTotals(String startKey, String endKey) =>
      FoodLogService.instance.getDailyTotals(startKey, endKey);

  @override
  Future<Map<String, int>> fetchWaterTotals(String startKey, String endKey) =>
      WaterLogService.instance.getDailyTotals(startKey, endKey);

  @override
  Future<void> execute(QueuedWrite w) async {
    final upsert = w.op == QueuedWriteOp.upsert;
    final p = w.payload;
    switch (w.kind) {
      case CalorieWriteKinds.food:
        upsert
            ? await FoodLogService.instance.upsertEntry(FoodLogEntry.fromJson(p))
            : await FoodLogService.instance.deleteEntry(w.entityId);
      case CalorieWriteKinds.water:
        upsert
            ? await WaterLogService.instance.upsertEntry(WaterLogEntry.fromJson(p))
            : await WaterLogService.instance.deleteEntry(w.entityId);
      case CalorieWriteKinds.workout:
        upsert
            ? await WorkoutLogService.instance.upsert(Workout.fromJson(p))
            : await WorkoutLogService.instance.delete(w.entityId);
      case CalorieWriteKinds.weight:
        upsert
            ? await WeightLogService.instance.upsertForDate(
                weightKg: (p['weight_kg'] as num).toDouble(),
                date: parseCalorieDayKey(p['logged_date'] as String),
                note: p['note'] as String?,
              )
            : await WeightLogService.instance.deleteForDay(w.dateKey ?? w.entityId);
      case CalorieWriteKinds.goal:
        await NutritionGoalService.instance.saveGoal(NutritionGoal.fromJson(p));
      case CalorieWriteKinds.checkin:
        await DietChallengeService.instance.setCheckIn(
          p['challenge_id'] as String,
          p['date'] as String,
          upsert ? p['kept'] as bool? : null,
        );
      case CalorieWriteKinds.userFood:
        upsert
            ? await UserFoodService.instance.upsert(UserFood.fromJson(p))
            : await UserFoodService.instance.delete(w.entityId);
      default:
        debugPrint('❌ [CalorieQueue] Unknown write kind ${w.kind}');
        throw const CalorieDataException(CalorieErrorCode.rejected);
    }
  }
}
