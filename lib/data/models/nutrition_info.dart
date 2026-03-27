import 'package:equatable/equatable.dart';

/// Nutrition information for a recipe (per serving)
class NutritionInfo extends Equatable {
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sugarG;
  final int? sodiumMg;

  const NutritionInfo({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  bool get hasData => calories != null || proteinG != null || carbsG != null || fatG != null;

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: json['calories'] as int?,
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      fiberG: (json['fiber_g'] as num?)?.toDouble(),
      sugarG: (json['sugar_g'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
    };
  }

  /// Adjust nutrition for different servings
  NutritionInfo adjustForServings(int originalServings, int newServings) {
    final multiplier = newServings / originalServings;
    return NutritionInfo(
      calories: calories != null ? (calories! * multiplier).round() : null,
      proteinG: proteinG != null ? proteinG! * multiplier : null,
      carbsG: carbsG != null ? carbsG! * multiplier : null,
      fatG: fatG != null ? fatG! * multiplier : null,
      fiberG: fiberG != null ? fiberG! * multiplier : null,
      sugarG: sugarG != null ? sugarG! * multiplier : null,
      sodiumMg: sodiumMg != null ? (sodiumMg! * multiplier).round() : null,
    );
  }

  @override
  List<Object?> get props => [calories, proteinG, carbsG, fatG, fiberG, sugarG, sodiumMg];
}
