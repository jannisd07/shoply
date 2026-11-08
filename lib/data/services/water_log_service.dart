import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/water_log_entry.dart';

/// CRUD for `water_log`. Multiple rows per day (each glass/bottle); a day's
/// total is the sum of its rows. Throws [CalorieDataException] on failure.
class WaterLogService {
  WaterLogService._();
  static final WaterLogService instance = WaterLogService._();

  static const _table = 'water_log';

  SupabaseClient get _supabase => Supabase.instance.client;

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
      debugPrint('❌ [WaterLog] $what failed: ${error.code.name} (${e is PostgrestException ? e.code : e.runtimeType})');
      throw error;
    }
  }

  Future<int> getTotalForDate(DateTime date) async {
    final entries = await getEntriesForDate(date);
    return entries.fold<int>(0, (sum, e) => sum + e.amountMl);
  }

  Future<List<WaterLogEntry>> getEntriesForDate(DateTime date) =>
      getEntriesForDay(calorieDayKey(date));

  Future<List<WaterLogEntry>> getEntriesForDay(String dateKey) => _guard('Loading $dateKey', () async {
        final response = await _supabase
            .from(_table)
            .select('id, user_id, logged_date, amount_ml, created_at')
            .eq('user_id', _userId())
            .eq('logged_date', dateKey)
            .order('created_at');
        return (response as List)
            .map((row) => WaterLogEntry.fromJson(row as Map<String, dynamic>))
            .toList();
      });

  /// Per-day totals for [startKey]..[endKey]; days without water are absent.
  Future<Map<String, int>> getDailyTotals(String startKey, String endKey) =>
      _guard('Loading totals', () async {
        final response = await _supabase
            .from(_table)
            .select('logged_date, amount_ml')
            .eq('user_id', _userId())
            .gte('logged_date', startKey)
            .lte('logged_date', endKey);
        final byDay = <String, int>{};
        for (final row in response as List) {
          final map = row as Map;
          final key = (map['logged_date'] as String).substring(0, 10);
          byDay[key] = (byDay[key] ?? 0) + ((map['amount_ml'] as num?)?.toInt() ?? 0);
        }
        return byDay;
      });

  /// Last 7 days (keys at local midnight) — legacy shape for the old summary.
  Future<Map<DateTime, int>> getWeeklyTotals() async {
    final todayKey = calorieDayKey(DateTime.now());
    final totals = await getDailyTotals(shiftCalorieDayKey(todayKey, -6), todayKey);
    return totals.map((key, ml) => MapEntry(parseCalorieDayKey(key), ml));
  }

  /// Inserts or replaces [entry] by id (idempotent for the write queue).
  Future<WaterLogEntry> upsertEntry(WaterLogEntry entry) => _guard('Saving water', () async {
        final userId = _userId();
        final row = {
          ...WaterLogEntry(
            id: entry.id,
            userId: entry.userId.isEmpty ? userId : entry.userId,
            loggedDate: entry.loggedDate,
            amountMl: entry.amountMl,
            createdAt: entry.createdAt,
          ).toInsertJson(),
          'id': entry.id.isEmpty ? const Uuid().v4() : entry.id,
        };
        final response = await _supabase
            .from(_table)
            .upsert(row, onConflict: 'id')
            .select('id, user_id, logged_date, amount_ml, created_at')
            .single();
        return WaterLogEntry.fromJson(response);
      });

  /// Adds [amountMl] for [date] (default today).
  Future<WaterLogEntry> addEntry(int amountMl, {DateTime? date}) {
    final now = DateTime.now();
    return upsertEntry(WaterLogEntry(
      id: const Uuid().v4(),
      userId: '',
      loggedDate: date ?? now,
      amountMl: amountMl,
      createdAt: now,
    ));
  }

  /// Server function for widgets, Siri and Avo (`log_water`, B6 migration):
  /// adds water for today (Europe/Berlin) or [date].
  Future<void> logWaterRemote(int amountMl, {required String source, DateTime? date}) =>
      _guard('log_water', () async {
        _userId();
        await _supabase.rpc('log_water', params: {
          'p_ml': amountMl,
          'p_source': source,
          if (date != null) 'p_date': calorieDayKey(date),
        });
      });

  Future<void> deleteEntry(String id) => _guard('Deleting water', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('id', id);
      });
}
