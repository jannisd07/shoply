import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/diet_preferences.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';

/// Accounts created before this moment count as set up, even when
/// `users.onboarding_completed` is still null (Konzept 17 §1.2, §9.6).
///
/// Stand-in for the backfill migration (all accounts that exist before the
/// release get `onboarding_completed = true`) until the owner applies it:
/// without either, an old account signing in on a new device would be
/// treated as new and could get its diet overwritten. Set it to the release
/// day of the new onboarding; once the backfill ran it may stay as it is.
final DateTime kOnboardingRedesignCutoff = DateTime.utc(2026, 11, 9);

/// What the flow learns right after a sign-in (Konzept 17 §1.2, §5.3).
enum AccountSetupStatus {
  /// Not set up yet: the answers from before the account are written into it
  /// and the flow goes on with Name.
  isNew,

  /// Set up before: local answers are dropped, the list of today opens.
  setUp,
}

/// Decides new or set up without a server change: set up when the flag says
/// so or when the account is older than [cutoff] (default
/// [kOnboardingRedesignCutoff]).
AccountSetupStatus decideAccountStatus({
  bool? onboardingCompleted,
  DateTime? createdAt,
  DateTime? cutoff,
}) {
  if (onboardingCompleted == true) return AccountSetupStatus.setUp;
  final limit = cutoff ?? kOnboardingRedesignCutoff;
  if (createdAt != null && createdAt.isBefore(limit)) {
    return AccountSetupStatus.setUp;
  }
  return AccountSetupStatus.isNew;
}

/// Diet chips of the onboarding (Konzept 17 §3.9). The three "frei von" ids
/// (`gluten_free`, `dairy_free`, `nut_free`) are chosen through allergies
/// instead (§9.7).
const List<String> kOnboardingDietIds = [
  'vegetarian',
  'vegan',
  'pescatarian',
  'low_carb',
  'keto',
  'paleo',
  'halal',
  'kosher',
  'low_sodium',
];

/// Allergy chips shown at once: the 14 EU allergens plus lactose, in the
/// order of Konzept 17 §3.9.
const List<AllergyType> kOnboardingAllergies = [
  AllergyType.gluten,
  AllergyType.milk,
  AllergyType.lactose,
  AllergyType.eggs,
  AllergyType.peanuts,
  AllergyType.nuts,
  AllergyType.soy,
  AllergyType.fish,
  AllergyType.crustaceans,
  AllergyType.molluscs,
  AllergyType.celery,
  AllergyType.mustard,
  AllergyType.sesame,
  AllergyType.sulfites,
  AllergyType.lupin,
];

/// Behind "Weitere anzeigen".
const List<AllergyType> kOnboardingMoreAllergies = [
  AllergyType.fructose,
  AllergyType.histamine,
  AllergyType.nightshades,
  AllergyType.corn,
  AllergyType.yeast,
];

/// The two columns written for a diet and allergy choice (Konzept 17 §9.7):
/// a gluten allergy also sets `gluten_free`, milk or lactose `dairy_free`,
/// tree nuts or peanuts `nut_free`, so recipe filters and swaps keep working.
({List<String> dietPreferences, List<String> allergies}) mergeDietAndAllergies({
  required Set<String> diet,
  required Set<String> allergies,
}) {
  final out = <String>{
    for (final id in diet)
      if (kDietPreferenceIds.contains(id)) id,
  };
  if (allergies.contains(AllergyType.gluten.name)) out.add('gluten_free');
  if (allergies.contains(AllergyType.milk.name) ||
      allergies.contains(AllergyType.lactose.name)) {
    out.add('dairy_free');
  }
  if (allergies.contains(AllergyType.nuts.name) ||
      allergies.contains(AllergyType.peanuts.name)) {
    out.add('nut_free');
  }
  final names = AllergyType.values.map((t) => t.name).toSet();
  return (
    dietPreferences: [
      for (final id in kDietPreferenceIds)
        if (out.contains(id)) id,
    ],
    allergies: [
      for (final t in AllergyType.values)
        if (allergies.contains(t.name) && names.contains(t.name)) t.name,
    ],
  );
}

/// Allergy chips implied by old diet values without allergies (Konzept 17
/// §9.7, for settings that load data saved before the merge).
Set<String> allergiesImpliedByDiet(Iterable<String> diet) => {
  if (diet.contains('gluten_free')) AllergyType.gluten.name,
  if (diet.contains('dairy_free')) AllergyType.lactose.name,
  if (diet.contains('nut_free')) AllergyType.nuts.name,
};

