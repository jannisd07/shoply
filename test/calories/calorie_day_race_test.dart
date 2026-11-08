// A write made while a fetch of the same day is in flight (review I1): the
// server reads the day before the write, the write is confirmed and leaves
// the queue, then the old answer arrives. The local write must survive,
// neither lost nor doubled, also in the store.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Answers a fetch with the day as it was when the fetch started, once
/// [gate] opens; writes are committed and confirmed at once.
class _SlowReadRemote implements CalorieRemote {
  final Map<String, CalorieDay> days = {};
  Completer<void>? gate;

  /// Holds a write back before the server commits it.
  Completer<void>? writeGate;
  int fetches = 0;

  @override
  Future<CalorieDay> fetchDay(String dateKey) async {
    fetches++;
    final snapshot = days[dateKey] ?? CalorieDay(dateKey: dateKey);
    final g = gate;
    if (g != null) await g.future;
    return snapshot;
  }

  @override
  Future<void> execute(QueuedWrite write) async {
    final wg = writeGate;
    if (wg != null) await wg.future;
    final key = write.dateKey!;
    final day = days[key] ?? CalorieDay(dateKey: key);
    days[key] = day.copyWith(entries: [
      ...day.entries.where((e) => e.id != write.entityId),
      if (write.op == QueuedWriteOp.upsert) FoodLogEntry.fromJson(write.payload),
    ]);
  }

  @override
  Future<Map<String, DailyNutritionTotals>> fetchFoodTotals(String startKey, String endKey) async => {};

  @override
  Future<Map<String, int>> fetchWaterTotals(String startKey, String endKey) async => {};
}

FoodLogEntry _food(String id, String name, int kcal, String date) => FoodLogEntry(
      id: id,
      userId: 'u1',
      loggedDate: parseCalorieDayKey(date),
      mealType: MealType.lunch,
      foodName: name,
      calories: kcal,
      createdAt: parseCalorieDayKey(date).add(const Duration(hours: 12)),
    );

void main() {
  late SharedPreferences prefs;
  late _SlowReadRemote remote;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = _SlowReadRemote();
    container = ProviderContainer(overrides: [
      calorieSharedPreferencesProvider.overrideWith((ref) async => prefs),
      calorieRemoteProvider.overrideWithValue(remote),
      authUserIdProvider.overrideWithValue('u1'),
      calorieClockProvider.overrideWithValue(() => DateTime(2026, 11, 7, 12)),
      calorieOnlineStreamProvider.overrideWithValue(const Stream<bool>.empty()),
      healthBridgeProvider.overrideWithValue(null),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  CalorieDay? stored(String key) {
    final raw = prefs.getString(CalorieDayStore.keyFor('u1', key));
    return raw == null ? null : CalorieDay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  test('logging to a day that is not loaded yet keeps the row (S3 date menu)', () async {
    remote.gate = Completer<void>();
    remote.writeGate = Completer<void>();
    final saved = await container.read(calorieDiaryProvider).addFood(_food('', 'Apfel', 80, '2026-11-05'));
    await settle();
    // The first fetch has read the day without the row; now the server
    // commits and confirms the write while that fetch still waits.
    expect(remote.fetches, 1);
    remote.writeGate!.complete();
    await settle();
    expect(remote.days['2026-11-05']!.entries.single.id, saved.id);

    remote.gate!.complete();
    await settle();
    final day = container.read(calorieDayProvider('2026-11-05')).day!;
    expect(day.entries.map((e) => e.id), [saved.id]);
    expect(stored('2026-11-05')!.entries.map((e) => e.id), [saved.id]);

    // The next refresh reads the server with the row: still exactly once.
    remote.gate = null;
    await container.read(calorieDayProvider('2026-11-05').notifier).refresh();
    expect(container.read(calorieDayProvider('2026-11-05')).day!.entries.map((e) => e.id), [saved.id]);
  });

  test('a row deleted during a fetch does not come back', () async {
    remote.days['2026-11-06'] = CalorieDay(dateKey: '2026-11-06', entries: [_food('x', 'Kuchen', 400, '2026-11-06')]);
    container.listen(calorieDayProvider('2026-11-06'), (_, __) {});
    await settle();
    final row = container.read(calorieDayProvider('2026-11-06')).day!.entries.single;

    remote.gate = Completer<void>();
    final refresh = container.read(calorieDayProvider('2026-11-06').notifier).refresh();
    await settle();
    await container.read(calorieDiaryProvider).deleteFood(row);
    await settle();
    expect(remote.days['2026-11-06']!.entries, isEmpty);

    remote.gate!.complete();
    await refresh;
    expect(container.read(calorieDayProvider('2026-11-06')).day!.entries, isEmpty);
    expect(stored('2026-11-06')!.entries, isEmpty);
  });

  test('an edit during a fetch keeps the edited version', () async {
    remote.days['2026-11-06'] = CalorieDay(dateKey: '2026-11-06', entries: [_food('x', 'Kuchen', 400, '2026-11-06')]);
    container.listen(calorieDayProvider('2026-11-06'), (_, __) {});
    await settle();
    final row = container.read(calorieDayProvider('2026-11-06')).day!.entries.single;

    remote.gate = Completer<void>();
    final refresh = container.read(calorieDayProvider('2026-11-06').notifier).refresh();
    await settle();
    await container.read(calorieDiaryProvider).updateFood(row, row.copyWith(mealType: MealType.dinner));
    await settle();
    remote.gate!.complete();
    await refresh;
    expect(container.read(calorieDayProvider('2026-11-06')).day!.entries.single.mealType, MealType.dinner);
  });

  test('undo puts a deleted row back at its old place', () async {
    remote.days['2026-11-06'] = CalorieDay(dateKey: '2026-11-06', entries: [
      _food('a', 'Früh', 100, '2026-11-06').copyWith(),
      FoodLogEntry.fromJson({
        ..._food('b', 'Mittag', 200, '2026-11-06').toJson(),
        'created_at': DateTime(2026, 11, 6, 13).toIso8601String(),
      }),
      FoodLogEntry.fromJson({
        ..._food('c', 'Abend', 300, '2026-11-06').toJson(),
        'created_at': DateTime(2026, 11, 6, 19).toIso8601String(),
      }),
    ]);
    container.listen(calorieDayProvider('2026-11-06'), (_, __) {});
    await settle();
    final diary = container.read(calorieDiaryProvider);
    final middle = container.read(calorieDayProvider('2026-11-06')).day!.entries[1];
    await diary.deleteFood(middle);
    await diary.restoreFood(middle);
    expect(container.read(calorieDayProvider('2026-11-06')).day!.entries.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('applyLocalChanges: added, edited and deleted rows win over an old answer', () {
    final a = _food('a', 'A', 1, '2026-11-06');
    final b = _food('b', 'B', 2, '2026-11-06');
    final c = _food('c', 'C', 3, '2026-11-06');
    final server = CalorieDay(dateKey: '2026-11-06', entries: [a, b]);
    final before = CalorieDay(dateKey: '2026-11-06', entries: [a, b]);
    final after = CalorieDay(dateKey: '2026-11-06', entries: [a.copyWith(calories: 10), c]);
    final merged = applyLocalChanges(server, before: before, after: after);
    expect(merged.entries.map((e) => (e.id, e.calories)), [('a', 10), ('c', 3)]);
    expect(applyLocalChanges(server, before: before, after: before), same(server));
  });
}
