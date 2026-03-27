import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_filter.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

class RecipeFilterState {
  final Set<String> activeQuickFilters;
  final AdvancedFilterOptions advancedFilters;

  const RecipeFilterState({
    this.activeQuickFilters = const {},
    this.advancedFilters = const AdvancedFilterOptions(),
  });

  RecipeFilterState copyWith({
    Set<String>? activeQuickFilters,
    AdvancedFilterOptions? advancedFilters,
  }) {
    return RecipeFilterState(
      activeQuickFilters: activeQuickFilters ?? this.activeQuickFilters,
      advancedFilters: advancedFilters ?? this.advancedFilters,
    );
  }

  int get activeFilterCount {
    return activeQuickFilters.length + 
        (advancedFilters.hasActiveFilters ? 1 : 0);
  }

  bool get hasActiveFilters {
    return activeQuickFilters.isNotEmpty || advancedFilters.hasActiveFilters;
  }
}

class RecipeFilterNotifier extends StateNotifier<RecipeFilterState> {
  final Ref ref;
  
  RecipeFilterNotifier(this.ref) : super(const RecipeFilterState());

  void toggleQuickFilter(String filterId) {
    final newFilters = Set<String>.from(state.activeQuickFilters);
    if (newFilters.contains(filterId)) {
      newFilters.remove(filterId);
    } else {
      newFilters.add(filterId);
    }
    state = state.copyWith(activeQuickFilters: newFilters);
  }

  void updateAdvancedFilters(AdvancedFilterOptions options) {
    state = state.copyWith(advancedFilters: options);
  }

  void clearAllFilters() {
    state = const RecipeFilterState();
  }

