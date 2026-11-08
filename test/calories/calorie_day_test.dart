import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/workout.dart';

FoodLogEntry _food(String id, int kcal,
        {double? protein, double? carbs, double? fat, String day = '2026-11-07'}) =>
    FoodLogEntry(
      id: id,
      userId: 'u1',
      loggedDate: parseCalorieDayKey(day),
      mealType: MealType.lunch,
      foodName: 'Essen $id',
      calories: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      createdAt: DateTime(2026, 11, 7, 12),
    );

WaterLogEntry _water(String id, int ml) => WaterLogEntry(
      id: id,
      userId: 'u1',
      loggedDate: DateTime(2026, 11, 7),
      amountMl: ml,
      createdAt: DateTime(2026, 11, 7, 9),
    );

Workout _workout(String id, int kcal) => Workout(
      id: id,
      userId: 'u1',
      startedAt: DateTime(2026, 11, 7, 18, 5),
      durationMin: 32,
      type: WorkoutType.running,
      intensity: WorkoutIntensity.moderate,
      calories: kcal,
      createdAt: DateTime(2026, 11, 7, 18, 40),
    );

void main() {
  group('day key', () {
    test('uses the local calendar day, also for UTC timestamps', () {
      final utc = DateTime.utc(2026, 11, 7, 12);
      expect(calorieDayKey(utc), calorieDayKey(utc.toLocal()));
      expect(calorieDayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });

    test('round-trips and shifts by calendar days', () {
      expect(calorieDayKey(parseCalorieDayKey('2026-11-07')), '2026-11-07');
      expect(shiftCalorieDayKey('2026-11-01', -1), '2026-10-31');
      expect(shiftCalorieDayKey('2026-12-31', 1), '2027-01-01');
      // Across the DST switch (29 Mar 2026 in Germany) a day is still a day.
      expect(shiftCalorieDayKey('2026-03-28', 1), '2026-03-29');
      expect(shiftCalorieDayKey('2026-03-29', 1), '2026-03-30');
    });

    test('week starts on Monday', () {
      expect(calorieWeekStartKey('2026-11-07'), '2026-11-02'); // Saturday
      expect(calorieWeekStartKey('2026-11-02'), '2026-11-02'); // Monday
      expect(calorieWeekStartKey('2026-11-08'), '2026-11-02'); // Sunday
    });

    test('rejects malformed keys', () {
      expect(() => parseCalorieDayKey('7.11.2026'), throwsFormatException);
    });
  });

  group('day sums', () {
    test('adds up calories, macros, water and workouts', () {
      final day = CalorieDay(
        dateKey: '2026-11-07',
        entries: [
          _food('a', 420, protein: 20, carbs: 50, fat: 10),
          _food('b', 650, protein: 32.5, carbs: 78),
        ],
        water: [_water('w1', 250), _water('w2', 500)],
        workouts: [_workout('r1', 280)],
      );
      expect(day.totals.calories, 1070);
      expect(day.totals.proteinG, 52.5);
      expect(day.totals.carbsG, 128);
      expect(day.totals.fatG, 10);
      expect(day.eatenKcal, 1070);
      expect(day.waterMl, 750);
      expect(day.workoutKcal, 280);
    });

    test('a day without food entries is unknown, not 0 kcal', () {
      final day = CalorieDay(dateKey: '2026-11-07', water: [_water('w1', 250)]);
      expect(day.hasFoodEntries, isFalse);
      expect(day.eatenKcal, isNull);
      expect(day.waterMl, 250);
    });

    test('pending and failed entries still count (optimistic)', () {
      final day = CalorieDay(
        dateKey: '2026-11-07',
        entries: [_food('a', 300)],
        syncStates: const {'a': CalorieSyncState.failed},
      );
      expect(day.eatenKcal, 300);
      expect(day.syncStateOf('a'), CalorieSyncState.failed);
      expect(day.syncStateOf('other'), CalorieSyncState.synced);
    });

    test('JSON round-trip keeps entries, water, workouts and sync states', () {
      final day = CalorieDay(
        dateKey: '2026-11-07',
        entries: [_food('a', 420, protein: 20)],
        water: [_water('w1', 250)],
        workouts: [_workout('r1', 280)],
        syncStates: const {'a': CalorieSyncState.pending},
        syncedAt: DateTime.utc(2026, 11, 7, 10),
      );
      final copy = CalorieDay.fromJson(day.toJson());
      expect(copy.dateKey, day.dateKey);
      expect(copy.entries.single.calories, 420);
      expect(copy.entries.single.proteinG, 20);
      expect(copy.water.single.amountMl, 250);
      expect(copy.workouts.single.calories, 280);
      expect(copy.syncStateOf('a'), CalorieSyncState.pending);
      expect(copy.syncedAt, day.syncedAt);
    });
  });

  group('budget', () {
    final day = CalorieDay(dateKey: '2026-11-07', entries: [_food('a', 1360)]);

    test('remaining = goal - eaten', () {
      final b = day.budget(goalKcal: 2000);
      expect(b.remainingKcal, 640);
      expect(b.isOverGoal, isFalse);
      expect(b.overByKcal, 0);
      expect(b.progress, closeTo(0.68, 0.001));
    });

    test('over goal gives a negative remainder and the amount over', () {
      final over = CalorieDay(dateKey: '2026-11-07', entries: [_food('a', 2120)]);
      final b = over.budget(goalKcal: 2000);
      expect(b.remainingKcal, -120);
      expect(b.isOverGoal, isTrue);
      expect(b.overByKcal, 120);
      expect(b.progress, 1.0);
    });

    test('workouts are not credited unless switched on', () {
      final withRun = CalorieDay(
        dateKey: '2026-11-07',
        entries: [_food('a', 1360)],
        workouts: [_workout('r1', 280)],
      );
      expect(withRun.budget(goalKcal: 2000).remainingKcal, 640);
      expect(withRun.budget(goalKcal: 2000).workoutCreditKcal, 0);
      final credited = withRun.budget(goalKcal: 2000, creditWorkouts: true);
      expect(credited.remainingKcal, 920);
      expect(credited.workoutCreditKcal, 280);
    });

    test('nothing eaten yet: whole goal remains', () {
      final empty = CalorieDay(dateKey: '2026-11-07');
      final b = empty.budget(goalKcal: 2000);
      expect(b.eatenKcal, 0);
      expect(b.remainingKcal, 2000);
      expect(b.progress, 0);
    });

    test('without a goal there is no remainder', () {
      final b = day.budget(goalKcal: null);
      expect(b.remainingKcal, isNull);
      expect(b.isOverGoal, isFalse);
      expect(b.progress, isNull);
    });
  });

  group('number input', () {
    test('accepts comma and point as decimal separator', () {
      expect(parseCalorieNumber('450,5').value, 450.5);
      expect(parseCalorieNumber('450.5').value, 450.5);
      expect(parseCalorieNumber(' 72,4 ').value, 72.4);
    });

    test('integer fields read a point before three digits as thousands', () {
      expect(parseCalorieNumber('1.250', integer: true).value, 1250);
      expect(parseCalorieNumber('1.250').value, 1.25);
      expect(parseCalorieNumber('1.250,5').value, 1250.5);
      expect(parseCalorieNumber('1,250.5').value, 1250.5);
    });

    test('integer fields round to whole numbers', () {
      expect(parseCalorieNumber('450,6', integer: true).value, 451);
    });

    test('invalid input carries the error key, never a silent 0', () {
      for (final bad in ['abc', '12abc', '1,2,3', '-5', '∞']) {
        final r = parseCalorieNumber(bad);
        expect(r.value, isNull, reason: bad);
        expect(r.errorKey, calNumberErrorKey, reason: bad);
      }
    });

    test('empty input is empty, an error only when required', () {
      expect(parseCalorieNumber('').isEmpty, isTrue);
      expect(parseCalorieNumber('').errorKey, isNull);
      expect(parseCalorieNumber('', required: true).errorKey, calNumberErrorKey);
    });

    test('respects the upper bound', () {
      expect(parseCalorieNumber('20000', max: 10000).errorKey, calNumberErrorKey);
      expect(parseCalorieNumber('9999', max: 10000).value, 9999);
    });
  });

  group('data errors', () {
    test('typed error keeps code, retry flag and message key', () {
      const e = CalorieDataException(CalorieErrorCode.network);
      expect(e.retryable, isTrue);
      expect(e.messageKey, 'cal_err_offline');
      const r = CalorieDataException(CalorieErrorCode.rejected);
      expect(r.retryable, isFalse);
    });

    test('classifies unknown errors as retryable network trouble', () {
      final e = CalorieDataException.from(Exception('socket closed'));
      expect(e.code, CalorieErrorCode.network);
      expect(CalorieDataException.from(e), same(e));
    });
  });

  group('week', () {
    final week = buildCalorieWeek(
      weekStartKey: '2026-11-02',
      todayKey: '2026-11-07',
      serverFood: const {
        '2026-11-02': DailyNutritionTotals(calories: 1910, proteinG: 90),
        '2026-11-03': DailyNutritionTotals(calories: 2080),
        '2026-11-05': DailyNutritionTotals(calories: 1760),
      },
      serverWater: const {'2026-11-02': 1500, '2026-11-03': 1700},
      localDays: {
        '2026-11-05': CalorieDay(dateKey: '2026-11-05', entries: [_food('x', 1800, day: '2026-11-05')]),
        '2026-11-07': CalorieDay(dateKey: '2026-11-07', entries: [_food('y', 900)]),
      },
    );

    test('Monday to Sunday, unlogged days unknown, local days win', () {
      expect(week.days.map((d) => d.dateKey).toList(), [
        '2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05',
        '2026-11-06', '2026-11-07', '2026-11-08',
      ]);
      expect(week.dayOf('2026-11-04')!.kcal, isNull);
      expect(week.dayOf('2026-11-05')!.kcal, 1800);
      expect(week.dayOf('2026-11-08')!.isFuture, isTrue);
      expect(week.dayOf('2026-11-07')!.isToday, isTrue);
    });

    test('averages only finished logged days (today counts from tomorrow)', () {
      expect(week.completedLoggedDays, 3);
      expect(week.averageKcal, ((1910 + 2080 + 1800) / 3).round());
      expect(week.daysInGoal(2000), 3); // 2080 <= 2100 (105 %)
      expect(week.daysInGoal(1900), 2);
      expect(week.averageWaterMl, 1600);
    });

    test('a week without data has no average', () {
      final empty = buildCalorieWeek(
        weekStartKey: '2026-11-09',
        todayKey: '2026-11-07',
        serverFood: const {},
        serverWater: const {},
        localDays: const {},
      );
      expect(empty.averageKcal, isNull);
      expect(empty.completedLoggedDays, 0);
    });
  });
}
