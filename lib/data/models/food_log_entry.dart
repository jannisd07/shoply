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

/// Where a logged food entry's nutrition data came from.
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
}

/// A single logged food item for one meal on one day.
class FoodLogEntry extends Equatable {
  final String id;
  final String userId;
  final DateTime loggedDate;
  final MealType mealType;
  final FoodLogSource source;
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
  final DateTime createdAt;

  const FoodLogEntry({
    required this.id,
    required this.userId,
    required this.loggedDate,
    required this.mealType,
    this.source = FoodLogSource.manual,
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
    required this.createdAt,
  });

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      loggedDate: DateTime.parse(json['logged_date'] as String),
      mealType: MealTypeX.fromDb(json['meal_type'] as String? ?? 'snack'),
      source: FoodLogSourceX.fromDb(json['source'] as String? ?? 'manual'),
      sourceRecipeId: json['source_recipe_id'] as String?,
      foodName: json['food_name'] as String,
      brand: json['brand'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String?,
      calories: json['calories'] as int? ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      barcode: json['barcode'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'logged_date':
          '${loggedDate.year.toString().padLeft(4, '0')}-${loggedDate.month.toString().padLeft(2, '0')}-${loggedDate.day.toString().padLeft(2, '0')}',
      'meal_type': mealType.dbValue,
      'source': source.dbValue,
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
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        loggedDate,
        mealType,
        source,
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
        createdAt,
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