  List<Recipe> getFilteredRecipes(List<Recipe> recipes) {
    if (!state.hasActiveFilters) {
      return recipes;
    }

    return recipes.where((recipe) {
      // Must match ALL active filters
      for (final filterId in state.activeQuickFilters) {
        if (!_matchesQuickFilter(recipe, filterId)) {
          return false;
        }
      }

      // Must match advanced filters
      if (!_matchesAdvancedFilters(recipe)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _matchesQuickFilter(Recipe recipe, String filterId) {
    // Special handling for "My Diet" filter
    if (filterId == 'my-diet') {
      final user = ref.read(currentUserProvider).value;
      if (user == null || user.dietPreferences.isEmpty) {
        return true; // No diet preferences, show all recipes
      }
      
      // Check if recipe matches ALL user's diet preferences
      for (final dietPref in user.dietPreferences) {
        if (!_matchesQuickFilter(recipe, dietPref)) {
          return false; // Recipe doesn't match this diet preference
        }
      }
      return true; // Recipe matches all diet preferences
    }
    
    // Use ML-generated labels from the recipe for efficient filtering
    final labels = recipe.labels.map((l) => l.toLowerCase()).toList();
    
    // FIRST: Direct label match (case-insensitive)
    if (labels.contains(filterId.toLowerCase())) {
      return true;
    }
    
    // SECOND: Fallback to ingredient/property analysis for missing labels
    // This ensures filters work even if recipes don't have ML labels yet
    return _fallbackFilterMatch(recipe, filterId);
  }
  
  bool _fallbackFilterMatch(Recipe recipe, String filterId) {
    final totalTime = recipe.prepTimeMinutes + recipe.cookTimeMinutes;
    final ingredientNames = recipe.ingredients
        .map((i) => i.name.toLowerCase())
        .join(' ');
    
    switch (filterId.toLowerCase()) {
      // Time filters
      case 'quick':
        return totalTime <= 15;
      case '30min':
        return totalTime <= 30;
      case 'under-hour':
        return totalTime <= 60;
        
      // Diet filters
      case 'vegetarian':
      case 'vegetarisch':
        return !ingredientNames.contains('fleisch') &&
               !ingredientNames.contains('fisch') &&
               !ingredientNames.contains('hähnchen') &&
               !ingredientNames.contains('rind') &&
               !ingredientNames.contains('schwein');
               
      case 'vegan':
        return !ingredientNames.contains('fleisch') &&
               !ingredientNames.contains('fisch') &&
               !ingredientNames.contains('ei') &&
               !ingredientNames.contains('milch') &&
               !ingredientNames.contains('käse') &&
               !ingredientNames.contains('butter') &&
               !ingredientNames.contains('sahne') &&
               !ingredientNames.contains('joghurt');
               
      case 'gluten-free':
      case 'glutenfrei':
        return !ingredientNames.contains('mehl') &&
               !ingredientNames.contains('brot') &&
               !ingredientNames.contains('pasta') &&
               !ingredientNames.contains('nudeln');
               
      case 'low-carb':
        return !ingredientNames.contains('reis') &&
               !ingredientNames.contains('kartoffel') &&
               !ingredientNames.contains('nudeln') &&
               !ingredientNames.contains('brot');
               
      // Meal type filters (check recipe name)
      case 'breakfast':
      case 'frühstück':
        final name = recipe.name.toLowerCase();
        return name.contains('frühstück') ||
               name.contains('breakfast') ||
               ingredientNames.contains('müsli') ||
               ingredientNames.contains('haferflocken');
               
      case 'lunch':
      case 'mittagessen':
        return true; // Most recipes work for lunch
        
      case 'dinner':
      case 'abendessen':
        return true; // Most recipes work for dinner
        
      case 'snack':
        final name = recipe.name.toLowerCase();
        return name.contains('snack') ||
               name.contains('happen') ||
               totalTime <= 15;
               
      // Difficulty filters
      case 'easy':
      case 'einfach':
        return recipe.ingredients.length <= 6 && totalTime <= 30;
        
      case 'medium':
      case 'mittel':
        return recipe.ingredients.length <= 10 && totalTime <= 60;
        
      case 'advanced':
      case 'fortgeschritten':
        return recipe.ingredients.length > 10 || totalTime > 60;
        
      // Cuisine filters (check recipe name and ingredients)
      case 'italian':
      case 'italienisch':
        return ingredientNames.contains('pasta') ||
               ingredientNames.contains('tomate') ||
               ingredientNames.contains('basilikum') ||
               ingredientNames.contains('mozzarella');
               
      case 'asian':
      case 'asiatisch':
        return ingredientNames.contains('soja') ||
               ingredientNames.contains('reis') ||
               ingredientNames.contains('ingwer') ||
               ingredientNames.contains('sesam');
               
      case 'mexican':
      case 'mexikanisch':
        return ingredientNames.contains('bohnen') ||
               ingredientNames.contains('avocado') ||
               ingredientNames.contains('tortilla') ||
               ingredientNames.contains('chili');
               
      case 'mediterranean':
      case 'mediterran':
        return ingredientNames.contains('olive') ||
               ingredientNames.contains('feta') ||
               ingredientNames.contains('zitrone');
               
      // Top rated
      case 'top-rated':
        return recipe.ratingCount >= 10;
        
      default:
        return false;
    }
  }

  bool _matchesAdvancedFilters(Recipe recipe) {
    final options = state.advancedFilters;
    final totalTime = recipe.prepTimeMinutes + recipe.cookTimeMinutes;

    // Time range
    if (options.minTimeMinutes != null && totalTime < options.minTimeMinutes!) {
      return false;
    }
    if (options.maxTimeMinutes != null && totalTime > options.maxTimeMinutes!) {
      return false;
    }

    // Diet restrictions
    for (final diet in options.dietRestrictions) {
      if (!_matchesQuickFilter(recipe, diet)) {
        return false;
      }
    }

    // Meal types (OR logic - match any)
    if (options.mealTypes.isNotEmpty) {
      bool matchesAnyMealType = false;
      for (final mealType in options.mealTypes) {
        if (_matchesQuickFilter(recipe, mealType)) {
          matchesAnyMealType = true;
          break;
        }
      }
      if (!matchesAnyMealType) return false;
    }

    // Difficulty
    if (options.difficulty != null) {
      if (!_matchesQuickFilter(recipe, options.difficulty!)) {
        return false;
      }
    }

    // Cuisine types (OR logic - match any)
    if (options.cuisineTypes.isNotEmpty) {
      bool matchesAnyCuisine = false;
      for (final cuisine in options.cuisineTypes) {
        if (_matchesQuickFilter(recipe, cuisine)) {
          matchesAnyCuisine = true;
          break;
        }
      }
      if (!matchesAnyCuisine) return false;
    }

    // Servings range
    if (options.minServings != null && recipe.defaultServings < options.minServings!) {
      return false;
    }
    if (options.maxServings != null && recipe.defaultServings > options.maxServings!) {
      return false;
    }

    // Include ingredients
    if (options.includeIngredients.isNotEmpty) {
      final ingredients = recipe.ingredients.map((i) => i.name.toLowerCase()).toList();
      for (final required in options.includeIngredients) {
        if (!ingredients.any((i) => i.contains(required.toLowerCase()))) {
          return false;
        }
      }
    }

    // Exclude ingredients
    if (options.excludeIngredients.isNotEmpty) {
      final ingredients = recipe.ingredients.map((i) => i.name.toLowerCase()).toList();
      for (final excluded in options.excludeIngredients) {
        if (ingredients.any((i) => i.contains(excluded.toLowerCase()))) {
          return false;
        }
      }
    }

    // High protein
    if (options.highProtein) {
      final ingredients = recipe.ingredients.map((i) => i.name.toLowerCase()).toList();
      if (!ingredients.any((i) => 
        i.contains('hähnchen') || i.contains('fisch') || 
        i.contains('ei') || i.contains('tofu') || i.contains('quark'))) {
        return false;
      }
    }

    // Low calorie
    if (options.lowCalorie) {
      final ingredients = recipe.ingredients.map((i) => i.name.toLowerCase()).toList();
      if (!ingredients.any((i) => i.contains('gemüse') || i.contains('salat'))) {
        return false;
      }
    }

    // High fiber
    if (options.highFiber) {
      final ingredients = recipe.ingredients.map((i) => i.name.toLowerCase()).toList();
      if (!ingredients.any((i) => i.contains('vollkorn') || i.contains('haferflocken'))) {
        return false;
      }
    }

    return true;
  }
}

final recipeFilterProvider = StateNotifierProvider<RecipeFilterNotifier, RecipeFilterState>((ref) {
  return RecipeFilterNotifier(ref);
});
