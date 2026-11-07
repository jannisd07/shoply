import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_state_views.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for user's own recipes - auto-dispose to ensure fresh data.
/// Also reloads on refreshRecipeData (e.g. after editing a recipe).
final myRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  ref.watch(recipeRefreshTriggerProvider);
  return RecipeService.instance.getMyRecipes();
});

/// Screen displaying recipes created by the current user
class MyRecipesScreen extends ConsumerWidget {
  const MyRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);
    final textPrimary = AppColors.textPrimary(context);

    return Scaffold(
      backgroundColor: AppColors.recipeBg(context),
      appBar: recipeListAppBar(
        context,
        title: Text(context.tr('my_recipes')),
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: textPrimary),
            onPressed: () => context.push('/recipes/add'),
          ),
        ],
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => RecipeErrorView(
          onRetry: () => ref.invalidate(myRecipesProvider),
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
                      bottom: 100 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final recipe = recipes[index];
                          return _MyRecipeCard(
                            recipe: recipe,
                            onTap: () => context.push('/recipes/${recipe.id}', extra: recipe),
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
    return RecipeEmptyView(
      icon: Icons.restaurant_menu_rounded,
      title: context.tr('no_my_recipes'),
      subtitle: context.tr('create_recipe_hint'),
      action: OutlinedButton.icon(
        onPressed: () => context.push('/recipes/add'),
        icon: Icon(Icons.add_rounded, color: AppColors.textPrimary(context), size: 20),
        label: Text(
          context.tr('create_recipe'),
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                memCacheWidth: (100 * MediaQuery.devicePixelRatioOf(context)).round(),
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
                      _formatDate(context, recipe.createdAt),
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

  String _formatDate(BuildContext context, DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    String ago(String key, int count) =>
        context.tr(key, params: {'count': '$count'});

    if (days == 0) return context.tr('today');
    if (days == 1) return context.tr('yesterday');
    if (days < 7) return ago('time_days_ago', days);
    if (days < 30) return ago('time_weeks_ago', days ~/ 7);
    if (days < 365) return ago('time_months_ago', days ~/ 30);
    return ago('time_years_ago', days ~/ 365);
  }
}
