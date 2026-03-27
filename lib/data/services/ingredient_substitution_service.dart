import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/ai_ingredient_analyzer.dart';

/// Service für intelligenten Zutatenaustausch basierend auf Allergien und Ernährungspräferenzen
/// Kombiniert lokale Datenbank mit KI für maximale Abdeckung
class IngredientSubstitutionService {
  static final AIIngredientAnalyzer _aiAnalyzer = AIIngredientAnalyzer();
  static bool useAI = true; // Toggle für KI-Nutzung
  
  /// Passt ein Rezept an die Ernährungspräferenzen an (mit KI-Support)
  /// Nutzt zuerst lokale Datenbank, dann KI als Fallback
  static Future<Recipe> adaptRecipeWithAI({
    required Recipe recipe,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) async {
    if (allergies.isEmpty && diets.isEmpty) {
      return recipe;
    }

    final adaptedIngredients = <Ingredient>[];
    final warnings = <String>[];

    for (final ingredient in recipe.ingredients) {
      // Prüfe ob Zutat problematisch ist
      final hasAllergen = allergies.any((allergy) => 
        allergy.containsAllergen(ingredient.name)
      );
      
      final needsVeganSubstitute = diets.contains(DietType.vegan) && 
        _isAnimalProduct(ingredient.name);
      
      final needsVegetarianSubstitute = diets.contains(DietType.vegetarian) && 
        _isMeat(ingredient.name);

      if (hasAllergen || needsVeganSubstitute || needsVegetarianSubstitute) {
        // 1. Versuch: Lokale Datenbank
        final localSubstitutes = SubstitutionDatabase.findSubstitutes(
          ingredient: ingredient.name,
          allergies: allergies,
          diets: diets,
        );

        if (localSubstitutes.isNotEmpty) {
          final bestSubstitute = localSubstitutes.first;
          adaptedIngredients.add(
            Ingredient(
              name: bestSubstitute.substitute,
              amount: ingredient.amount,
              unit: ingredient.unit,
            ),
          );
        } else if (useAI) {
          // 2. Versuch: KI-Analyse
          try {
            final aiResult = await _aiAnalyzer.analyzeIngredient(
              ingredientName: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              allergies: allergies,
              diets: diets,
            );

            if (aiResult.needsReplacement && aiResult.bestSubstitute != null) {
              final aiSub = aiResult.bestSubstitute!;
              adaptedIngredients.add(aiSub.toIngredient());
            } else {
              warnings.add('⚠️ Kein Ersatz für "${ingredient.name}" gefunden');
              adaptedIngredients.add(ingredient);
            }
          } catch (e) {
            warnings.add('⚠️ Kein Ersatz für "${ingredient.name}" gefunden');
            adaptedIngredients.add(ingredient);
          }
        } else {
          // Keine KI, keine lokale DB → Original behalten
          warnings.add('⚠️ Kein Ersatz für "${ingredient.name}" gefunden');
          adaptedIngredients.add(ingredient);
        }
      } else {
        // Zutat ist OK
        adaptedIngredients.add(ingredient);
      }
    }

    return Recipe(
      id: recipe.id,
      name: recipe.name,
      description: _addWarningsToDescription(recipe.description, warnings),
      imageUrl: recipe.imageUrl,
      prepTimeMinutes: recipe.prepTimeMinutes,
      cookTimeMinutes: recipe.cookTimeMinutes,
      defaultServings: recipe.defaultServings,
      ingredients: adaptedIngredients,
      instructions: recipe.instructions,
      authorId: recipe.authorId,
      authorName: recipe.authorName,
      createdAt: recipe.createdAt,
      ratingCount: recipe.ratingCount,
      averageRating: recipe.averageRating,
      labels: recipe.labels,
    );
  }
  
  /// Passt ein Rezept an die Ernährungspräferenzen an
  static Recipe adaptRecipe({
    required Recipe recipe,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) {
    if (allergies.isEmpty && diets.isEmpty) {
      return recipe;
    }

    final adaptedIngredients = <Ingredient>[];
    final warnings = <String>[];

    for (final ingredient in recipe.ingredients) {
      // Prüfe ob Zutat problematisch ist
      final hasAllergen = allergies.any((allergy) => 
        allergy.containsAllergen(ingredient.name)
      );
      
      final needsVeganSubstitute = diets.contains(DietType.vegan) && 
        _isAnimalProduct(ingredient.name);
      
      final needsVegetarianSubstitute = diets.contains(DietType.vegetarian) && 
        _isMeat(ingredient.name);

      if (hasAllergen || needsVeganSubstitute || needsVegetarianSubstitute) {
        // Finde Ersatzprodukt
        final substitutes = SubstitutionDatabase.findSubstitutes(
          ingredient: ingredient.name,
          allergies: allergies,
          diets: diets,
        );

        if (substitutes.isNotEmpty) {
          final bestSubstitute = substitutes.first;
          adaptedIngredients.add(
            Ingredient(
              name: bestSubstitute.substitute,
              amount: ingredient.amount,
              unit: ingredient.unit,
            ),
          );
        } else {
          // Keine Ersatz gefunden - Warnung hinzufügen
          warnings.add('⚠️ Kein Ersatz für "${ingredient.name}" gefunden');
          adaptedIngredients.add(ingredient); // Original behalten
        }
      } else {
        // Zutat ist OK
        adaptedIngredients.add(ingredient);
      }
    }

    return Recipe(
      id: recipe.id,
      name: recipe.name,
      description: _addWarningsToDescription(recipe.description, warnings),
      imageUrl: recipe.imageUrl,
      prepTimeMinutes: recipe.prepTimeMinutes,
      cookTimeMinutes: recipe.cookTimeMinutes,
      defaultServings: recipe.defaultServings,
      ingredients: adaptedIngredients,
      instructions: recipe.instructions,
      authorId: recipe.authorId,
      authorName: recipe.authorName,
      createdAt: recipe.createdAt,
      ratingCount: recipe.ratingCount,
      averageRating: recipe.averageRating,
      labels: recipe.labels,
    );
  }

  /// Gibt detaillierte Zutatenliste mit Substitutionen zurück
  static List<IngredientWithSubstitution> getIngredientsWithSubstitutions({
    required List<Ingredient> ingredients,
    List<AllergyType> allergies = const [],
    List<DietType> diets = const [],
  }) {
    print('🔍 [SUBSTITUTION] Analyzing ${ingredients.length} ingredients');
    print('📋 [SUBSTITUTION] User allergies: $allergies');
    print('🥗 [SUBSTITUTION] User diets: $diets');
    
    final result = <IngredientWithSubstitution>[];

    for (final ingredient in ingredients) {
      print('🧪 [SUBSTITUTION] Analyzing: ${ingredient.name}');
      
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
      
      print('   - Animal product: $isAnimalProduct');
      print('   - Meat: $isMeat');
      print('   - Needs substitution: $needsSubstitution');
      print('   - Diet flags: $dietFlags');
      print('   - Reasons: $reasons');

      if (needsSubstitution) {
        final substitutes = SubstitutionDatabase.findSubstitutes(
          ingredient: ingredient.name,
          allergies: allergies,
          diets: diets,
        );
        
        print('   - Found ${substitutes.length} substitutes');

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

    print('✅ [SUBSTITUTION] Analysis complete: ${result.length} ingredients processed');
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

  static String _addWarningsToDescription(String description, List<String> warnings) {
    if (warnings.isEmpty) return description;
    return '$description\n\n${warnings.join('\n')}';
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
