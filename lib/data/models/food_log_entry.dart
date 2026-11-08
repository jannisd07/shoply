import 'package:equatable/equatable.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get dbValue => switch (this) {
        MealType.breakfast => 'breakfast',
        MealType.lunch => 'lunch',
        MealType.dinner => 'dinner',
        MealType.snack => 'snack',
      };

  static MealType fromDb(String value) => switch (value) {
        'breakfast' => MealType.breakfast,
        'lunch' => MealType.lunch,
        'dinner' => MealType.dinner,
        _ => MealType.snack,
      };
}

/// Legacy four-way source. Kept for the old diary widgets until P2 replaces
/// them; new code reads [FoodLogEntry.origin].
enum FoodLogSource { manual, recipe, barcode, photo }

extension FoodLogSourceX on FoodLogSource {
  String get dbValue => switch (this) {
        FoodLogSource.manual => 'manual',
        FoodLogSource.recipe => 'recipe',
        FoodLogSource.barcode => 'barcode',
        FoodLogSource.photo => 'photo',
      };

  static FoodLogSource fromDb(String value) => switch (value) {
        'recipe' => FoodLogSource.recipe,
        'barcode' => FoodLogSource.barcode,
        'photo' => FoodLogSource.photo,
        _ => FoodLogSource.manual,
      };

  FoodEntryOrigin get origin => switch (this) {
        FoodLogSource.manual => FoodEntryOrigin.manual,
        FoodLogSource.recipe => FoodEntryOrigin.recipe,
        FoodLogSource.barcode => FoodEntryOrigin.barcode,
        FoodLogSource.photo => FoodEntryOrigin.photo,
      };
}

/// Where an entry's numbers came from (`food_log_entries.source`).
/// `search` = Open Food Facts or own food found by name; `manualEstimated`
/// = typed name with an AI estimate ("Kalorien schätzen lassen").
enum FoodEntryOrigin { manual, recipe, barcode, photo, search, manualEstimated }

extension FoodEntryOriginX on FoodEntryOrigin {
  String get dbValue => switch (this) {
        FoodEntryOrigin.manualEstimated => 'manual_estimated',
        _ => name,
      };

  static FoodEntryOrigin fromDb(String? value) => switch (value) {
        'recipe' => FoodEntryOrigin.recipe,
        'barcode' => FoodEntryOrigin.barcode,
        'photo' => FoodEntryOrigin.photo,
        'search' => FoodEntryOrigin.search,
        'manual_estimated' => FoodEntryOrigin.manualEstimated,
        _ => FoodEntryOrigin.manual,
      };

  /// Closest value the old check constraint accepts.
  FoodLogSource get legacySource => switch (this) {
        FoodEntryOrigin.recipe => FoodLogSource.recipe,
        FoodEntryOrigin.barcode || FoodEntryOrigin.search => FoodLogSource.barcode,
        FoodEntryOrigin.photo => FoodLogSource.photo,
        FoodEntryOrigin.manual || FoodEntryOrigin.manualEstimated => FoodLogSource.manual,
      };
}

/// Confidence of an AI estimate in three word levels, never percent
/// (concept 15 2.3): high "Recht sicher", medium "Unsicher", low "Grob
/// geschätzt".
enum EstimateConfidence { high, medium, low }

extension EstimateConfidenceX on EstimateConfidence {
  String get dbValue => name;

  static EstimateConfidence? fromDb(String? value) => switch (value) {
        'high' => EstimateConfidence.high,
        'medium' => EstimateConfidence.medium,
        'low' => EstimateConfidence.low,
        _ => null,
      };
}

/// Local wall-clock time of a meal (`food_log_entries.logged_time`).
class FoodLogTime extends Equatable {
  final int hour;
  final int minute;

  const FoodLogTime(this.hour, this.minute);

  factory FoodLogTime.of(DateTime time) {
    final local = time.isUtc ? time.toLocal() : time;
    return FoodLogTime(local.hour, local.minute);
  }

  static FoodLogTime? tryParse(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})(:\d{2}(\.\d+)?)?$').firstMatch(value);
    if (m == null) return null;
    final h = int.parse(m[1]!);
    final min = int.parse(m[2]!);
    if (h > 23 || min > 59) return null;
    return FoodLogTime(h, min);
  }

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [hour, minute];
}

/// A single logged food item for one meal on one day.
class FoodLogEntry extends Equatable {
  final String id;
  final String userId;
  final DateTime loggedDate;
  final MealType mealType;
  final FoodEntryOrigin origin;
  final String? sourceRecipeId;
  final String foodName;
  final String? brand;
  final double quantity;
  final String? unit;
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? barcode;
  final String? photoUrl;

  /// Storage path in the private `meal-photos` bucket (signed URLs).
  final String? photoPath;

