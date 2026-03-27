import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for user's own recipes - auto-dispose to ensure fresh data
final myRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  print('🔄 [MY_RECIPES_PROVIDER] Fetching my recipes...');
  final recipes = await RecipeService().getMyRecipes();
  print('✅ [MY_RECIPES_PROVIDER] Got ${recipes.length} recipes');
  for (final r in recipes) {
    print('   - ${r.name} (author_id: ${r.authorId})');
  }
  return recipes;
});

/// Screen displaying recipes created by the current user
class MyRecipesScreen extends ConsumerWidget {
  const MyRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('my_recipes'),
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
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: textPrimary),
            onPressed: () => context.push('/recipes/add'),
          ),
        ],
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
                onPressed: () => ref.invalidate(myRecipesProvider),
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
                      ref.invalidate(myRecipesProvider);
                    },
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100 + MediaQuery.of(context).padding.bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recipe = recipes[index];
                          return _MyRecipeCard(
                            recipe: recipe,
                            onTap: () => context.push('/recipes/${recipe.id}'),
                            onEdit: () => context.push('/recipes/add', extra: {'recipeId': recipe.id}),
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
              context.tr('no_my_recipes'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('create_recipe_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/recipes/add'),
              icon: Icon(Icons.add_rounded, color: AppColors.textPrimary(context), size: 20),
              label: Text(
                context.tr('create_recipe'),
                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: textSecondary.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _MyRecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 100,
                  height: 100,
                  color: AppColors.recipeInput(context),
                  child: const Icon(Icons.restaurant_rounded),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 100,
                  height: 100,
                  color: AppColors.recipeInput(context),
                  child: const Icon(Icons.restaurant_rounded),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(recipe.createdAt),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        if (recipe.averageRating > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.star_rounded, size: 14, color: AppColors.recipeStarColor(context)),
                          const SizedBox(width: 3),
                          Text(
                            recipe.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' (${recipe.ratingCount})',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Edit button
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.recipeAccentColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: AppColors.recipeAccentColor(context),
                  size: 20,
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}
