import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';

/// Service für Zutatenaustausch basierend auf Allergien und Ernährungspräferenzen
class IngredientSubstitutionService {
  /// Gibt detaillierte Zutatenliste mit Substitutionen zurück
  static List<IngredientWithSubstitution> getIngredientsWithSubstitutions({
    required List<Ingredient> ingredients,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) {
    final result = <IngredientWithSubstitution>[];

    for (final ingredient in ingredients) {
      // Check for allergens
      final hasAllergen = allergies.any((allergy) => 
        allergy.containsAllergen(ingredient.name)
      );
      
      // Check if animal product (for vegan)
      final isAnimalProduct = _isAnimalProduct(ingredient.name);
      
      // Check if meat (for vegetarian)
      final isMeat = _isMeat(ingredient.name);
      
      // Determine if substitution is needed based on user preferences
      final needsVeganSubstitute = diets.contains(DietType.vegan) && isAnimalProduct;
      final needsVegetarianSubstitute = diets.contains(DietType.vegetarian) && isMeat;
      final needsSubstitution = hasAllergen || needsVeganSubstitute || needsVegetarianSubstitute;

      // Always collect diet flags for display, even if user doesn't have those preferences
      final dietFlags = <String>[];
      
      if (!isAnimalProduct && !isMeat) {
        dietFlags.add('🌱 Vegan');
        dietFlags.add('🥗 Vegetarian');
      } else if (!isMeat) {
        dietFlags.add('🥗 Vegetarian');
      }
      
      // Add allergy/diet reasons if substitution is needed
      final reasons = needsSubstitution ? _getReasons(ingredient.name, allergies, diets) : dietFlags;

      if (needsSubstitution) {
        final substitutes = SubstitutionDatabase.findSubstitutes(
          ingredient: ingredient.name,
          allergies: allergies,
          diets: diets,
        );

        result.add(IngredientWithSubstitution(
          original: ingredient,
          substitutes: substitutes,
          needsSubstitution: true,
          reasons: reasons,
        ));
      } else {
        result.add(IngredientWithSubstitution(
          original: ingredient,
          substitutes: [],
          needsSubstitution: false,
          reasons: dietFlags, // Show diet compatibility even when no substitution needed
        ));
      }
    }

    debugPrint('✅ [SUBSTITUTION] Analyzed ${result.length} ingredients '
        '(${result.where((r) => r.needsSubstitution).length} need substitution)');
    return result;
  }

  /// Prüft ob ein Rezept für Präferenzen geeignet ist
  static RecipeCompatibility checkRecipeCompatibility({
    required Recipe recipe,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) {
    if (allergies.isEmpty && diets.isEmpty) {
      return RecipeCompatibility(
        isCompatible: true,
        needsModifications: false,
        incompatibleIngredients: [],
        possibleSubstitutions: 0,
      );
    }

    final incompatible = <String>[];
    int substitutionCount = 0;

    for (final ingredient in recipe.ingredients) {
      final hasAllergen = allergies.any((allergy) => 
        allergy.containsAllergen(ingredient.name)
      );
      
      final needsSubstitute = diets.contains(DietType.vegan) && 
        _isAnimalProduct(ingredient.name) ||
        diets.contains(DietType.vegetarian) && _isMeat(ingredient.name);

      if (hasAllergen || needsSubstitute) {
        final substitutes = SubstitutionDatabase.findSubstitutes(
          ingredient: ingredient.name,
          allergies: allergies,
          diets: diets,
        );

        if (substitutes.isNotEmpty) {
          substitutionCount++;
        } else {
          incompatible.add(ingredient.name);
        }
      }
    }

    return RecipeCompatibility(
      isCompatible: incompatible.isEmpty,
      needsModifications: substitutionCount > 0,
      incompatibleIngredients: incompatible,
      possibleSubstitutions: substitutionCount,
    );
  }

  // Helper Methoden
  static bool _isAnimalProduct(String ingredient) {
    final animal = [
      // Dairy (German)
      'milch', 'sahne', 'butter', 'käse', 'joghurt', 'quark', 'crème',
      // Dairy (English)
      'milk', 'cream', 'cheese', 'yogurt', 'yoghurt', 'dairy',
      // Eggs (German)
      'ei', 'eier', 'eigelb', 'eiweiß',
      // Eggs (English)
      'egg', 'eggs', 'yolk',
      // Meat (German)
      'hähnchen', 'huhn', 'rind', 'schwein', 'lamm', 'fleisch', 'hack',
      'speck', 'pancetta', 'schinken', 'salami', 'wurst',
      // Meat (English)
      'chicken', 'beef', 'pork', 'lamb', 'meat', 'bacon', 'ham', 'sausage',
      'turkey', 'duck', 'steak', 'mince', 'ground beef', 'ground pork',
      // Seafood (German)
      'fisch', 'lachs', 'thunfisch', 'garnelen', 'muscheln',
      // Seafood (English)
      'fish', 'salmon', 'tuna', 'shrimp', 'prawns', 'shellfish', 'seafood',
      'cod', 'trout', 'crab', 'lobster',
      // Other animal products
      'honig', 'gelatine', 'honey', 'gelatin', 'lard', 'schmalz',
    ];
    final lower = ingredient.toLowerCase();
    return animal.any((a) => lower.contains(a));
  }

  static bool _isMeat(String ingredient) {
    final meat = [
      // Meat (German)
      'hähnchen', 'huhn', 'rind', 'schwein', 'lamm', 'fleisch', 'hack',
      'speck', 'pancetta', 'schinken', 'salami', 'wurst',
      // Meat (English)
      'chicken', 'beef', 'pork', 'lamb', 'meat', 'bacon', 'ham', 'sausage',
      'turkey', 'duck', 'steak', 'mince', 'ground beef', 'ground pork',
      'veal', 'venison', 'boar', 'goat',
      // Seafood (German)
      'fisch', 'lachs', 'thunfisch', 'garnelen', 'muscheln',
      // Seafood (English)
      'fish', 'salmon', 'tuna', 'shrimp', 'prawns', 'shellfish', 'seafood',
      'cod', 'trout', 'crab', 'lobster', 'anchovy', 'sardine',
    ];
    final lower = ingredient.toLowerCase();
    return meat.any((m) => lower.contains(m));
  }

  static List<String> _getReasons(
    String ingredient,
    List<AllergyType> allergies,
    List<DietType> diets,
  ) {
    final reasons = <String>[];

    for (final allergy in allergies) {
      if (allergy.containsAllergen(ingredient)) {
        reasons.add('${allergy.emoji} ${allergy.label}');
      }
    }

    if (diets.contains(DietType.vegan) && _isAnimalProduct(ingredient)) {
      reasons.add('🌱 Vegan');
    } else if (diets.contains(DietType.vegetarian) && _isMeat(ingredient)) {
      reasons.add('🥗 Vegetarisch');
    }

    return reasons;
  }
}

/// Zutat mit möglichen Ersatzprodukten
class IngredientWithSubstitution {
  final Ingredient original;
  final List<IngredientSubstitution> substitutes;
  final bool needsSubstitution;
  final List<String> reasons;

  IngredientWithSubstitution({
    required this.original,
    required this.substitutes,
    required this.needsSubstitution,
    required this.reasons,
  });

  /// Gibt die beste Substitution zurück
  IngredientSubstitution? get bestSubstitute => 
    substitutes.isNotEmpty ? substitutes.first : null;

  /// Gibt die angepasste Zutat zurück (mit Substitution falls vorhanden)
  Ingredient get adaptedIngredient {
    if (bestSubstitute != null) {
      return Ingredient(
        name: bestSubstitute!.substitute,
        amount: original.amount,
        unit: original.unit,
      );
    }
    return original;
  }
}

/// Kompatibilität eines Rezepts mit Ernährungspräferenzen
class RecipeCompatibility {
  final bool isCompatible;
  final bool needsModifications;
  final List<String> incompatibleIngredients;
  final int possibleSubstitutions;

  RecipeCompatibility({
    required this.isCompatible,
    required this.needsModifications,
    required this.incompatibleIngredients,
    required this.possibleSubstitutions,
  });

  /// Badge-Text für UI
  String get badgeText {
    if (isCompatible && !needsModifications) {
      return 'Passend';
    } else if (isCompatible && needsModifications) {
      return '$possibleSubstitutions Anpassungen';
    } else {
      return 'Nicht geeignet';
    }
  }
}
