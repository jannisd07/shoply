import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD for `food_log_entries` — the day-by-day food diary.
class FoodLogService {
  FoodLogService._();
  static final FoodLogService instance = FoodLogService._();

  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<FoodLogEntry>> getEntriesForDate(DateTime date) async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('food_log_entries')
          .select()
          .eq('user_id', userId)
          .eq('logged_date', _dateKey(date))
          .order('created_at');
      return (response as List)
          .map((row) => FoodLogEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [FoodLog] Failed to load entries: $e');
      return [];
    }
  }

  Future<FoodLogEntry> addEntry(FoodLogEntry entry) async {
    final response = await _supabase
        .from('food_log_entries')
        .insert(entry.toInsertJson())
        .select()
        .single();
    return FoodLogEntry.fromJson(response);
  }

  Future<void> deleteEntry(String id) async {
    await _supabase.from('food_log_entries').delete().eq('id', id);
  }

  /// Days (normalized to midnight) with at least one food entry in the last
  /// [days] days — a single-column fetch, used for the logging streak.
  Future<Set<DateTime>> getRecentLoggedDates({int days = 60}) async {
    final userId = _userId;
    if (userId == null) return {};
    final since = DateTime.now().subtract(Duration(days: days));
    try {
      final response = await _supabase
          .from('food_log_entries')
          .select('logged_date')
          .eq('user_id', userId)
          .gte('logged_date', _dateKey(since));
      return (response as List)
          .map((row) {
            final d = DateTime.parse((row as Map)['logged_date'] as String);
            return DateTime(d.year, d.month, d.day);
          })
          .toSet();
    } catch (e) {
      debugPrint('⚠️ [FoodLog] Failed to load logged dates: $e');
      return {};
    }
  }

  /// Last 7 days of daily totals, oldest first — for a weekly summary.
  Future<Map<DateTime, DailyNutritionTotals>> getWeeklyTotals() async {
    final userId = _userId;
    if (userId == null) return {};
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 6));
    try {
      final response = await _supabase
          .from('food_log_entries')
          .select()
          .eq('user_id', userId)
          .gte('logged_date', _dateKey(weekAgo))
          .lte('logged_date', _dateKey(today));
      final entries = (response as List)
          .map((row) => FoodLogEntry.fromJson(row as Map<String, dynamic>))
          .toList();
      final byDay = <DateTime, List<FoodLogEntry>>{};
      for (final e in entries) {
        final key = DateTime(e.loggedDate.year, e.loggedDate.month, e.loggedDate.day);
        (byDay[key] ??= []).add(e);
      }
      return byDay.map((day, list) => MapEntry(day, DailyNutritionTotals.fromEntries(list)));
    } catch (e) {
      debugPrint('⚠️ [FoodLog] Failed to load weekly totals: $e');
      return {};
    }
  }
}
