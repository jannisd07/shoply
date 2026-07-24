import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/models/weight_log_entry.dart';

NutritionGoal goal({int? calories = 2000, int? protein = 120, int water = 2000}) {
  return NutritionGoal(
    userId: 'u',
    dailyCalorieTarget: calories,
    proteinTargetG: protein,
    waterTargetMl: water,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

DailyNutritionTotals t(int kcal, {double protein = 0}) =>
    DailyNutritionTotals(calories: kcal, proteinG: protein);

WeightLogEntry w(DateTime day, double kg) => WeightLogEntry(
    id: 'w', userId: 'u', loggedDate: day, weightKg: kg, createdAt: day);

void main() {
  final today = DateTime(2026, 7, 18);
  DateTime d(int daysAgo) => today.subtract(Duration(days: daysAgo));

  test('empty week: no data, no streak, zero averages', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s.hasAnyData, false);
    expect(s.loggedDayCount, 0);
    expect(s.avgCalories, 0);
    expect(s.loggingStreak, 0);
    expect(s.weightDeltaKg, null);
    expect(s.latestWeightKg, null);
    expect(s.days.length, 7);
    expect(s.days.first, d(6));
    expect(s.days.last, today);
  });

  test('averages over logged days only; budget uses 105% grace', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {
        d(6): t(1900),
        d(5): t(2100), // exactly 105% — within
        d(4): t(2101), // just over
        d(2): t(1500),
        d(0): t(1800),
      },
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s.loggedDayCount, 5);
    expect(s.avgCalories, ((1900 + 2100 + 2101 + 1500 + 1800) / 5).round());
    expect(s.daysWithinBudget, 4);
    expect(s.caloriesByDay.length, 5);
    expect(s.caloriesByDay[d(3)], null);
  });

  test('protein reached uses 90% threshold, inclusive', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {
        d(4): t(1000, protein: 108), // = 0.9 * 120 — reached
        d(3): t(1000, protein: 107.9),
        d(2): t(1000, protein: 120),
        d(1): t(1000, protein: 0),
      },
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s.proteinReachedDays, 2);
    expect(s.avgProteinG, closeTo((108 + 107.9 + 120 + 0) / 4, 0.001));
  });

  test('no calorie/protein target: nothing counted as within budget/reached', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {d(1): t(1500, protein: 100)},
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(calories: null, protein: null),
      today: today,
    );
    expect(s.loggedDayCount, 1);
    expect(s.daysWithinBudget, 0);
    expect(s.proteinReachedDays, 0);
  });

  test('water: average over logged days, reached counts >= target', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {d(3): 2000, d(2): 1000, d(1): 2500, d(5): 0},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s.waterLoggedDayCount, 3);
    expect(s.avgWaterMl, ((2000 + 1000 + 2500) / 3).round());
    expect(s.waterReachedDays, 2);
  });

  test('weight delta needs two weigh-ins inside the window', () {
    final s1 = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      weightHistory: [w(d(20), 80.0), w(d(5), 79.2), w(d(1), 78.8)],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s1.weightDeltaKg, closeTo(-0.4, 0.001));
    expect(s1.latestWeightKg, 78.8);

    final s2 = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      weightHistory: [w(d(20), 80.0), w(d(1), 78.8)],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s2.weightDeltaKg, null);
    expect(s2.latestWeightKg, 78.8);
  });

  test('streak counts back from today when today is logged', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      loggedDates: {d(0), d(1), d(2), d(4)},
      weightHistory: [],
      goal: goal(),
      today: today,
    );
    expect(s.loggingStreak, 3);
  });

  test('an unlogged today does not break the streak yet', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      loggedDates: {d(1), d(2), d(3), d(5)},
      weightHistory: [],
      goal: goal(),
      today: today,
    );
    expect(s.loggingStreak, 3);
  });

  test('streak across a month boundary', () {
    final marchToday = DateTime(2026, 3, 2);
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      loggedDates: {
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 1),
        DateTime(2026, 2, 28),
        DateTime(2026, 2, 27),
      },
      weightHistory: [],
      goal: goal(),
      today: marchToday,
    );
    expect(s.loggingStreak, 4);
    expect(s.days.first, DateTime(2026, 2, 24));
  });

  FoodLogEntry recipeEntry({
    required int calories,
    double? protein,
    DateTime? loggedDate,
  }) =>
      FoodLogEntry(
        id: 'e',
        userId: 'u',
        loggedDate: loggedDate ?? today,
        mealType: MealType.dinner,
        source: FoodLogSource.recipe,
        sourceRecipeId: 'r1',
        foodName: 'Test meal',
        calories: calories,
        proteinG: protein,
        createdAt: today,
      );

  group('isHighProteinMeal', () {
    test('needs both >=20g protein and >=30% of calories from protein', () {
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 300, protein: 25)), // 100 kcal from protein = 33%
          true);
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 300, protein: 19)), // under the 20g floor
          false);
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 1000, protein: 25)), // 10% of calories
          false);
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 0, protein: 25)), // no calories: undefined
          false);
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 300, protein: null)),
          false);
    });

    test('boundary: exactly 20g and exactly 30% both count', () {
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 267, protein: 20)), // 80/267 = 29.96%..
          false); // just under 30% due to rounding — not a boundary case
      expect(
          WeeklyNutritionSummary.isHighProteinMeal(
              recipeEntry(calories: 266, protein: 20)), // 80/266 = 30.08%
          true);
    });
  });

  test('cookedMealCount/cookedHighProteinMealCount from recipeSourcedEntries', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
      recipeSourcedEntries: [
        recipeEntry(calories: 300, protein: 25), // high-protein
        recipeEntry(calories: 600, protein: 45), // 30% exactly-ish, high-protein
        recipeEntry(calories: 500, protein: 10), // not high-protein
      ],
    );
    expect(s.cookedMealCount, 3);
    expect(s.cookedHighProteinMealCount, 2);
  });

  test('no recipe-sourced entries: both counts default to zero', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      weightHistory: [],
      loggedDates: {},
      goal: goal(),
      today: today,
    );
    expect(s.cookedMealCount, 0);
    expect(s.cookedHighProteinMealCount, 0);
  });

  test('non-midnight timestamps in inputs are normalized', () {
    final s = WeeklyNutritionSummary.compute(
      dailyTotals: {},
      waterTotals: {},
      loggedDates: {DateTime(2026, 7, 18, 14, 30), DateTime(2026, 7, 17, 9)},
      weightHistory: [
        w(DateTime(2026, 7, 13, 8), 80.0),
        w(DateTime(2026, 7, 18, 21), 79.0),
      ],
      goal: goal(),
      today: DateTime(2026, 7, 18, 23, 59),
    );
    expect(s.loggingStreak, 2);
    expect(s.weightDeltaKg, closeTo(-1.0, 0.001));
  });
}
