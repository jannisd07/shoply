import 'package:equatable/equatable.dart';

enum NutritionGoalType { loseWeight, gainMuscle, maintain, custom }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension NutritionGoalTypeX on NutritionGoalType {
  String get dbValue => switch (this) {
        NutritionGoalType.loseWeight => 'lose_weight',
        NutritionGoalType.gainMuscle => 'gain_muscle',
        NutritionGoalType.maintain => 'maintain',
        NutritionGoalType.custom => 'custom',
      };

  static NutritionGoalType fromDb(String value) => switch (value) {
        'lose_weight' => NutritionGoalType.loseWeight,
        'gain_muscle' => NutritionGoalType.gainMuscle,
        'custom' => NutritionGoalType.custom,
        _ => NutritionGoalType.maintain,
      };
}

extension ActivityLevelX on ActivityLevel {
  String get dbValue => switch (this) {
        ActivityLevel.sedentary => 'sedentary',
        ActivityLevel.light => 'light',
        ActivityLevel.moderate => 'moderate',
        ActivityLevel.active => 'active',
        ActivityLevel.veryActive => 'very_active',
      };

  /// Multiplier applied to BMR to estimate total daily energy expenditure
  /// (standard Harris/Mifflin activity-factor table).
  double get factor => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  static ActivityLevel fromDb(String value) => switch (value) {
        'sedentary' => ActivityLevel.sedentary,
        'light' => ActivityLevel.light,
        'active' => ActivityLevel.active,
        'very_active' => ActivityLevel.veryActive,
        _ => ActivityLevel.moderate,
      };
}

/// Tempo for losing or gaining weight (replaces the old `Slider` and the
/// "Zeitraum" in weeks; `timeline_weeks` stays readable).
enum GoalPace { gemuetlich, normal, zuegig }

extension GoalPaceX on GoalPace {
  String get dbValue => name;

  static GoalPace? fromDb(String? value) => switch (value) {
        'gemuetlich' => GoalPace.gemuetlich,
        'normal' => GoalPace.normal,
        'zuegig' => GoalPace.zuegig,
        _ => null,
      };

  /// kg per week: losing 0.25 / 0.5 / 0.75, gaining 0.1 / 0.25 / 0.4
  /// (concept 15 3.14). 0 for "maintain"/"custom".
  double kgPerWeek(NutritionGoalType goal) => switch (goal) {
        NutritionGoalType.loseWeight => const [0.25, 0.5, 0.75][index],
        NutritionGoalType.gainMuscle => const [0.1, 0.25, 0.4][index],
        _ => 0,
      };
}

/// A user's calorie/macro targets and the inputs used to calculate them.
/// One row per user (`user_id` is the primary key on the server).
class NutritionGoal extends Equatable {
  final String userId;
  final bool calorieTrackingEnabled;
  final NutritionGoalType goalType;
  final ActivityLevel activityLevel;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final double? heightCm;
  final int? timelineWeeks;
  final int? dailyCalorieTarget;
  final int? proteinTargetG;
  final int? carbsTargetG;
  final int? fatTargetG;
  final int waterTargetMl;

