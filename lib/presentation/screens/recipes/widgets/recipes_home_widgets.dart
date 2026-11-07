import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/presentation/screens/recipes/recipe_user_diet.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_image_card.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';

/// Building blocks of the Recipes tab (`recipes_screen.dart`).

/// Paper "kicker" section header with an optional "See all" link.
class RecipeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const RecipeSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                context.tr('see_all'),
                style: TextStyle(
                  color: AppColors.accentColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opaque card surface for tappable tiles inside scrolling content.
///
/// Matches `AdaptiveGlass`'s opaque fallback. Native Liquid Glass is a
/// platform view per tile, and a dozen of them inside a scroll view caused
/// severe scroll jank on iOS, so scrolling content uses this instead.
class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

/// One number + label in the community stats banner.
class RecipeStatItem extends StatelessWidget {
  final String value;
  final String label;

  const RecipeStatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: PaperTextStyles.serif(19, color: AppColors.textPrimary(context)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
        ),
      ],
    );
  }
}

/// "Recipe of the week" hero card.
class FeaturedRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const FeaturedRecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image block with kicker + bookmark
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: recipe.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFB7C4A9),
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFB7C4A9),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 40,
                        color: Color(0xFF42513A),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PaperColors.paper.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.tr('recipe_of_the_week').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: PaperColors.creamInk,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => ref
                          .read(savedRecipesProvider.notifier)
                          .toggleSave(recipe.id),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: PaperColors.paper.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 18,
                          color: isSaved ? accent : PaperColors.creamInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Paper content panel below the image
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(
                  left: BorderSide(color: AppColors.border(context)),
                  right: BorderSide(color: AppColors.border(context)),
                  bottom: BorderSide(color: AppColors.border(context)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PaperTextStyles.serif(19, color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.totalTimeMinutes} min · ${recipe.authorName}'
                    '${recipe.averageRating > 0 ? ' · ★ ${recipe.averageRating.toStringAsFixed(1)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 13, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('add_to_list'),
                        style: TextStyle(fontSize: 12, color: accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shortcut tile (My recipes, Saved, Drafts, Creators).
class RecipeActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const RecipeActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _SurfaceCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: AppColors.textSecondary(context)),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentColor(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Browse-by-category tile.
class RecipeCategoryCard extends StatelessWidget {
  final RecipeCategory category;
  final int count;
  final VoidCallback onTap;

  const RecipeCategoryCard({
    super.key,
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _SurfaceCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.tr(category.nameKey),
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Opacity(
              opacity: count > 0 ? 1.0 : 0.0,
              child: Text(
                '$count',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + recipe count, for the "Top creators" carousel.
class CreatorAvatarCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int recipeCount;
  final VoidCallback onTap;

  const CreatorAvatarCard({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.recipeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            AuthorAvatar(
              name: name,
              avatarUrl: avatarUrl,
              size: 56,
              backgroundColor: AppColors.surface(context),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              initialStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '$recipeCount ${context.tr(recipeCount == 1 ? 'recipe_singular' : 'recipes_plural')}',
              style: TextStyle(color: textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal carousel of photo tiles.
class RecipeCarousel extends StatelessWidget {
  final List<Recipe> recipes;
  final void Function(Recipe recipe) onTap;

  const RecipeCarousel({super.key, required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return RecipeImageCard(
            recipe: recipe,
            onTap: () => onTap(recipe),
            width: 160,
            height: 196,
            margin: const EdgeInsets.only(right: 12, bottom: 6),
          );
        },
      ),
    );
  }
}

/// Grid photo tile that carries the user's diet/allergy compatibility badge.
///
/// A warning that quietly disappears because the layout got prettier is a
/// regression, not a redesign, so it rides along as a chip on the image.
class DietAwareRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const DietAwareRecipeCard({super.key, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    RecipeCompatibility? compatibility;
    if (user != null && user.hasDietProfile) {
      compatibility = IngredientSubstitutionService.checkRecipeCompatibility(
        recipe: recipe,
        allergies: user.allergyTypes,
        diets: user.dietTypes,
      );
    }

    Color? badgeColor;
    if (compatibility != null) {
      badgeColor = compatibility.isCompatible
          ? (compatibility.needsModifications ? Colors.orange : Colors.green)
          : Colors.red;
    }

    // Time and author on one line. The description does not fit a tile and
    // the detail screen shows it in full anyway.
    final parts = <String>[
      if (recipe.totalTimeMinutes > 0) '${recipe.totalTimeMinutes} min',
      if (recipe.authorName.isNotEmpty) recipe.authorName,
    ];

    return RecipeImageCard(
      recipe: recipe,
      onTap: onTap,
      badgeText: compatibility?.badgeText,
      badgeColor: badgeColor,
      metaLine: parts.join(' · '),
    );
  }
}
