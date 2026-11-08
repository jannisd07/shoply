import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/calorie_day_store.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';

FoodLogEntry _food(String id, int kcal, {String day = '2026-11-07'}) => FoodLogEntry(
      id: id,
      userId: 'u1',
      loggedDate: parseCalorieDayKey(day),
      mealType: MealType.snack,
      foodName: id,
      calories: kcal,
      createdAt: DateTime.utc(2026, 11, 7, 10),
    );

Workout _healthRun() => Workout(
      id: 'health:hk1',
      userId: 'u1',
      startedAt: DateTime(2026, 11, 7, 18),
      durationMin: 30,
      type: WorkoutType.running,
      calories: 250,
      source: WorkoutSource.health,
      sourceName: 'Apple Watch',
      createdAt: DateTime(2026, 11, 7, 18),
    );

void main() {
  late SharedPreferences prefs;
  final today = DateTime(2026, 11, 7, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  CalorieDayStore store({String user = 'u1'}) =>
      CalorieDayStore(prefs: prefs, userId: user, now: () => today);

  group('local store', () {
    test('keeps today and 14 days back on the device', () async {
      final s = store();
      expect(s.isPersisted('2026-11-07'), isTrue);
      expect(s.isPersisted('2026-10-24'), isTrue);
      expect(s.isPersisted('2026-10-23'), isFalse);
      expect(s.isPersisted('2026-11-08'), isFalse);

      await s.save(CalorieDay(dateKey: '2026-11-07', entries: [_food('a', 300)]));
      await s.save(CalorieDay(dateKey: '2026-10-01', entries: [_food('b', 500, day: '2026-10-01')]));

      final reopened = store();
      expect(reopened.read('2026-11-07')!.eatenKcal, 300);
      expect(reopened.read('2026-10-01'), isNull, reason: 'outside the window');
      // The same instance still has older days in memory.
      expect(s.read('2026-10-01')!.eatenKcal, 500);
    });

    test('an unknown day reads as null, not as an empty day', () {
      expect(store().read('2026-11-05'), isNull);
    });

    test('days are kept per account', () async {
      await store().save(CalorieDay(dateKey: '2026-11-07', entries: [_food('a', 300)]));
      expect(store(user: 'u2').read('2026-11-07'), isNull);
    });

    test('prune drops days that left the window', () async {
      final early = CalorieDayStore(prefs: prefs, userId: 'u1', now: () => DateTime(2026, 10, 20));
      await early.save(CalorieDay(dateKey: '2026-10-20', entries: [_food('a', 300, day: '2026-10-20')]));
      await store(user: 'u2').save(CalorieDay(dateKey: '2026-11-07'));
      final s = store();
      await s.prune();
      expect(prefs.getKeys().where((k) => k.contains('u1')), isEmpty);
      expect(prefs.getKeys().where((k) => k.contains('u2')), hasLength(1));
    });

    test('a broken stored day is dropped instead of crashing', () async {
      await prefs.setString(CalorieDayStore.keyFor('u1', '2026-11-07'), '{nope');
      expect(store().read('2026-11-07'), isNull);
    });
  });

  group('merging the server day with waiting writes', () {
    test('pending adds stay, pending deletes stay deleted, moved rows leave', () {
      final remote = CalorieDay(
        dateKey: '2026-11-07',
        entries: [_food('kept', 400), _food('deleted', 200), _food('moved', 100)],
        water: [
          WaterLogEntry(id: 'w1', userId: 'u1', loggedDate: DateTime(2026, 11, 7), amountMl: 250, createdAt: DateTime.utc(2026, 11, 7, 9)),
        ],
      );
      final writes = [
        QueuedWrite.upsert(
          kind: CalorieWriteKinds.food,
          entityId: 'new',
          dateKey: '2026-11-07',
          payload: _food('new', 650).toJson(),
          isCreate: true,
        ),
        QueuedWrite.delete(kind: CalorieWriteKinds.food, entityId: 'deleted', dateKey: '2026-11-07'),
        QueuedWrite.upsert(
          kind: CalorieWriteKinds.food,
          entityId: 'moved',
          dateKey: '2026-11-06',
          payload: _food('moved', 100, day: '2026-11-06').toJson(),
        ),
        QueuedWrite.delete(kind: CalorieWriteKinds.water, entityId: 'w1', dateKey: '2026-11-07'),
      ];
      final local = CalorieDay(dateKey: '2026-11-07', workouts: [_healthRun()]);

      final merged = mergeServerDay(
        server: remote,
        writes: writes,
        local: local,
        syncedAt: DateTime.utc(2026, 11, 7, 14),
      );
      expect(merged.entries.map((e) => e.id), ['kept', 'new']);
      expect(merged.eatenKcal, 1050);
      expect(merged.waterMl, 0);
      expect(merged.workouts.single.sourceName, 'Apple Watch');
      expect(merged.syncStateOf('new'), CalorieSyncState.pending);
      expect(merged.syncStateOf('kept'), CalorieSyncState.synced);
      expect(merged.syncedAt, DateTime.utc(2026, 11, 7, 14));
    });

    test('an edit waiting in the queue wins over the older server row', () {
      final remote = CalorieDay(dateKey: '2026-11-07', entries: [_food('a', 400)]);
      final merged = mergeServerDay(
        server: remote,
        writes: [
          QueuedWrite.upsert(
            kind: CalorieWriteKinds.food,
            entityId: 'a',
            dateKey: '2026-11-07',
            payload: _food('a', 450).toJson(),
          ),
        ],
        syncedAt: DateTime.utc(2026, 11, 7, 14),
      );
      expect(merged.eatenKcal, 450);
      expect(merged.entries, hasLength(1));
    });

    test('rows are sorted by meal time order: breakfast, lunch, snacks, dinner', () {
      FoodLogEntry meal(String id, MealType m) => FoodLogEntry(
            id: id,
            userId: 'u1',
            loggedDate: DateTime(2026, 11, 7),
            mealType: m,
            foodName: id,
            createdAt: DateTime.utc(2026, 11, 7, 10),
          );
      final day = CalorieDay(dateKey: '2026-11-07', entries: [
        meal('d', MealType.dinner),
        meal('b', MealType.breakfast),
        meal('s', MealType.snack),
        meal('l', MealType.lunch),
      ]);
      expect(entriesByMeal(day).keys.toList(), [MealType.breakfast, MealType.lunch, MealType.snack, MealType.dinner]);
      expect(entriesByMeal(day)[MealType.dinner]!.single.id, 'd');
    });
  });
}
