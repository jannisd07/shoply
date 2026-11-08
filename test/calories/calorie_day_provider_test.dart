import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

class _FakeRemote implements CalorieRemote {
  final Map<String, CalorieDay> days = {};
  Object? fetchError;
  Object? writeError;
  int fetchDayCalls = 0;
  int totalsCalls = 0;
  final List<QueuedWrite> executed = [];
  Completer<void>? writeGate;

  @override
  Future<CalorieDay> fetchDay(String dateKey) async {
    fetchDayCalls++;
    if (fetchError != null) throw fetchError!;
    return days[dateKey] ?? CalorieDay(dateKey: dateKey);
  }

  @override
  Future<void> execute(QueuedWrite write) async {
    if (writeGate != null) await writeGate!.future;
    if (writeError != null) throw writeError!;
    executed.add(write);
  }

  @override
  Future<Map<String, DailyNutritionTotals>> fetchFoodTotals(String startKey, String endKey) async {
    totalsCalls++;
    return {'2026-11-03': const DailyNutritionTotals(calories: 1900)};
  }

  @override
  Future<Map<String, int>> fetchWaterTotals(String startKey, String endKey) async => {'2026-11-03': 1500};
}

FoodLogEntry _food(String name, int kcal) => FoodLogEntry(
      id: '',
      userId: '',
      loggedDate: DateTime(2026, 11, 7),
      mealType: MealType.lunch,
      foodName: name,
      calories: kcal,
      createdAt: DateTime(2026, 11, 7, 12),
    );

void main() {
  // "Today" listens for the return from the background (needs a binding).
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late _FakeRemote remote;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    remote = _FakeRemote();
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

  test('a day the server cannot load stays unknown, not empty', () async {
    remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    container.listen(calorieDayProvider('2026-11-05'), (_, __) {});
    await settle();
    final s = container.read(calorieDayProvider('2026-11-05'));
    expect(s.day, isNull);
    expect(s.isUnknown, isTrue);
    expect(s.error?.code, CalorieErrorCode.network);
    expect(s.asAsync.hasError, isTrue);
  });

  test('opening a day loads it and its neighbours once', () async {
    container.listen(calorieDiaryDayProvider('2026-11-06'), (_, __) {});
    await settle();
    expect(container.read(calorieDayProvider('2026-11-06')).day, isNotNull);
    // 6th + 5th (before) + 7th (after, not in the future).
    expect(remote.fetchDayCalls, 3);
  });

  test('adding food shows at once, pending, then synced; nothing is refetched', () async {
    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    final fetches = remote.fetchDayCalls;
    remote.writeGate = Completer<void>();

    final diary = container.read(calorieDiaryProvider);
    final saved = await diary.addFood(_food('Spaghetti Bolognese', 650));
    final pending = container.read(calorieDayProvider('2026-11-07')).day!;
    expect(saved.id, isNotEmpty);
    expect(pending.eatenKcal, 650);
    expect(pending.syncStateOf(saved.id), CalorieSyncState.pending);

    remote.writeGate!.complete();
    await settle();
    final synced = container.read(calorieDayProvider('2026-11-07')).day!;
    expect(synced.syncStateOf(saved.id), CalorieSyncState.synced);
    expect(remote.executed.single.kind, CalorieWriteKinds.food);
    expect(remote.fetchDayCalls, fetches);
  });

  test('a refused write marks the row "not saved" and keeps it', () async {
    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    remote.writeError = const CalorieDataException(CalorieErrorCode.rejected);
    final saved = await container.read(calorieDiaryProvider).addFood(_food('Pizza', 850));
    await settle();
    final day = container.read(calorieDayProvider('2026-11-07')).day!;
    expect(day.syncStateOf(saved.id), CalorieSyncState.failed);
    expect(day.eatenKcal, 850);
  });

  test('delete and undo restore the row and the sum', () async {
    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    final diary = container.read(calorieDiaryProvider);
    final saved = await diary.addFood(_food('Studentenfutter', 132));
    await settle();
    final removed = await diary.deleteFood(saved);
    expect(container.read(calorieDayProvider('2026-11-07')).day!.eatenKcal, isNull);
    await diary.restoreFood(removed);
    expect(container.read(calorieDayProvider('2026-11-07')).day!.eatenKcal, 132);
  });

  test('the local day survives a restart offline', () async {
    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    remote.writeError = const CalorieDataException(CalorieErrorCode.network);
    await container.read(calorieDiaryProvider).addFood(_food('Pizza', 850));
    await settle();
    container.dispose();

    remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    container = ProviderContainer(overrides: [
      calorieSharedPreferencesProvider.overrideWith((ref) async => prefs),
      calorieRemoteProvider.overrideWithValue(remote),
      authUserIdProvider.overrideWithValue('u1'),
      calorieClockProvider.overrideWithValue(() => DateTime(2026, 11, 7, 12)),
      calorieOnlineStreamProvider.overrideWithValue(const Stream<bool>.empty()),
      healthBridgeProvider.overrideWithValue(null),
    ]);
    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    final s = container.read(calorieDayProvider('2026-11-07'));
    expect(s.day!.eatenKcal, 850);
    expect(s.error?.code, CalorieErrorCode.network);
    expect(s.asAsync.hasValue, isTrue);
  });

  test('the week mixes server sums and local days; a change does not refetch it', () async {
    container.listen(calorieWeekProvider('2026-11-02'), (_, __) {});
    await settle();
    var week = container.read(calorieWeekProvider('2026-11-02')).value!;
    expect(week.days.map((d) => d.dateKey).first, '2026-11-02');
    expect(week.dayOf('2026-11-03')!.kcal, 1900);
    expect(week.dayOf('2026-11-04')!.kcal, isNull, reason: 'unknown, not 0');

    container.listen(calorieDayProvider('2026-11-07'), (_, __) {});
    await settle();
    await container.read(calorieDiaryProvider).addFood(_food('Pizza', 850));
    await settle();
    week = container.read(calorieWeekProvider('2026-11-02')).value!;
    expect(week.dayOf('2026-11-07')!.kcal, 850);
    expect(remote.totalsCalls, 1);
  });
}
