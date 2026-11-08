import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// CRUD for own workouts in `workout_log` (B6 migration). Health workouts are
/// never stored here. Throws [CalorieDataException]; before the migration
/// every call is `rejected` so the diary shows "Nicht gespeichert" instead
/// of retrying a missing table forever.
class WorkoutLogService {
  WorkoutLogService._();
  static final WorkoutLogService instance = WorkoutLogService._();

  static const _table = 'workout_log';

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _available =>
      AppFlagsService.instance.current.isEnabled(calorieSchemaV2FlagKey, fallback: false);

  String _userId() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    if (!_available) {
      debugPrint('⚠️ [WorkoutLog] $what skipped: workout_log not migrated yet');
      throw const CalorieDataException(CalorieErrorCode.rejected);
    }
    try {
      return await run();
    } catch (e) {
      final error = CalorieDataException.from(e);
      debugPrint('❌ [WorkoutLog] $what failed: ${error.code.name} ($e)');
      throw error;
    }
  }

  static List<Workout> _rows(Object response) => (response as List)
      .map((row) => Workout.fromJson(row as Map<String, dynamic>))
      .toList();

  /// Workouts that started on the local day [dateKey].
  Future<List<Workout>> getForDay(String dateKey) {
    final start = parseCalorieDayKey(dateKey);
    return getRange(start, DateTime(start.year, start.month, start.day + 1));
  }

  /// Workouts with `started_at` in [from, to).
  Future<List<Workout>> getRange(DateTime from, DateTime to) => _guard('Loading', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .gte('started_at', from.toUtc().toIso8601String())
            .lt('started_at', to.toUtc().toIso8601String())
            .order('started_at');
        return _rows(response);
      });

  Future<Workout> upsert(Workout workout) => _guard('Saving', () async {
        if (workout.isReadOnly) throw const CalorieDataException(CalorieErrorCode.rejected);
        final userId = _userId();
        final row = {...workout.toUpsertJson(), if (workout.userId.isEmpty) 'user_id': userId};
        final response = await _supabase.from(_table).upsert(row, onConflict: 'id').select().single();
        return Workout.fromJson(response);
      });

  Future<void> delete(String id) => _guard('Deleting', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('id', id);
      });
}
