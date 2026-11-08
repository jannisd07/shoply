import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// CRUD for `food_log_entries` — the day-by-day food diary.
///
/// Every method throws [CalorieDataException] on failure (also when signed
/// out) instead of returning an empty result, so a network error never looks
/// like "nothing logged" (concept 15 2.1). Rows carry a client-made id and
/// are upserted, so a retry after a timeout never duplicates an entry.
class FoodLogService {
  FoodLogService._();
  static final FoodLogService instance = FoodLogService._();

  static const _table = 'food_log_entries';

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _schemaV2 =>
      AppFlagsService.instance.current.isEnabled(calorieSchemaV2FlagKey, fallback: false);

  String _userId() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      final error = CalorieDataException.from(e);
      debugPrint('❌ [FoodLog] $what failed: ${error.code.name} ($e)');
      throw error;
    }
  }

  static List<FoodLogEntry> _rows(Object response) => (response as List)
      .map((row) => FoodLogEntry.fromJson(row as Map<String, dynamic>))
      .toList();

  Future<List<FoodLogEntry>> getEntriesForDate(DateTime date) =>
      getEntriesForDay(calorieDayKey(date));

  Future<List<FoodLogEntry>> getEntriesForDay(String dateKey) => _guard('Loading $dateKey', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .eq('logged_date', dateKey)
            .order('created_at');
        return _rows(response);
      });

  /// Inserts or replaces [entry] by id. An empty id gets a new one.
  Future<FoodLogEntry> upsertEntry(FoodLogEntry entry) => _guard('Saving entry', () async {
        final userId = _userId();
        final row = FoodLogEntry(
          id: entry.id.isEmpty ? const Uuid().v4() : entry.id,
          userId: entry.userId.isEmpty ? userId : entry.userId,
          loggedDate: entry.loggedDate,
          mealType: entry.mealType,
          origin: entry.origin,
          sourceRecipeId: entry.sourceRecipeId,
          foodName: entry.foodName,
          brand: entry.brand,
          quantity: entry.quantity,
          unit: entry.unit,
          calories: entry.calories,
          proteinG: entry.proteinG,
          carbsG: entry.carbsG,
          fatG: entry.fatG,
          barcode: entry.barcode,
          photoUrl: entry.photoUrl,
          photoPath: entry.photoPath,
          estimated: entry.estimated,
          confidence: entry.confidence,
          healthUuid: entry.healthUuid,
          loggedTime: entry.loggedTime,
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        );
        final response = await _supabase
            .from(_table)
            .upsert(row.toUpsertJson(schemaV2: _schemaV2), onConflict: 'id')
            .select()
            .single();
        return FoodLogEntry.fromJson(response);
      });

  /// Direct save for callers that do not go through the diary queue yet
  /// (Avo, old sheets).
  Future<FoodLogEntry> addEntry(FoodLogEntry entry) => upsertEntry(entry);

  Future<void> deleteEntry(String id) => _guard('Deleting entry', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('id', id);
      });

  /// Per-day sums for [startKey]..[endKey] (inclusive), fetching only the
  /// number columns (Inv. 4.23). Days without entries are absent (unknown).
  Future<Map<String, DailyNutritionTotals>> getDailyTotals(String startKey, String endKey) =>
      _guard('Loading totals', () async {
        final response = await _supabase
            .from(_table)
            .select('logged_date, calories, protein_g, carbs_g, fat_g')
            .eq('user_id', _userId())
            .gte('logged_date', startKey)
            .lte('logged_date', endKey);
        return sumByDay((response as List).cast<Map<String, dynamic>>());
      });

  /// Groups number-only rows by `logged_date`.
  @visibleForTesting
  static Map<String, DailyNutritionTotals> sumByDay(List<Map<String, dynamic>> rows) {
    final sums = <String, List<num>>{};
    for (final row in rows) {
      final key = (row['logged_date'] as String).substring(0, 10);
      final s = sums.putIfAbsent(key, () => [0, 0, 0, 0]);
      s[0] += (row['calories'] as num?) ?? 0;
      s[1] += (row['protein_g'] as num?) ?? 0;
      s[2] += (row['carbs_g'] as num?) ?? 0;
      s[3] += (row['fat_g'] as num?) ?? 0;
    }
    return sums.map((day, s) => MapEntry(
          day,
          DailyNutritionTotals(
            calories: s[0].round(),
            proteinG: s[1].toDouble(),
            carbsG: s[2].toDouble(),
            fatG: s[3].toDouble(),
          ),
        ));
  }

  /// Last 7 days of daily totals (keys at local midnight) — legacy shape for
  /// the old weekly strip.
  Future<Map<DateTime, DailyNutritionTotals>> getWeeklyTotals() async {
    final todayKey = calorieDayKey(DateTime.now());
    final totals = await getDailyTotals(shiftCalorieDayKey(todayKey, -6), todayKey);
    return totals.map((key, t) => MapEntry(parseCalorieDayKey(key), t));
  }

  /// Days (local midnight) with at least one entry in the last [days] days —
  /// a single-column fetch, used for the logging streak.
  Future<Set<DateTime>> getRecentLoggedDates({int days = 60}) => _guard('Loading logged dates', () async {
        final since = shiftCalorieDayKey(calorieDayKey(DateTime.now()), -days);
        final response = await _supabase
            .from(_table)
            .select('logged_date')
            .eq('user_id', _userId())
            .gte('logged_date', since);
        return (response as List)
            .map((row) => parseCalorieDayKey(((row as Map)['logged_date'] as String).substring(0, 10)))
            .toSet();
      });

  /// Recipe ids logged as meals in the last [days] days — used to avoid
  /// re-suggesting a dinner the user just cooked.
  Future<Set<String>> getRecentSourceRecipeIds({int days = 5}) => _guard('Loading recent recipes', () async {
        final since = shiftCalorieDayKey(calorieDayKey(DateTime.now()), -days);
        final response = await _supabase
            .from(_table)
            .select('source_recipe_id')
            .eq('user_id', _userId())
            .eq('source', 'recipe')
            .gte('logged_date', since);
        return (response as List)
            .map((row) => (row as Map)['source_recipe_id'] as String?)
            .whereType<String>()
            .toSet();
      });

  /// Meals logged from a recipe in the last 7 days — counts the week's
  /// high-protein cooked meals.
  Future<List<FoodLogEntry>> getWeeklyRecipeSourcedEntries() => _guard('Loading recipe meals', () async {
        final todayKey = calorieDayKey(DateTime.now());
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .eq('source', 'recipe')
            .gte('logged_date', shiftCalorieDayKey(todayKey, -6))
            .lte('logged_date', todayKey);
        return _rows(response);
      });

  /// Newest entries for "Zuletzt gegessen" (the caller removes duplicates).
  Future<List<FoodLogEntry>> getRecentEntries({int limit = 60}) => _guard('Loading recent entries', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .order('created_at', ascending: false)
            .limit(limit);
        return _rows(response);
      });
}
