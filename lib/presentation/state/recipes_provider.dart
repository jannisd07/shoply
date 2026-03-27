import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';

/// Provider for all recipes - can be invalidated to force refresh
final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return RecipeService().getRecipes();
});

/// Provider for popular recipes
final popularRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return RecipeService().getPopularRecipes(limit: 8);
});

/// Provider for recent recipes
final recentRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return RecipeService().getRecentRecipes(limit: 10);
});

/// Provider to trigger recipe data refresh across screens
/// Increment this to force all recipe providers to refresh
final recipeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Helper to refresh all recipe data
void refreshRecipeData(WidgetRef ref) {
  ref.read(recipeRefreshTriggerProvider.notifier).state++;
  ref.invalidate(recipesProvider);
  ref.invalidate(popularRecipesProvider);
  ref.invalidate(recentRecipesProvider);
}
