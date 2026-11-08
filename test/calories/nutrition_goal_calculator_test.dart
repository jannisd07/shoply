import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';

CalculatedTargets _calc({
  NutritionGoalType goal = NutritionGoalType.loseWeight,
  ActivityLevel activity = ActivityLevel.moderate,
  double weight = 70,
  double height = 165,
  int age = 30,
  String gender = 'female',
  double? target,
  int? weeks,
  GoalPace? pace,
}) =>
    NutritionGoalCalculator.calculate(
      goalType: goal,
      activityLevel: activity,
      currentWeightKg: weight,
      heightCm: height,
      age: age,
      gender: gender,
      targetWeightKg: target,
      timelineWeeks: weeks,
      pace: pace,
    );

void main() {
  group('pace (Gemütlich · Normal · Zügig)', () {
    // Female, 30 y, 165 cm, 70 kg, moderate: TDEE 2201.39 kcal.
    test('weight loss: 0.25 / 0.5 / 0.75 kg per week', () {
      expect(_calc(pace: GoalPace.gemuetlich).dailyCalorieTarget, 1926);
      expect(_calc(pace: GoalPace.normal).dailyCalorieTarget, 1651);
      expect(_calc(pace: GoalPace.zuegig).dailyCalorieTarget, 1376);
      expect(_calc(pace: GoalPace.normal).effectiveKgPerWeek, closeTo(0.5, 0.001));
    });

    test('muscle gain: the 200 kcal minimum change still applies', () {
      final slow = _calc(goal: NutritionGoalType.gainMuscle, pace: GoalPace.gemuetlich);
      expect(slow.dailyCalorieTarget, 2401);
      expect(slow.effectiveKgPerWeek, closeTo(200 * 7 / 7700, 0.0001));
      expect(
        _calc(goal: NutritionGoalType.gainMuscle, pace: GoalPace.zuegig).dailyCalorieTarget,
        2641,
      );
    });

    test('estimates the weeks to the target weight', () {
      final r = _calc(pace: GoalPace.normal, target: 65);
      expect(r.estimatedWeeksToTarget, closeTo(10, 0.01));
      expect(r.targetWeightConflict, isFalse);
    });

    test('flags a target weight above the current weight when losing', () {
      expect(_calc(pace: GoalPace.normal, target: 75).targetWeightConflict, isTrue);
      expect(_calc(pace: GoalPace.normal, target: 75).estimatedWeeksToTarget, isNull);
      expect(
        _calc(goal: NutritionGoalType.gainMuscle, pace: GoalPace.normal, target: 65)
            .targetWeightConflict,
        isTrue,
      );
    });

    test('pace has DB values gemuetlich, normal, zuegig', () {
      expect(GoalPace.values.map((p) => p.dbValue), ['gemuetlich', 'normal', 'zuegig']);
      expect(GoalPaceX.fromDb('zuegig'), GoalPace.zuegig);
      expect(GoalPaceX.fromDb(null), isNull);
    });
  });

  group('lower bounds', () {
    test('never below 1200 kcal for women and says so', () {
      final r = _calc(
        activity: ActivityLevel.sedentary,
        weight: 50,
        height: 155,
        age: 60,
        pace: GoalPace.normal,
      );
      expect(r.dailyCalorieTarget, 1200);
      expect(r.floorReached, isTrue);
      expect(r.floorKcal, 1200);
      expect(r.effectiveKgPerWeek!, lessThan(0.05));
    });

    test('never below 1500 kcal for men', () {
      final r = _calc(
        gender: 'male',
        activity: ActivityLevel.sedentary,
        weight: 60,
        height: 165,
        age: 65,
        pace: GoalPace.normal,
      );
      expect(r.dailyCalorieTarget, 1500);
      expect(r.floorKcal, 1500);
      expect(r.floorReached, isTrue);
    });

    test('a normal goal does not report the floor', () {
      expect(_calc(pace: GoalPace.normal).floorReached, isFalse);
    });
  });

  group('divers', () {
    test('uses the average of the male and female formula', () {
      final divers = _calc(goal: NutritionGoalType.maintain, gender: 'other', height: 175);
      final male = _calc(goal: NutritionGoalType.maintain, gender: 'male', height: 175);
      final female = _calc(goal: NutritionGoalType.maintain, gender: 'female', height: 175);
      expect(divers.dailyCalorieTarget, 2427);
      expect(
        divers.dailyCalorieTarget,
        closeTo((male.dailyCalorieTarget + female.dailyCalorieTarget) / 2, 1),
      );
    });

    test('"divers", "diverse" and "prefer_not_to_say" count as divers', () {
      for (final g in ['divers', 'diverse', 'prefer_not_to_say']) {
        expect(
          _calc(goal: NutritionGoalType.maintain, gender: g, height: 175).dailyCalorieTarget,
          2427,
          reason: g,
        );
      }
    });

    test('lower bound for divers is 1200 kcal', () {
      final r = _calc(
        goal: NutritionGoalType.maintain,
        gender: 'other',
        activity: ActivityLevel.sedentary,
        weight: 45,
        height: 150,
        age: 70,
      );
      expect(r.dailyCalorieTarget, 1200);
      expect(r.floorKcal, 1200);
    });
  });

  group('under 18', () {
    test('no weight-loss goal: calculates maintenance and flags it', () {
      final r = _calc(age: 16, height: 160, weight: 60, pace: GoalPace.normal, target: 55);
      expect(r.weightLossBlockedForMinor, isTrue);
      expect(r.dailyCalorieTarget, 2106);
      expect(r.estimatedWeeksToTarget, isNull);
      expect(NutritionGoalCalculator.weightLossAllowed(17), isFalse);
      expect(NutritionGoalCalculator.weightLossAllowed(18), isTrue);
    });

    test('muscle gain stays possible', () {
      final r = _calc(goal: NutritionGoalType.gainMuscle, age: 16, pace: GoalPace.normal);
      expect(r.weightLossBlockedForMinor, isFalse);
    });
  });

  test('legacy timeline call stays exactly as before', () {
    final r = _calc(
      gender: 'male',
      weight: 80,
      height: 180,
      age: 30,
      target: 75,
      weeks: 12,
    );
    expect(r.dailyCalorieTarget, 2301);
    expect(r.proteinTargetG, 144);
    expect(r.fatTargetG, 72);
    expect(r.carbsTargetG, 270);
  });

  test('input helpers: plausible ranges and 1,68 m as 168 cm', () {
    expect(NutritionGoalCalculator.normalizeHeightCm(1.68), 168);
    expect(NutritionGoalCalculator.normalizeHeightCm(176), 176);
    expect(NutritionGoalCalculator.isPlausibleHeightCm(99), isFalse);
    expect(NutritionGoalCalculator.isPlausibleWeightKg(30), isTrue);
    expect(NutritionGoalCalculator.isPlausibleAge(12), isFalse);
    expect(NutritionGoalCalculator.isPlausibleAge(110), isTrue);
  });

  group('goal model', () {
    final base = NutritionGoal(
      userId: 'u1',
      goalType: NutritionGoalType.loseWeight,
      targetWeightKg: 70,
      pace: GoalPace.normal,
      creditWorkouts: true,
      dailyCalorieTarget: 2000,
      createdAt: DateTime.utc(2026, 11, 2),
      updatedAt: DateTime.utc(2026, 11, 2),
    );

    test('reads and writes credit_workouts and pace', () {
      final json = base.toUpsertJson(schemaV2: true);
      expect(json['credit_workouts'], true);
      expect(json['pace'], 'normal');
      final copy = NutritionGoal.fromJson({
        ...json,
        'created_at': '2026-11-02T00:00:00Z',
        'updated_at': '2026-11-02T00:00:00Z',
      });
      expect(copy.creditWorkouts, isTrue);
      expect(copy.pace, GoalPace.normal);
    });

    test('before the migration the new columns are not sent', () {
      final json = base.toUpsertJson(schemaV2: false);
      expect(json.containsKey('credit_workouts'), isFalse);
      expect(json.containsKey('pace'), isFalse);
    });

    test('copyWith can clear the target weight and pace', () {
      final kept = base.copyWith(goalType: NutritionGoalType.maintain);
      expect(kept.targetWeightKg, 70);
      final cleared = base.copyWith(
        goalType: NutritionGoalType.maintain,
        clearTargetWeight: true,
        clearPace: true,
      );
      expect(cleared.targetWeightKg, isNull);
      expect(cleared.pace, isNull);
      expect(cleared.creditWorkouts, isTrue);
    });
  });
}
