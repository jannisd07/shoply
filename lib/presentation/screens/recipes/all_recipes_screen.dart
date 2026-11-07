import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_grid_card.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_state_views.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';

/// Top 50 popular recipes for the "Popular" page. Watches the refresh
/// trigger so a new rating or recipe (refreshRecipeData) updates it, and is
/// dropped when the page closes.
final _popularRecipesPageProvider =
    FutureProvider.autoDispose<List<Recipe>>((ref) async {
  ref.watch(recipeRefreshTriggerProvider);
  return RecipeService.instance.getPopularRecipes(limit: 50);
});

/// Screen displaying all recipes or popular recipes
class AllRecipesScreen extends ConsumerWidget {
  final bool popularOnly;

  const AllRecipesScreen({
    super.key,
    this.popularOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "All" reuses the app-wide recipe list (with its offline fallback),
    // so it stays in sync with refreshRecipeData.
    final recipesAsync = popularOnly
        ? ref.watch(_popularRecipesPageProvider)
        : ref.watch(recipesProvider);

    Future<void> refresh() async {
      if (popularOnly) {
        ref.invalidate(_popularRecipesPageProvider);
      } else {
        ref.invalidate(recipesProvider);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.recipeBg(context),
      appBar: recipeListAppBar(
        context,
        title: Text(context.tr(popularOnly ? 'popular_recipes' : 'all_recipes')),
        onBack: () => context.pop(),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => RecipeErrorView(onRetry: refresh),
        data: (recipes) => recipes.isEmpty
            ? RecipeEmptyView(
                icon: Icons.restaurant_menu_rounded,
                title: context.tr('no_recipes_found'),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: refresh),
                  RecipeSliverGrid(
                    recipes: recipes,
                    onTap: (recipe) =>
                        context.push('/recipes/${recipe.id}', extra: recipe),
                  ),
                ],
              ),
      ),
    );
  }
}
