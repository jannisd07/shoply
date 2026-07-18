import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD for `water_log`. Multiple rows per day (each logged glass/bottle);
/// a day's total is the sum of its rows.
class WaterLogService {
  WaterLogService._();
  static final WaterLogService instance = WaterLogService._();

  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<int> getTotalForDate(DateTime date) async {
    final entries = await getEntriesForDate(date);
    return entries.fold<int>(0, (sum, e) => sum + e.amountMl);
  }

  Future<List<WaterLogEntry>> getEntriesForDate(DateTime date) async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('water_log')
          .select()
          .eq('user_id', userId)
          .eq('logged_date', _dateKey(date))
          .order('created_at');
      return (response as List)
          .map((row) => WaterLogEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [WaterLog] Failed to load entries: $e');
      return [];
    }
  }

  /// Last 7 days of per-day totals (normalized-midnight keys); days with no
  /// water logged are simply absent — for the weekly summary.
  Future<Map<DateTime, int>> getWeeklyTotals() async {
    final userId = _userId;
    if (userId == null) return {};
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 6));
    try {
      final response = await _supabase
          .from('water_log')
          .select('logged_date, amount_ml')
          .eq('user_id', userId)
          .gte('logged_date', _dateKey(weekAgo))
          .lte('logged_date', _dateKey(today));
      final byDay = <DateTime, int>{};
      for (final row in response as List) {
        final map = row as Map;
        final d = DateTime.parse(map['logged_date'] as String);
        final key = DateTime(d.year, d.month, d.day);
        byDay[key] = (byDay[key] ?? 0) + ((map['amount_ml'] as num?)?.toInt() ?? 0);
      }
      return byDay;
    } catch (e) {
      debugPrint('⚠️ [WaterLog] Failed to load weekly totals: $e');
      return {};
    }
  }

  Future<WaterLogEntry> addEntry(int amountMl, {DateTime? date}) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    final entry = WaterLogEntry(
      id: '',
      userId: userId,
      loggedDate: date ?? DateTime.now(),
      amountMl: amountMl,
      createdAt: DateTime.now(),
    );
    final response =
        await _supabase.from('water_log').insert(entry.toInsertJson()).select().single();
    return WaterLogEntry.fromJson(response);
  }

  Future<void> deleteEntry(String id) async {
    await _supabase.from('water_log').delete().eq('id', id);
  }
}
