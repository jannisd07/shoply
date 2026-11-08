import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/food_log_entry.dart';

/// One part of a photographed meal as Avo saw it ("Spaghetti", 250 g,
/// 390 kcal). The meal's [MealPhotoEstimate.calories] is the sum of its
/// components, so the app can scale one and keep the total right.
class MealPhotoComponent {
  const MealPhotoComponent({
    required this.name,
    required this.grams,
    required this.kcal,
  });

  final String name;

  /// Estimated weight as served (cooked pasta, not dry).
  final int grams;
  final int kcal;
}

/// Avo's estimate of a meal photo (task `meal_photo`): always a rough guess,
/// shown as an editable preview and never saved without the person checking
/// it (portion weight and hidden fat cannot be seen on a photo).
class MealPhotoEstimate {
  const MealPhotoEstimate({
    required this.foodName,
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.confidence,
    this.components = const [],
    this.allergens = const [],
  });

  /// The dish ("Spaghetti Bolognese").
  final String foodName;
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// `high`, `medium` or `low`, the suffix of the `add_food_photo_confidence_*`
  /// texts. [confidenceWord] is the same level in the server's words.
  final String confidence;

  /// The main parts of the meal, at most 12.
  final List<MealPhotoComponent> components;

  /// Allergens the meal likely contains: a hint to check against the
  /// person's allergies, never a promise that it is free of others.
  final List<AllergyType> allergens;

  /// The level as the server says it: `recht_sicher`, `unsicher` or `grob`
  /// (shown as "Recht sicher", "Unsicher", "Grob geschätzt", never percent).
  String get confidenceWord => switch (confidence) {
        'high' => 'recht_sicher',
        'medium' => 'unsicher',
        _ => 'grob',
      };

  /// The level as a food log entry stores it.
  EstimateConfidence get confidenceLevel =>
      EstimateConfidenceX.fromDb(confidence) ?? EstimateConfidence.low;

  /// Reads the `result` of the task `meal_photo`. An unknown confidence is
  /// the roughest level; an empty dish name becomes [fallbackName]; broken
  /// components and unknown allergen ids are dropped. Throws
  /// [FormatException] when the total kcal is missing.
  factory MealPhotoEstimate.fromJson(
    Map<String, dynamic> json, {
    String fallbackName = 'Meal',
  }) {
    final kcal = json['kcal'];
    if (kcal is! num || !kcal.isFinite || kcal < 0) {
      throw const FormatException('meal_photo result without kcal');
    }
    final dish = json['dish'];
    final name = dish is String ? dish.trim() : '';
    return MealPhotoEstimate(
      foodName: name.isEmpty ? fallbackName : name,
      calories: kcal.round(),
      proteinG: _grams(json['protein_g']),
      carbsG: _grams(json['carbs_g']),
      fatG: _grams(json['fat_g']),
      confidence: switch (json['confidence']) {
        'recht_sicher' => 'high',
        'unsicher' => 'medium',
        _ => 'low',
      },
      components: _components(json['components']),
      allergens: _allergens(json['allergens']),
    );
  }

  static double? _grams(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

  static List<MealPhotoComponent> _components(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry case {'name': final String name, 'grams': final num grams, 'kcal': final num kcal}
            when name.trim().isNotEmpty &&
                grams.isFinite &&
                grams >= 0 &&
                kcal.isFinite &&
                kcal >= 0)
          MealPhotoComponent(name: name.trim(), grams: grams.round(), kcal: kcal.round()),
    ];
  }

  static List<AllergyType> _allergens(Object? value) {
    if (value is! List) return const [];
    final byId = AllergyType.values.asNameMap();
    return {
      for (final id in value)
        if (id is String && byId[id] != null) byId[id]!,
    }.toList();
  }
}
