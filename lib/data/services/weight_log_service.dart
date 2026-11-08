import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/weight_log_entry.dart';

/// CRUD for `weight_log`. One row per user per day — logging again for the
/// same day replaces it (upsert on `user_id,logged_date`). Throws
/// [CalorieDataException] on failure.
class WeightLogService {
  WeightLogService._();
  static final WeightLogService instance = WeightLogService._();

  static const _table = 'weight_log';

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
      debugPrint('❌ [WeightLog] $what failed: ${error.code.name} ($e)');
      throw error;
    }
  }

  /// Entries of the last [days] days (null = all), oldest first.
  Future<List<WeightLogEntry>> getHistory({int? days = 90}) => _guard('Loading history', () async {
        var query = _supabase.from(_table).select().eq('user_id', _userId());
        if (days != null) {
          query = query.gte('logged_date', shiftCalorieDayKey(calorieDayKey(DateTime.now()), -days));
        }
        final response = await query.order('logged_date');
        return (response as List)
            .map((row) => WeightLogEntry.fromJson(row as Map<String, dynamic>))
            .toList();
      });

  /// Newest weigh-in, or null when there is none (not on error).
  Future<WeightLogEntry?> getLatest() => _guard('Loading latest', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .order('logged_date', ascending: false)
            .limit(1)
            .maybeSingle();
        return response == null ? null : WeightLogEntry.fromJson(response);
      });

  /// Sets the weight of [date] (default today), replacing that day's entry.
  Future<WeightLogEntry> logWeight({
    required double weightKg,
    DateTime? date,
    String? note,
  }) =>
      upsertForDate(weightKg: weightKg, date: date ?? DateTime.now(), note: note);

  Future<WeightLogEntry> upsertForDate({
    required double weightKg,
    required DateTime date,
    String? note,
  }) =>
      _guard('Saving weight', () async {
        final entry = WeightLogEntry(
          id: '',
          userId: _userId(),
          loggedDate: date,
          weightKg: weightKg,
          note: note,
          createdAt: DateTime.now(),
        );
        final response = await _supabase
            .from(_table)
            .upsert(entry.toUpsertJson(), onConflict: 'user_id,logged_date')
            .select()
            .single();
        return WeightLogEntry.fromJson(response);
      });

  /// Moves an entry to another day ("es war gestern", concept 15 5.6).
  Future<WeightLogEntry> moveToDate(String id, DateTime date) => _guard('Moving weight', () async {
        final response = await _supabase
            .from(_table)
            .update({'logged_date': calorieDayKey(date)})
            .eq('user_id', _userId())
            .eq('id', id)
            .select()
            .single();
        return WeightLogEntry.fromJson(response);
      });

  Future<void> delete(String id) => _guard('Deleting weight', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('id', id);
      });

  /// Deletes the entry of [dateKey] (queue writes know the day, not the id).
  Future<void> deleteForDay(String dateKey) => _guard('Deleting weight', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('logged_date', dateKey);
      });
}
