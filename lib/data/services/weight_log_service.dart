import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD for `weight_log`. One row per user per day — logging again for the
/// same day overwrites (upsert) rather than creating a duplicate.
class WeightLogService {
  WeightLogService._();
  static final WeightLogService instance = WeightLogService._();

  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Last [days] entries, oldest first, for a progress chart.
  Future<List<WeightLogEntry>> getHistory({int days = 90}) async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final response = await _supabase
          .from('weight_log')
          .select()
          .eq('user_id', userId)
          .gte('logged_date', _dateKey(since))
          .order('logged_date');
      return (response as List)
          .map((row) => WeightLogEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [WeightLog] Failed to load history: $e');
      return [];
    }
  }

  Future<WeightLogEntry?> getLatest() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final response = await _supabase
          .from('weight_log')
          .select()
          .eq('user_id', userId)
          .order('logged_date', ascending: false)
          .limit(1)
          .maybeSingle();
      return response == null ? null : WeightLogEntry.fromJson(response);
    } catch (e) {
      debugPrint('⚠️ [WeightLog] Failed to load latest: $e');
      return null;
    }
  }

  Future<WeightLogEntry> logWeight({
    required double weightKg,
    DateTime? date,
    String? note,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    final entry = WeightLogEntry(
      id: '',
      userId: userId,
      loggedDate: date ?? DateTime.now(),
      weightKg: weightKg,
      note: note,
      createdAt: DateTime.now(),
    );
    final response = await _supabase
        .from('weight_log')
        .upsert(entry.toUpsertJson(), onConflict: 'user_id,logged_date')
        .select()
        .single();
    return WeightLogEntry.fromJson(response);
  }
}
