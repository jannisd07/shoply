import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_service.dart';

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

/// Provider for popular recipes. Falls back to the cached recipe set
/// (sorted by rating) when offline.
final popularRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  try {
    return await RecipeService().getPopularRecipes(limit: 8);
  } catch (e) {
    final cached = await OfflineCacheService.instance.getCachedRecipes();
    if (cached.isEmpty) rethrow;
    final sorted = [...cached]
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return sorted.take(8).toList();
  }
});

/// Provider for recent recipes. Falls back to the cached recipe set
/// (sorted by creation date) when offline.
final recentRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  try {
    return await RecipeService().getRecentRecipes(limit: 10);
  } catch (e) {
    final cached = await OfflineCacheService.instance.getCachedRecipes();
    if (cached.isEmpty) rethrow;
    final sorted = [...cached]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(10).toList();
  }
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
