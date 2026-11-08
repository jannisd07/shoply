// Fakes shared by the Wochenplan (B7) tests.
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/services/meal_plan_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory meal_plan_* tables; [offline] makes every call fail.
class FakeMealPlanRemote implements MealPlanRemote {
  final entries = <String, Map<String, dynamic>>{};
  final weeks = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? settings;
  bool offline = false;
  int upserts = 0;

  /// Entry ids the database refuses (e.g. a list the person left).
  final refused = <String>{};

  void _check() {
    if (offline) throw Exception('offline');
  }

  bool _inRange(String date, DateTime from, DateTime to) {
    final d = parsePlanDate(date);
    return !d.isBefore(from) && d.isBefore(to);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEntries(DateTime from, DateTime to) async {
    _check();
    return [
      for (final r in entries.values)
        if (_inRange(r['plan_date'] as String, from, to))
          {...r, 'created_at': '2026-11-01T00:00:00Z', 'updated_at': '2026-11-01T00:00:00Z'},
    ];
  }

  @override
  Future<void> upsertEntries(List<Map<String, dynamic>> rows) async {
    _check();
    upserts++;
    if (rows.any((r) => refused.contains(r['id']))) {
      throw const PostgrestException(message: 'sent_list_id is not a list of this person', code: '42501');
    }
    for (final r in rows) {
      entries[r['id'] as String] = r;
    }
  }

  @override
  Future<void> deleteEntries(List<String> ids) async {
    _check();
    ids.forEach(entries.remove);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeks(DateTime from, DateTime to) async {
    _check();
    return [for (final w in weeks.values) if (_inRange(w['week_start'] as String, from, to)) w];
  }

  @override
  Future<void> upsertWeek(Map<String, dynamic> row) async {
    _check();
    weeks[row['week_start'] as String] = row;
  }

  @override
  Future<Map<String, dynamic>?> fetchSettings() async {
    _check();
    return settings;
  }

  @override
  Future<void> upsertSettings(Map<String, dynamic> row) async {
    _check();
    settings = row;
  }
}