  /// Numbers come from an AI estimate; the diary keeps saying "geschätzt".
  final bool estimated;
  final EstimateConfidence? confidence;
  final String? healthUuid;
  final FoodLogTime? loggedTime;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FoodLogEntry({
    required this.id,
    required this.userId,
    required this.loggedDate,
    required this.mealType,
    FoodLogSource source = FoodLogSource.manual,
    FoodEntryOrigin? origin,
    this.sourceRecipeId,
    required this.foodName,
    this.brand,
    this.quantity = 1,
    this.unit,
    this.calories = 0,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.barcode,
    this.photoUrl,
    this.photoPath,
    this.estimated = false,
    this.confidence,
    this.healthUuid,
    this.loggedTime,
    required this.createdAt,
    this.updatedAt,
  }) : origin = origin ??
            (source == FoodLogSource.recipe
                ? FoodEntryOrigin.recipe
                : source == FoodLogSource.barcode
                    ? FoodEntryOrigin.barcode
                    : source == FoodLogSource.photo
                        ? FoodEntryOrigin.photo
                        : FoodEntryOrigin.manual);

  FoodLogSource get source => origin.legacySource;

  String get dateKey =>
      '${loggedDate.year.toString().padLeft(4, '0')}-${loggedDate.month.toString().padLeft(2, '0')}-${loggedDate.day.toString().padLeft(2, '0')}';

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    final updated = json['updated_at'] as String?;
    return FoodLogEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      loggedDate: DateTime.parse(json['logged_date'] as String),
      mealType: MealTypeX.fromDb(json['meal_type'] as String? ?? 'snack'),
      origin: FoodEntryOriginX.fromDb(json['source'] as String?),
      sourceRecipeId: json['source_recipe_id'] as String?,
      foodName: json['food_name'] as String,
      brand: json['brand'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String?,
      calories: (json['calories'] as num?)?.round() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      barcode: json['barcode'] as String?,
      photoUrl: json['photo_url'] as String?,
      photoPath: json['photo_path'] as String?,
      estimated: json['estimated'] as bool? ?? false,
      confidence: EstimateConfidenceX.fromDb(json['confidence'] as String?),
      healthUuid: json['health_uuid'] as String?,
      loggedTime: FoodLogTime.tryParse(json['logged_time'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: updated == null ? null : DateTime.parse(updated),
    );
  }

  /// Row for an idempotent upsert by [id]. Before the B6 migration
  /// ([schemaV2] false) only the columns and source values that exist today
  /// are sent, so logging keeps working until the owner applies it.
  Map<String, dynamic> toUpsertJson({required bool schemaV2}) {
    return {
      'id': id,
      'user_id': userId,
      'logged_date': dateKey,
      'meal_type': mealType.dbValue,
      'source': schemaV2 ? origin.dbValue : origin.legacySource.dbValue,
      'source_recipe_id': sourceRecipeId,
      'food_name': foodName,
      'brand': brand,
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'barcode': barcode,
      'photo_url': photoUrl,
      if (schemaV2) ...{
        'estimated': estimated,
        'confidence': confidence?.dbValue,
        'health_uuid': healthUuid,
        'logged_time': loggedTime?.toString(),
        'photo_path': photoPath,
      },
    };
  }

  /// Full local snapshot for the day store.
  Map<String, dynamic> toJson() => {
        ...toUpsertJson(schemaV2: true),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  FoodLogEntry copyWith({
    DateTime? loggedDate,
    MealType? mealType,
    String? foodName,
    String? brand,
    double? quantity,
    String? unit,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? photoPath,
    bool? estimated,
    EstimateConfidence? confidence,
    String? healthUuid,
    FoodLogTime? loggedTime,
    DateTime? updatedAt,
  }) {
    return FoodLogEntry(
      id: id,
      userId: userId,
      loggedDate: loggedDate ?? this.loggedDate,
      mealType: mealType ?? this.mealType,
      origin: origin,
      sourceRecipeId: sourceRecipeId,
      foodName: foodName ?? this.foodName,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      barcode: barcode,
      photoUrl: photoUrl,
      photoPath: photoPath ?? this.photoPath,
      estimated: estimated ?? this.estimated,
      confidence: confidence ?? this.confidence,
      healthUuid: healthUuid ?? this.healthUuid,
      loggedTime: loggedTime ?? this.loggedTime,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        loggedDate,
        mealType,
        origin,
        sourceRecipeId,
        foodName,
        brand,
        quantity,
        unit,
        calories,
        proteinG,
        carbsG,
        fatG,
        barcode,
        photoUrl,
        photoPath,
        estimated,
        confidence,
        healthUuid,
        loggedTime,
        createdAt,
        updatedAt,
      ];
}

/// Totals for one day's logged food, and the remaining budget against a
/// [NutritionGoal] (null fields when the goal isn't configured yet).
class DailyNutritionTotals extends Equatable {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const DailyNutritionTotals({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  factory DailyNutritionTotals.fromEntries(List<FoodLogEntry> entries) {
    int calories = 0;
    double protein = 0, carbs = 0, fat = 0;
    for (final e in entries) {
      calories += e.calories;
      protein += e.proteinG ?? 0;
      carbs += e.carbsG ?? 0;
      fat += e.fatG ?? 0;
    }
    return DailyNutritionTotals(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
  }

  @override
  List<Object?> get props => [calories, proteinG, carbsG, fatG];
}