  /// "Verbrauch durch Workouts gutschreiben" (default off, concept 15 2.2).
  final bool creditWorkouts;
  final GoalPace? pace;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionGoal({
    required this.userId,
    this.calorieTrackingEnabled = false,
    this.goalType = NutritionGoalType.maintain,
    this.activityLevel = ActivityLevel.moderate,
    this.currentWeightKg,
    this.targetWeightKg,
    this.heightCm,
    this.timelineWeeks,
    this.dailyCalorieTarget,
    this.proteinTargetG,
    this.carbsTargetG,
    this.fatTargetG,
    this.waterTargetMl = 2000,
    this.creditWorkouts = false,
    this.pace,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the goal has enough inputs (and calculated targets) to power
  /// the dashboard — vs. a freshly-enabled toggle with no answers yet.
  bool get isConfigured => dailyCalorieTarget != null;

  factory NutritionGoal.fromJson(Map<String, dynamic> json) {
    return NutritionGoal(
      userId: json['user_id'] as String,
      calorieTrackingEnabled: json['calorie_tracking_enabled'] as bool? ?? false,
      goalType: NutritionGoalTypeX.fromDb(json['goal_type'] as String? ?? 'maintain'),
      activityLevel: ActivityLevelX.fromDb(json['activity_level'] as String? ?? 'moderate'),
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      timelineWeeks: json['timeline_weeks'] as int?,
      dailyCalorieTarget: json['daily_calorie_target'] as int?,
      proteinTargetG: json['protein_target_g'] as int?,
      carbsTargetG: json['carbs_target_g'] as int?,
      fatTargetG: json['fat_target_g'] as int?,
      waterTargetMl: json['water_target_ml'] as int? ?? 2000,
      creditWorkouts: json['credit_workouts'] as bool? ?? false,
      pace: GoalPaceX.fromDb(json['pace'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Row for `nutrition_goals`. The B6 columns (`credit_workouts`, `pace`)
  /// are only sent once the migration is applied ([schemaV2]).
  Map<String, dynamic> toUpsertJson({bool schemaV2 = false}) {
    return {
      'user_id': userId,
      'calorie_tracking_enabled': calorieTrackingEnabled,
      'goal_type': goalType.dbValue,
      'activity_level': activityLevel.dbValue,
      'current_weight_kg': currentWeightKg,
      'target_weight_kg': targetWeightKg,
      'height_cm': heightCm,
      'timeline_weeks': timelineWeeks,
      'daily_calorie_target': dailyCalorieTarget,
      'protein_target_g': proteinTargetG,
      'carbs_target_g': carbsTargetG,
      'fat_target_g': fatTargetG,
      'water_target_ml': waterTargetMl,
      if (schemaV2) ...{
        'credit_workouts': creditWorkouts,
        'pace': pace?.dbValue,
      },
    };
  }

  NutritionGoal copyWith({
    bool? calorieTrackingEnabled,
    NutritionGoalType? goalType,
    ActivityLevel? activityLevel,
    double? currentWeightKg,
    double? targetWeightKg,
    double? heightCm,
    int? timelineWeeks,
    int? dailyCalorieTarget,
    int? proteinTargetG,
    int? carbsTargetG,
    int? fatTargetG,
    int? waterTargetMl,
    bool? creditWorkouts,
    GoalPace? pace,
    bool clearTargetWeight = false,
    bool clearTimeline = false,
    bool clearPace = false,
  }) {
    return NutritionGoal(
      userId: userId,
      calorieTrackingEnabled: calorieTrackingEnabled ?? this.calorieTrackingEnabled,
      goalType: goalType ?? this.goalType,
      activityLevel: activityLevel ?? this.activityLevel,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: clearTargetWeight ? null : (targetWeightKg ?? this.targetWeightKg),
      heightCm: heightCm ?? this.heightCm,
      timelineWeeks: clearTimeline ? null : (timelineWeeks ?? this.timelineWeeks),
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      proteinTargetG: proteinTargetG ?? this.proteinTargetG,
      carbsTargetG: carbsTargetG ?? this.carbsTargetG,
      fatTargetG: fatTargetG ?? this.fatTargetG,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      creditWorkouts: creditWorkouts ?? this.creditWorkouts,
      pace: clearPace ? null : (pace ?? this.pace),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        userId,
        calorieTrackingEnabled,
        goalType,
        activityLevel,
        currentWeightKg,
        targetWeightKg,
        heightCm,
        timelineWeeks,
        dailyCalorieTarget,
        proteinTargetG,
        carbsTargetG,
        fatTargetG,
        waterTargetMl,
        creditWorkouts,
        pace,
      ];
}
