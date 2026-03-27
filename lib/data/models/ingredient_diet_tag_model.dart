import 'package:equatable/equatable.dart';

/// Ingredient diet and allergen information (Prompt 5)
/// Stored in Supabase ingredient_diet_tags table
class IngredientDietTagModel extends Equatable {
  final String id;
  final String ingredientName;
  
  // Diet Compatibility Flags
  final bool isVegan;
  final bool isVegetarian;
  final bool isGlutenFree;
  final bool isDairyFree;
  final bool isNutFree;
  final bool isSoyFree;
  final bool isEggFree;
  
  // Allergen Info
  final bool containsShellfish;
  final bool containsFish;
  
  // Metadata
  final bool verified; // True if manually verified, false if AI-generated
  final DateTime createdAt;
  final DateTime updatedAt;

  const IngredientDietTagModel({
    required this.id,
    required this.ingredientName,
    this.isVegan = true,
    this.isVegetarian = true,
    this.isGlutenFree = true,
    this.isDairyFree = true,
    this.isNutFree = true,
    this.isSoyFree = true,
    this.isEggFree = true,
    this.containsShellfish = false,
    this.containsFish = false,
    this.verified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IngredientDietTagModel.fromJson(Map<String, dynamic> json) {
    return IngredientDietTagModel(
      id: json['id'] as String,
      ingredientName: json['ingredient_name'] as String,
      isVegan: json['is_vegan'] as bool? ?? true,
      isVegetarian: json['is_vegetarian'] as bool? ?? true,
      isGlutenFree: json['is_gluten_free'] as bool? ?? true,
      isDairyFree: json['is_dairy_free'] as bool? ?? true,
      isNutFree: json['is_nut_free'] as bool? ?? true,
      isSoyFree: json['is_soy_free'] as bool? ?? true,
      isEggFree: json['is_egg_free'] as bool? ?? true,
      containsShellfish: json['contains_shellfish'] as bool? ?? false,
      containsFish: json['contains_fish'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ingredient_name': ingredientName,
      'is_vegan': isVegan,
      'is_vegetarian': isVegetarian,
      'is_gluten_free': isGlutenFree,
      'is_dairy_free': isDairyFree,
      'is_nut_free': isNutFree,
      'is_soy_free': isSoyFree,
      'is_egg_free': isEggFree,
      'contains_shellfish': containsShellfish,
      'contains_fish': containsFish,
      'verified': verified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  IngredientDietTagModel copyWith({
    String? id,
    String? ingredientName,
    bool? isVegan,
    bool? isVegetarian,
    bool? isGlutenFree,
    bool? isDairyFree,
    bool? isNutFree,
    bool? isSoyFree,
    bool? isEggFree,
    bool? containsShellfish,
    bool? containsFish,
    bool? verified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IngredientDietTagModel(
      id: id ?? this.id,
      ingredientName: ingredientName ?? this.ingredientName,
      isVegan: isVegan ?? this.isVegan,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
      isDairyFree: isDairyFree ?? this.isDairyFree,
      isNutFree: isNutFree ?? this.isNutFree,
      isSoyFree: isSoyFree ?? this.isSoyFree,
      isEggFree: isEggFree ?? this.isEggFree,
      containsShellfish: containsShellfish ?? this.containsShellfish,
      containsFish: containsFish ?? this.containsFish,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ingredientName,
        isVegan,
        isVegetarian,
        isGlutenFree,
        isDairyFree,
        isNutFree,
        isSoyFree,
        isEggFree,
        containsShellfish,
        containsFish,
        verified,
        createdAt,
        updatedAt,
      ];

  /// Check if ingredient is compatible with a specific diet preference
  bool isCompatibleWith(String dietPreference) {
    switch (dietPreference.toLowerCase()) {
      case 'vegan':
        return isVegan;
      case 'vegetarian':
        return isVegetarian;
      case 'gluten_free':
      case 'gluten-free':
        return isGlutenFree;
      case 'dairy_free':
      case 'dairy-free':
        return isDairyFree;
      case 'nut_free':
      case 'nut-free':
        return isNutFree;
      case 'soy_free':
      case 'soy-free':
        return isSoyFree;
      case 'egg_free':
      case 'egg-free':
        return isEggFree;
      case 'shellfish_free':
      case 'shellfish-free':
        return !containsShellfish;
      case 'fish_free':
      case 'fish-free':
        return !containsFish;
      default:
        return true; // Unknown diet = assume compatible
    }
  }

  /// Get list of violated diet preferences
  List<String> getViolatedDiets(List<String> dietPreferences) {
    return dietPreferences
        .where((diet) => !isCompatibleWith(diet))
        .toList();
  }

  /// Human-readable summary of diet flags
  String getDietSummary() {
    final flags = <String>[];
    if (isVegan) flags.add('Vegan');
    if (isVegetarian && !isVegan) flags.add('Vegetarian');
    if (isGlutenFree) flags.add('Gluten-Free');
    if (isDairyFree) flags.add('Dairy-Free');
    if (isNutFree) flags.add('Nut-Free');
    
    if (flags.isEmpty) return 'Contains animal products';
    return flags.join(', ');
  }

  /// Create tag from AI analysis result
  factory IngredientDietTagModel.fromAI({
    required String ingredientName,
    required Map<String, bool> dietFlags,
  }) {
    final now = DateTime.now();
    return IngredientDietTagModel(
      id: '', // Will be generated by Supabase
      ingredientName: ingredientName,
      isVegan: dietFlags['is_vegan'] ?? true,
      isVegetarian: dietFlags['is_vegetarian'] ?? true,
      isGlutenFree: dietFlags['is_gluten_free'] ?? true,
      isDairyFree: dietFlags['is_dairy_free'] ?? true,
      isNutFree: dietFlags['is_nut_free'] ?? true,
      isSoyFree: dietFlags['is_soy_free'] ?? true,
      isEggFree: dietFlags['is_egg_free'] ?? true,
      containsShellfish: dietFlags['contains_shellfish'] ?? false,
      containsFish: dietFlags['contains_fish'] ?? false,
      verified: false, // AI-generated, not manually verified
      createdAt: now,
      updatedAt: now,
    );
  }
}
