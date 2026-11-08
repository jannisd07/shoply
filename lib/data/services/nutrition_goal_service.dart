import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// A calculated goal, ready to save — [NutritionGoalCalculator.calculate]'s
/// output before it's persisted. The fields after the four targets are
/// additive (B6) and tell the goal form what to explain.
class CalculatedTargets {
  final int dailyCalorieTarget;
  final int proteinTargetG;
  final int carbsTargetG;
  final int fatTargetG;

  /// kg per week the target really implies (after the 200–1000 kcal limits
  /// and the lower bound); null for maintain/custom.
  final double? effectiveKgPerWeek;

  /// Weeks until the target weight at [effectiveKgPerWeek]; null without a
  /// target, without progress or with [targetWeightConflict].
  final double? estimatedWeeksToTarget;

  /// The target hit the lower bound: "Für ein schnelleres Tempo müsstest du
  /// unter {floor} kcal essen. Wir rechnen nicht darunter."
  final bool floorReached;
  final int floorKcal;

  /// Under 18 and "Abnehmen": maintenance was calculated instead.
  final bool weightLossBlockedForMinor;

  /// Losing with a target above the current weight (or gaining below it):
  /// the form asks "Meinst du „Muskeln aufbauen“?".
  final bool targetWeightConflict;

  const CalculatedTargets({
    required this.dailyCalorieTarget,
    required this.proteinTargetG,
    required this.carbsTargetG,
    required this.fatTargetG,
    this.effectiveKgPerWeek,
    this.estimatedWeeksToTarget,
    this.floorReached = false,
    this.floorKcal = 1200,
    this.weightLossBlockedForMinor = false,
    this.targetWeightConflict = false,
  });
}

/// Calorie/macro target calculation — Mifflin-St Jeor BMR, scaled by
/// activity level, then adjusted for the user's goal. Stable API for Teil A's
/// onboarding: new parameters are optional, old calls compute as before.
///
/// Mifflin-St Jeor (more accurate than Harris-Benedict for modern
/// populations):
///   men:   10*kg + 6.25*cm - 5*age + 5
///   women: 10*kg + 6.25*cm - 5*age - 161
///   divers / no answer: the average of both (concept 15 F-K7)
/// TDEE = BMR * activity factor.
/// The daily deficit/surplus comes from [GoalPace] (kg per week) when given,
/// else from target weight and timeline as before; either way it stays
/// within 200–1000 kcal and never goes below 1200 kcal (women, divers) or
/// 1500 kcal (men). Under 18 there is no weight-loss target.
class NutritionGoalCalculator {
  static const int minAdultAgeForWeightLoss = 18;

  static bool weightLossAllowed(int age) => age >= minAdultAgeForWeightLoss;

  /// "1,68" typed into the height field means metres.
  static double normalizeHeightCm(double value) =>
      value > 0 && value < 3 ? value * 100 : value;

  static bool isPlausibleHeightCm(double cm) => cm >= 100 && cm <= 250;
  static bool isPlausibleWeightKg(double kg) => kg >= 30 && kg <= 300;
  static bool isPlausibleAge(int age) => age >= 13 && age <= 110;