/// The answers of "Dein Ziel" (Konzept 17 §3.10), as far as they are known.
@immutable
class OnboardingGoalDraft {
  const OnboardingGoalDraft({
    this.goalType = NutritionGoalType.loseWeight,
    this.activityLevel = ActivityLevel.light,
    this.gender,
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.timelineWeeks = 16,
    this.customCalories,
  });

  final NutritionGoalType goalType;
  final ActivityLevel activityLevel;

  /// `female`, `male` or `other`; null computes with the average of both
  /// formulas like "Divers".
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final int timelineWeeks;

  /// "Eigenes Ziel": kcal per day typed by the person.
  final int? customCalories;

  bool get needsTargetWeight =>
      goalType == NutritionGoalType.loseWeight ||
      goalType == NutritionGoalType.gainMuscle;

  /// Enough plausible data for an estimate.
  bool get isComplete {
    if (goalType == NutritionGoalType.custom) {
      final kcal = customCalories;
      return kcal != null && kcal >= 800 && kcal <= 6000;
    }
    final a = age, h = heightCm, w = currentWeightKg;
    return a != null &&
        h != null &&
        w != null &&
        NutritionGoalCalculator.isPlausibleAge(a) &&
        NutritionGoalCalculator.isPlausibleHeightCm(h) &&
        NutritionGoalCalculator.isPlausibleWeightKg(w);
  }

  /// The estimate through Teil B's stable API; null while incomplete or for
  /// "Eigenes Ziel".
  CalculatedTargets? targets() {
    if (!isComplete || goalType == NutritionGoalType.custom) return null;
    final target = needsTargetWeight ? targetWeightKg : null;
    return NutritionGoalCalculator.calculate(
      goalType: goalType,
      activityLevel: activityLevel,
      currentWeightKg: currentWeightKg!,
      heightCm: heightCm!,
      age: age!,
      gender: gender ?? 'other',
      targetWeightKg: target,
      timelineWeeks: target == null ? null : timelineWeeks,
    );
  }

  OnboardingGoalDraft copyWith({
    NutritionGoalType? goalType,
    ActivityLevel? activityLevel,
    String? gender,
    int? Function()? age,
    double? Function()? heightCm,
    double? Function()? currentWeightKg,
    double? Function()? targetWeightKg,
    int? timelineWeeks,
    int? Function()? customCalories,
  }) => OnboardingGoalDraft(
    goalType: goalType ?? this.goalType,
    activityLevel: activityLevel ?? this.activityLevel,
    gender: gender ?? this.gender,
    age: age == null ? this.age : age(),
    heightCm: heightCm == null ? this.heightCm : heightCm(),
    currentWeightKg: currentWeightKg == null
        ? this.currentWeightKg
        : currentWeightKg(),
    targetWeightKg: targetWeightKg == null
        ? this.targetWeightKg
        : targetWeightKg(),
    timelineWeeks: timelineWeeks ?? this.timelineWeeks,
    customCalories: customCalories == null
        ? this.customCalories
        : customCalories(),
  );

  Map<String, Object?> toJson() => {
    'goal_type': goalType.dbValue,
    'activity_level': activityLevel.dbValue,
    'gender': gender,
    'age': age,
    'height_cm': heightCm,
    'current_weight_kg': currentWeightKg,
    'target_weight_kg': targetWeightKg,
    'timeline_weeks': timelineWeeks,
    'custom_calories': customCalories,
  };

  factory OnboardingGoalDraft.fromJson(Map<String, Object?> json) {
    NutritionGoalType goal = NutritionGoalType.loseWeight;
    ActivityLevel activity = ActivityLevel.light;
    try {
      goal = NutritionGoalTypeX.fromDb(json['goal_type'] as String? ?? '');
    } catch (_) {}
    try {
      activity = ActivityLevelX.fromDb(json['activity_level'] as String? ?? '');
    } catch (_) {}
    return OnboardingGoalDraft(
      goalType: goal,
      activityLevel: activity,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      timelineWeeks: (json['timeline_weeks'] as num?)?.toInt() ?? 16,
      customCalories: (json['custom_calories'] as num?)?.toInt(),
    );
  }
}

/// What the flow writes into the account (Konzept 17 §1.2). Every write is a
/// targeted update of its own columns, never the whole `users` row
/// (Inventar Bug 15). Overridden in tests.
abstract interface class OnboardingAccountBackend {
  /// New or set up (see [decideAccountStatus]). Creates the `users` row when
  /// it does not exist yet. Throws on network errors.
  Future<AccountSetupStatus> accountStatus();

