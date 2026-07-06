import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A calculated goal, ready to save — [NutritionGoalCalculator.calculate]'s
/// output before it's persisted.
class CalculatedTargets {
  final int dailyCalorieTarget;
  final int proteinTargetG;
  final int carbsTargetG;
  final int fatTargetG;

  const CalculatedTargets({
    required this.dailyCalorieTarget,
    required this.proteinTargetG,
    required this.carbsTargetG,
    required this.fatTargetG,
  });
}

/// Calorie/macro target calculation — Mifflin-St Jeor BMR, scaled by
/// activity level, then adjusted for the user's goal.
///
/// Mifflin-St Jeor (more accurate than Harris-Benedict for modern
/// populations):
///   men:   10*kg + 6.25*cm - 5*age + 5
///   women: 10*kg + 6.25*cm - 5*age - 161
/// TDEE = BMR * activity factor.
/// Weight-loss/gain deficit/surplus is derived from the timeline: a safe
/// ~0.5-1% of body weight per week is assumed via a 500 kcal/day default
/// deficit-or-surplus, capped so a very short timeline can't produce an
/// unsafe target (never below 1200 kcal for women / 1500 for men, never
/// requiring more than a ~1kg/week rate of change).
class NutritionGoalCalculator {
  static CalculatedTargets calculate({
    required NutritionGoalType goalType,
    required ActivityLevel activityLevel,
    required double currentWeightKg,
    required double heightCm,
    required int age,
    required String gender,
    double? targetWeightKg,
    int? timelineWeeks,
  }) {
    final isFemale = gender == 'female';
    final bmr = 10 * currentWeightKg + 6.25 * heightCm - 5 * age + (isFemale ? -161 : 5);
    final tdee = bmr * activityLevel.factor;

    double calorieTarget = tdee;
    final minCalories = isFemale ? 1200.0 : 1500.0;

    if (goalType == NutritionGoalType.loseWeight || goalType == NutritionGoalType.gainMuscle) {
      final weightDeltaKg = (targetWeightKg != null)
          ? (targetWeightKg - currentWeightKg).abs()
          : 0.5 * (timelineWeeks ?? 12) / 4; // fallback: ~0.5kg/month pace
      final weeks = (timelineWeeks ?? 12).clamp(4, 104);
      // 1 kg of body mass ~= 7700 kcal.
      final dailyDelta = weightDeltaKg == 0
          ? 500.0
          : ((weightDeltaKg * 7700) / (weeks * 7)).clamp(200.0, 1000.0);
      calorieTarget = goalType == NutritionGoalType.loseWeight
          ? tdee - dailyDelta
          : tdee + dailyDelta;
    }

    calorieTarget = calorieTarget.clamp(minCalories, 6000);

    // Macros: protein prioritized (higher for muscle gain / weight loss to
    // preserve lean mass), remainder split between carbs and fat.
    final proteinPerKg = switch (goalType) {
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
    );
  }
}

/// CRUD for the single `nutrition_goals` row per user.
class NutritionGoalService {
  NutritionGoalService._();
  static final NutritionGoalService instance = NutritionGoalService._();

  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<NutritionGoal?> getGoal() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final response = await _supabase
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return NutritionGoal.fromJson(response);
    } catch (e) {
      debugPrint('⚠️ [NutritionGoal] Failed to load: $e');
      return null;
    }
  }

  /// Enables/disables tracking without touching any other field — used by
  /// the navbar toggle before a full goal has ever been configured.
  Future<NutritionGoal> setTrackingEnabled(bool enabled) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    final response = await _supabase
        .from('nutrition_goals')
        .upsert({
          'user_id': userId,
          'calorie_tracking_enabled': enabled,
        })
        .select()
        .single();
    return NutritionGoal.fromJson(response);
  }

  Future<NutritionGoal> saveGoal(NutritionGoal goal) async {
    final response = await _supabase
        .from('nutrition_goals')
        .upsert(goal.toUpsertJson())
        .select()
        .single();
    return NutritionGoal.fromJson(response);
  }
}
