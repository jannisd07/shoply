import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for all recipes
final allRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return RecipeService().getRecipes();
});

/// Provider for popular recipes
final popularRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  return RecipeService().getPopularRecipes(limit: 50);
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
    final recipesAsync = popularOnly
        ? ref.watch(popularRecipesProvider)
        : ref.watch(allRecipesProvider);
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          popularOnly ? context.tr('popular_recipes') : context.tr('all_recipes'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${context.tr('error_loading_recipes')}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (popularOnly) {
                    ref.invalidate(popularRecipesProvider);
                  } else {
                    ref.invalidate(allRecipesProvider);
                  }
                },
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
        data: (recipes) => recipes.isEmpty
            ? _buildEmptyState(context)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      if (popularOnly) {
                        ref.invalidate(popularRecipesProvider);
                      } else {
                        ref.invalidate(allRecipesProvider);
                      }
                    },
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100 + MediaQuery.of(context).padding.bottom,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recipe = recipes[index];
                          return _RecipeGridCard(
                            recipe: recipe,
                            onTap: () => context.push('/recipes/${recipe.id}'),
                          );
                        },
                        childCount: recipes.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 80,
              color: textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_recipes_found'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeGridCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeGridCard({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with bookmark
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: recipe.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 120,
                    color: AppColors.recipeInput(context),
                    child: const Center(child: Icon(Icons.restaurant_rounded)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.recipeInput(context),
                    child: const Center(child: Icon(Icons.restaurant_rounded)),
                  ),
                ),
                // Bookmark button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(savedRecipesProvider.notifier).toggleSave(recipe.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSaved ? Colors.white : Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 16,
                        color: isSaved ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                        if (recipe.averageRating > 0) ...[
                          const Spacer(),
                          Icon(Icons.star_rounded, size: 12, color: AppColors.recipeStarColor(context)),
                          const SizedBox(width: 2),
                          Text(
                            recipe.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