  /// `users.diet_preferences` and `users.allergies`.
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  });

  /// `nutrition_goals`, the first `weight_logs` entry of the day (upsert, so
  /// a second call does not add one) and `users.age/height/gender`.
  Future<void> saveGoal(OnboardingGoalDraft draft);

  /// The legacy server switch for calories when the goal was skipped.
  Future<void> enableCalorieTracking();

  /// `users.onboarding_completed = true`, at the very end (§1.2).
  Future<void> markCompleted();

  /// The list to open for a set-up account: the last opened on this device,
  /// else the first of the account; null without lists.
  Future<String?> lastListId();
}

/// The Supabase implementation.
class OnboardingAnswersService implements OnboardingAccountBackend {
  OnboardingAnswersService._();
  static final OnboardingAnswersService instance = OnboardingAnswersService._();

  String _uid() {
    final id = SupabaseService.instance.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  @override
  Future<AccountSetupStatus> accountStatus() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final row = await SupabaseService.instance
        .from('users')
        .select('onboarding_completed, created_at')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) {
      // First sign-in: the row the rest of the flow updates. No name from
      // the e-mail address (Inventar Bug 13); Name fills it.
      final now = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.instance
          .from('users')
          .upsert(
            {
              'id': user.id,
              'email': user.email,
              'auth_provider': user.appMetadata['provider'],
              'created_at': now,
              'updated_at': now,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          );
      return decideAccountStatus(createdAt: DateTime.tryParse(user.createdAt));
    }
    return decideAccountStatus(
      onboardingCompleted: row['onboarding_completed'] as bool?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.tryParse(user.createdAt),
    );
  }

  @override
  Future<void> saveDiet({
    required List<String> dietPreferences,
    required List<String> allergies,
  }) async {
    await SupabaseService.instance
        .from('users')
        .update({
          'diet_preferences': dietPreferences,
          'allergies': allergies,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _uid());
  }

  @override
  Future<void> saveGoal(OnboardingGoalDraft draft) async {
    final userId = _uid();
    final now = DateTime.now();
    final targets = draft.targets();
    final custom = draft.goalType == NutritionGoalType.custom;
    await NutritionGoalService.instance.saveGoal(
      NutritionGoal(
        userId: userId,
        calorieTrackingEnabled: true,
        goalType: draft.goalType,
        activityLevel: draft.activityLevel,
        currentWeightKg: custom ? null : draft.currentWeightKg,
        targetWeightKg: draft.needsTargetWeight ? draft.targetWeightKg : null,
        heightCm: custom ? null : draft.heightCm,
        timelineWeeks: draft.needsTargetWeight && draft.targetWeightKg != null
            ? draft.timelineWeeks
            : null,
        dailyCalorieTarget: custom
            ? draft.customCalories
            : targets?.dailyCalorieTarget,
        proteinTargetG: targets?.proteinTargetG,
        carbsTargetG: targets?.carbsTargetG,
        fatTargetG: targets?.fatTargetG,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (custom) return;
    final weight = draft.currentWeightKg;
    if (weight != null) {
      await WeightLogService.instance.upsertForDate(
        weightKg: weight,
        date: now,
      );
    }
    await SupabaseService.instance
        .from('users')
        .update({
          'age': draft.age,
          'height': draft.heightCm,
          'height_unit': 'cm',
          'gender': draft.gender,
        })
        .eq('id', userId);
  }

  @override
  Future<void> enableCalorieTracking() async {
    await NutritionGoalService.instance.setTrackingEnabled(true);
  }

  @override
  Future<void> markCompleted() async {
    await SupabaseService.instance
        .from('users')
        .update({
          'onboarding_completed': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _uid());
  }

  @override
  Future<String?> lastListId() async {
    final userId = _uid();
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString('last_accessed_list_$userId');
      if (last != null && last.isNotEmpty) return last;
    } catch (e) {
      debugPrint('⚠️ [Onboarding] Reading the last list failed: $e');
    }
    final lists = await ListRepository.instance.getUserLists().timeout(
      const Duration(seconds: 8),
    );
    return lists.isEmpty ? null : lists.first.id;
  }
}

/// Override in tests.
final onboardingBackendProvider = Provider<OnboardingAccountBackend>(
  (ref) => OnboardingAnswersService.instance,
);
