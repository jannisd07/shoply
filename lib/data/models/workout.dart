import 'package:equatable/equatable.dart';

/// Kind of workout. The DB stores [dbValue] (`workout_log.type` check).
enum WorkoutType {
  running,
  walking,
  cycling,
  swimming,
  strength,
  yoga,
  hiit,
  hiking,
  dance,
  other,
}

extension WorkoutTypeX on WorkoutType {
  String get dbValue => name;

  static WorkoutType fromDb(String? value) => WorkoutType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => WorkoutType.other,
      );
}

enum WorkoutIntensity { light, moderate, hard }

extension WorkoutIntensityX on WorkoutIntensity {
  String get dbValue => name;

  static WorkoutIntensity fromDb(String? value) =>
      WorkoutIntensity.values.firstWhere(
        (i) => i.name == value,
        orElse: () => WorkoutIntensity.moderate,
      );
}

/// Where a workout row comes from. Health workouts are shown on this device
/// only and never written to Supabase (concept 15 2.4, F-K5).
enum WorkoutSource { own, health }

/// Metabolic equivalents per type and intensity, rounded from the
/// Compendium of Physical Activities (Ainsworth et al., 2011/2024).
/// kcal = MET x body weight in kg x hours. No AI involved (concept 15 3.18).
abstract final class WorkoutMet {
  static const Map<WorkoutType, List<double>> table = {
    WorkoutType.running: [7.0, 9.8, 11.5],
    WorkoutType.walking: [2.8, 3.5, 5.0],
    WorkoutType.cycling: [4.0, 6.8, 10.0],
    WorkoutType.swimming: [5.8, 8.3, 9.8],
    WorkoutType.strength: [3.5, 5.0, 6.0],
    WorkoutType.yoga: [2.5, 3.0, 4.0],
    WorkoutType.hiit: [5.0, 8.0, 10.0],
    WorkoutType.hiking: [5.3, 6.0, 7.8],
    WorkoutType.dance: [3.0, 5.0, 7.3],
    WorkoutType.other: [3.0, 4.5, 6.5],
  };

  static double of(WorkoutType type, WorkoutIntensity intensity) =>
      table[type]![intensity.index];
}

/// Result of [estimateWorkoutCalories]. [usedDefaultWeight] drives the hint
/// "Mit deinem Gewicht wird die Schätzung genauer."
class WorkoutCalorieEstimate extends Equatable {
  final int kcal;
  final double weightKg;
  final bool usedDefaultWeight;

  const WorkoutCalorieEstimate({
    required this.kcal,
    required this.weightKg,
    required this.usedDefaultWeight,
  });

  @override
  List<Object?> get props => [kcal, weightKg, usedDefaultWeight];
}

/// Weight assumed when none is known (concept 15 3.18: "70 kg").
const double defaultWorkoutWeightKg = 70;

WorkoutCalorieEstimate estimateWorkoutCalories({
  required WorkoutType type,
  required WorkoutIntensity intensity,
  required int durationMin,
  double? weightKg,
}) {
  final known = weightKg != null && weightKg > 0;
  final kg = known ? weightKg : defaultWorkoutWeightKg;
  final minutes = durationMin < 0 ? 0 : durationMin;
  final kcal = WorkoutMet.of(type, intensity) * kg * minutes / 60;
  return WorkoutCalorieEstimate(
    kcal: kcal.round(),
    weightKg: kg,
    usedDefaultWeight: !known,
  );
}

/// One workout: own rows live in `workout_log`, Health rows only in memory.
class Workout extends Equatable {
  final String id;
  final String userId;
  final DateTime startedAt;
  final int durationMin;
  final WorkoutType type;
  final WorkoutIntensity intensity;
  final int? calories;
  final String? healthUuid;
  final WorkoutSource source;

  /// Name of the writing app or device for Health rows ("Apple Watch").
  final String? sourceName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Workout({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.durationMin,
    required this.type,
    this.intensity = WorkoutIntensity.moderate,
    this.calories,
    this.healthUuid,
    this.source = WorkoutSource.own,
    this.sourceName,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isReadOnly => source == WorkoutSource.health;

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      startedAt: DateTime.parse(json['started_at'] as String),
      durationMin: (json['duration_min'] as num).toInt(),
      type: WorkoutTypeX.fromDb(json['type'] as String?),
      intensity: WorkoutIntensityX.fromDb(json['intensity'] as String?),
      calories: (json['calories'] as num?)?.toInt(),
      healthUuid: json['health_uuid'] as String?,
      source: json['source'] == 'health' ? WorkoutSource.health : WorkoutSource.own,
      sourceName: json['source_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Row for `workout_log` (insert or upsert by [id]).
  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'user_id': userId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'duration_min': durationMin,
        'type': type.dbValue,
        'intensity': intensity.dbValue,
        'calories': calories,
        'health_uuid': healthUuid,
      };

  /// Full local snapshot (day store), including the Health-only fields.
  Map<String, dynamic> toJson() => {
        ...toUpsertJson(),
        'source': source.name,
        'source_name': sourceName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Workout copyWith({
    DateTime? startedAt,
    int? durationMin,
    WorkoutType? type,
    WorkoutIntensity? intensity,
    int? calories,
    String? healthUuid,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id,
      userId: userId,
      startedAt: startedAt ?? this.startedAt,
      durationMin: durationMin ?? this.durationMin,
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      calories: calories ?? this.calories,
      healthUuid: healthUuid ?? this.healthUuid,
      source: source,
      sourceName: sourceName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        startedAt,
        durationMin,
        type,
        intensity,
        calories,
        healthUuid,
        source,
        sourceName,
        createdAt,
        updatedAt,
      ];
}
