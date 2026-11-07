import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_service.dart';

/// Provider to trigger recipe data refresh across screens.
/// Increment this to force all recipe screens to refresh.
final recipeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Helper to refresh all recipe data
void refreshRecipeData(WidgetRef ref) {
  ref.read(recipeRefreshTriggerProvider.notifier).state++;
}

/// Provider for all recipes - can be invalidated to force refresh.
/// On a network error we fall back to the offline cache so the recipes tab
/// still renders when the device has no internet connection.
final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  try {
    final recipes = await RecipeService().getRecipes();
    // Cache in the background – don't block the UI on disk writes.
    // ignore: unawaited_futures
    OfflineCacheService.instance.cacheRecipes(recipes);
    return recipes;
  } catch (e) {
    final cached = await OfflineCacheService.instance.getCachedRecipes();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});