  static CalculatedTargets calculate({
    required NutritionGoalType goalType,
    required ActivityLevel activityLevel,
    required double currentWeightKg,
    required double heightCm,
    required int age,
    required String gender,
    double? targetWeightKg,
    int? timelineWeeks,
    GoalPace? pace,
  }) {
    final base = 10 * currentWeightKg + 6.25 * heightCm - 5 * age;
    final g = gender.toLowerCase();
    final isMale = g == 'male';
    final isFemale = g == 'female';
    final bmr = isMale
        ? base + 5
        : isFemale
            ? base - 161
            : base - 78; // average of +5 and -161
    final tdee = bmr * activityLevel.factor;
    final minCalories = isMale ? 1500.0 : 1200.0;

    final blockedForMinor =
        goalType == NutritionGoalType.loseWeight && !weightLossAllowed(age);
    final effectiveGoal = blockedForMinor ? NutritionGoalType.maintain : goalType;
    final changesWeight = effectiveGoal == NutritionGoalType.loseWeight ||
        effectiveGoal == NutritionGoalType.gainMuscle;
    final losing = effectiveGoal == NutritionGoalType.loseWeight;

    final targetWeightConflict = targetWeightKg != null &&
        changesWeight &&
        (losing ? targetWeightKg > currentWeightKg : targetWeightKg < currentWeightKg);

    double calorieTarget = tdee;
    double dailyDelta = 0;
    if (changesWeight) {
      if (pace != null) {
        dailyDelta = (pace.kgPerWeek(effectiveGoal) * 7700 / 7).clamp(200.0, 1000.0);
      } else {
        final weightDeltaKg = (targetWeightKg != null)
            ? (targetWeightKg - currentWeightKg).abs()
            : 0.5 * (timelineWeeks ?? 12) / 4; // fallback: ~0.5kg/month pace
        final weeks = (timelineWeeks ?? 12).clamp(4, 104);
        // 1 kg of body mass ~= 7700 kcal.
        dailyDelta = weightDeltaKg == 0
            ? 500.0
            : ((weightDeltaKg * 7700) / (weeks * 7)).clamp(200.0, 1000.0);
      }
      calorieTarget = losing ? tdee - dailyDelta : tdee + dailyDelta;
    }

    final floorReached = calorieTarget < minCalories;
    calorieTarget = calorieTarget.clamp(minCalories, 6000);

    double? effectiveKgPerWeek;
    double? weeksToTarget;
    if (changesWeight) {
      final realDelta = (calorieTarget - tdee).abs();
      effectiveKgPerWeek = realDelta * 7 / 7700;
      if (targetWeightKg != null && !targetWeightConflict && effectiveKgPerWeek > 0) {
        weeksToTarget = (targetWeightKg - currentWeightKg).abs() / effectiveKgPerWeek;
      }
    }

    // Macros: protein prioritized (higher for muscle gain / weight loss to
    // preserve lean mass), remainder split between carbs and fat.
    final proteinPerKg = switch (effectiveGoal) {
      NutritionGoalType.gainMuscle => 2.0,
      NutritionGoalType.loseWeight => 1.8,
      _ => 1.4,
    };
    final proteinG = (proteinPerKg * currentWeightKg).round();
    final proteinKcal = proteinG * 4;
    final fatKcal = calorieTarget * 0.28;
    final fatG = (fatKcal / 9).round();
    final remainingKcal = (calorieTarget - proteinKcal - fatKcal).clamp(0, calorieTarget);
    final carbsG = (remainingKcal / 4).round();

    return CalculatedTargets(
      dailyCalorieTarget: calorieTarget.round(),
      proteinTargetG: proteinG,
      carbsTargetG: carbsG,
      fatTargetG: fatG,
      effectiveKgPerWeek: effectiveKgPerWeek,
      estimatedWeeksToTarget: weeksToTarget,
      floorReached: floorReached,
      floorKcal: minCalories.round(),
      weightLossBlockedForMinor: blockedForMinor,
      targetWeightConflict: targetWeightConflict,
    );
  }
}

/// CRUD for the single `nutrition_goals` row per user. Throws
/// [CalorieDataException] on failure: `getGoal` returns null only when the
/// user really has no goal, never because the network failed (Inv. 4.1).
class NutritionGoalService {
  NutritionGoalService._();
  static final NutritionGoalService instance = NutritionGoalService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _schemaV2 =>
      AppFlagsService.instance.current.isEnabled(calorieSchemaV2FlagKey, fallback: false);

  String _userId() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      final error = CalorieDataException.from(e);
      debugPrint('❌ [NutritionGoal] $what failed: ${error.code.name} ($e)');
      throw error;
    }
  }

  Future<NutritionGoal?> getGoal() => _guard('Loading', () async {
        final response = await _supabase
            .from('nutrition_goals')
            .select()
            .eq('user_id', _userId())
            .maybeSingle();
        return response == null ? null : NutritionGoal.fromJson(response);
      });

  /// Enables/disables the legacy server switch without touching any other
  /// field (mirrors `AppModule.calories`).
  Future<NutritionGoal> setTrackingEnabled(bool enabled) => _guard('Saving switch', () async {
        final response = await _supabase
            .from('nutrition_goals')
            .upsert({'user_id': _userId(), 'calorie_tracking_enabled': enabled})
            .select()
            .single();
        return NutritionGoal.fromJson(response);
      });

  Future<NutritionGoal> saveGoal(NutritionGoal goal) => _guard('Saving goal', () async {
        _userId();
        final response = await _supabase
            .from('nutrition_goals')
            .upsert(goal.toUpsertJson(schemaV2: _schemaV2))
            .select()
            .single();
        return NutritionGoal.fromJson(response);
      });
}
