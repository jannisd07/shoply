import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';

/// Grid tile with the image on top and name, time and rating below, plus a
/// bookmark toggle. Used by the "All / Popular recipes" and category pages
/// (each used to carry its own byte-identical copy).
class RecipeGridCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeGridCard({super.key, required this.recipe, required this.onTap});

  static const double _imageHeight = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));
    final placeholder = Container(
      height: _imageHeight,
      color: AppColors.recipeInput(context),
      child: const Center(child: Icon(Icons.restaurant_rounded)),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.recipeSurface(context),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: recipe.imageUrl,
                  height: _imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Two-column grid: decode at half the screen width.
                  memCacheWidth: (MediaQuery.sizeOf(context).width /
                          2 *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(savedRecipesProvider.notifier)
                        .toggleSave(recipe.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSaved
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.5),
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
                          Icon(Icons.star_rounded,
                              size: 12, color: AppColors.recipeStarColor(context)),
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

/// Two-column sliver grid of [RecipeGridCard]s that open the detail page.
class RecipeSliverGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(Recipe recipe) onTap;

  const RecipeSliverGrid({super.key, required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 100 + MediaQuery.paddingOf(context).bottom,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => RecipeGridCard(
            recipe: recipes[index],
            onTap: () => onTap(recipes[index]),
          ),
          childCount: recipes.length,
        ),
      ),
    );
  }
}
