import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for recipes by category - auto-refreshes when recipeRefreshTriggerProvider changes
final categoryRecipesProvider = FutureProvider.family<List<Recipe>, String>((ref, category) async {
  // Watch the refresh trigger to auto-reload when data changes
  ref.watch(recipeRefreshTriggerProvider);
  return RecipeService().getRecipesByCategory(category);
});

/// Category localization keys
const Map<String, String> categoryLocalizationKeys = {
  'italienisch': 'category_italian',
  'asiatisch': 'category_asian',
  'vegetarisch': 'category_vegetarian',
  'vegan': 'category_vegan',
  'dessert': 'category_desserts',
  'frühstück': 'category_breakfast',
  'schnell': 'category_quick',
  'gesund': 'category_healthy',
  'comfort-food': 'category_comfort',
  'mexican': 'category_mexican',
  'mediterranean': 'category_mediterranean',
  'seafood': 'category_seafood',
  'soup': 'category_soup',
};

/// Format category ID to display name (fallback for missing translations)
String _formatCategoryName(String categoryId) {
  // Replace underscores and hyphens with spaces
  String formatted = categoryId.replaceAll('_', ' ').replaceAll('-', ' ');
  // Capitalize first letter of each word
  return formatted.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}

/// Screen displaying recipes for a specific category
class CategoryRecipesScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryRecipesScreen({
    super.key,
    required this.categoryId,
  });

  String _getDisplayName(BuildContext context) {
    final key = categoryLocalizationKeys[categoryId];
    if (key != null) {
      final translated = context.tr(key);
      // If translation returns the key itself, use formatted name
      if (translated != key) {
        return translated;
      }
    }
    // Use formatted fallback for missing translations or unknown categories
    return _formatCategoryName(categoryId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(categoryRecipesProvider(categoryId));
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getDisplayName(context),
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
                onPressed: () => ref.invalidate(categoryRecipesProvider(categoryId)),
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
                      ref.invalidate(categoryRecipesProvider(categoryId));
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
                          return _CategoryRecipeCard(
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
              Icons.search_off_rounded,
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
            const SizedBox(height: 8),
            Text(
              context.tr('no_recipes_in_category'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _CategoryRecipeCard({
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
