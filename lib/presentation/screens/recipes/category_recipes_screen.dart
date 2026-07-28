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

/// Provider for recipes by category
final categoryRecipesProvider = FutureProvider.family<List<Recipe>, String>((ref, category) async {
  ref.watch(recipeRefreshTriggerProvider);
  return RecipeService().getRecipesByCategory(category);
});

/// Active filter chips state per category
final _categoryFiltersProvider =
    StateProvider.family<Set<String>, String>((ref, categoryId) => {});

/// Maps category label IDs (as stored in DB) to translation keys
///
/// Includes both the browsable categories in `recipe_categories.dart` and the
/// dietary-preference IDs that `recipes_screen.dart` can also link here from
/// search (e.g. `/recipes/category/gluten-free`) — those aren't browsable
/// categories in their own right, so they have no entry in recipeCategories.
const Map<String, String> _categoryTrKeys = {
  'italian':       'category_italian',
  'asian':         'category_asian',
  'vegetarian':    'category_vegetarian',
  'vegan':         'category_vegan',
  'snack':         'category_desserts',
  'breakfast':     'category_breakfast',
  'quick':         'category_quick',
  'healthy':       'category_healthy',
  'comfort-food':  'category_comfort',
  'mexican':       'category_mexican',
  'mediterranean': 'category_mediterranean',
  'seafood':       'category_seafood',
  'soup':          'category_soup',
  'gluten-free':   'filter_gluten_free',
  'low-carb':      'diet_low_carb',
};

/// Filter chip definition
class _FilterChip {
  final String labelId; // matches a recipe label in the DB
  final String trKey;   // translation key
  final IconData icon;

  const _FilterChip({required this.labelId, required this.trKey, required this.icon});
}

/// All available filter chips shown at the top of every category page.
/// Only chips whose label exists on at least some recipes in the category
/// are shown — the rest are filtered out after the recipes load.
const List<_FilterChip> _allFilterChips = [
  _FilterChip(labelId: 'quick',       trKey: 'filter_quick',       icon: CupertinoIcons.bolt_fill),
  _FilterChip(labelId: '30min',       trKey: 'filter_30min',       icon: CupertinoIcons.time),
  _FilterChip(labelId: 'easy',        trKey: 'filter_easy',        icon: CupertinoIcons.star),
  _FilterChip(labelId: 'medium',      trKey: 'filter_medium',      icon: CupertinoIcons.star_lefthalf_fill),
  _FilterChip(labelId: 'advanced',    trKey: 'filter_advanced',    icon: CupertinoIcons.star_fill),
  _FilterChip(labelId: 'vegetarian',  trKey: 'filter_vegetarian',  icon: CupertinoIcons.leaf_arrow_circlepath),
  _FilterChip(labelId: 'vegan',       trKey: 'filter_vegan',       icon: CupertinoIcons.tree),
  _FilterChip(labelId: 'gluten-free', trKey: 'filter_gluten_free', icon: CupertinoIcons.checkmark_shield),
  _FilterChip(labelId: 'healthy',     trKey: 'filter_healthy',     icon: CupertinoIcons.heart_fill),
];

String _formatCategoryFallback(String categoryId) {
  return categoryId
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String _getDisplayName(BuildContext context, String categoryId) {
  final key = _categoryTrKeys[categoryId];
  if (key != null) {
    final translated = context.tr(key);
    if (translated != key) return translated;
  }
  return _formatCategoryFallback(categoryId);
}

List<Recipe> _applyFilters(List<Recipe> recipes, Set<String> activeFilters) {
  if (activeFilters.isEmpty) return recipes;
  return recipes
      .where((r) => activeFilters.every((f) => r.labels.contains(f)))
      .toList();
}

/// Only show chips that are relevant to at least one recipe in this category.
List<_FilterChip> _relevantChips(List<Recipe> recipes, String categoryId) {
  final presentLabels = <String>{};
  for (final r in recipes) {
    presentLabels.addAll(r.labels);
  }
  return _allFilterChips
      .where((c) => c.labelId != categoryId && presentLabels.contains(c.labelId))
      .toList();
}

class CategoryRecipesScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryRecipesScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(categoryRecipesProvider(categoryId));
    final activeFilters = ref.watch(_categoryFiltersProvider(categoryId));
    final bg = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getDisplayName(context, categoryId),
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
        data: (allRecipes) {
          final chips = _relevantChips(allRecipes, categoryId);
          final filtered = _applyFilters(allRecipes, activeFilters);
          return Column(
            children: [
              // Filter chips bar — only shown when there are relevant chips
              if (chips.isNotEmpty)
                _FilterChipsBar(
                  chips: chips,
                  activeFilters: activeFilters,
                  onToggle: (labelId) {
                    final current = ref.read(_categoryFiltersProvider(categoryId));
                    final updated = Set<String>.from(current);
                    if (updated.contains(labelId)) {
                      updated.remove(labelId);
                    } else {
                      updated.add(labelId);
                    }
                    ref.read(_categoryFiltersProvider(categoryId).notifier).state = updated;
                  },
                ),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(
                        context,
                        ref,
                        hasActiveFilters: activeFilters.isNotEmpty,
                        categoryId: categoryId,
                      )
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
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final recipe = filtered[index];
                                  return _CategoryRecipeCard(
                                    recipe: recipe,
                                    onTap: () =>
                                        context.push('/recipes/${recipe.id}'),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool hasActiveFilters,
    required String categoryId,
  }) {
    final textSecondary = AppColors.textSecondary(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters
                  ? Icons.filter_list_off_rounded
                  : Icons.search_off_rounded,
              size: 80,
              color: textSecondary.withValues(alpha: 0.5),
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
                color: textSecondary.withValues(alpha: 0.7),
              ),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => ref
                    .read(_categoryFiltersProvider(categoryId).notifier)
                    .state = {},
                child: Text(
                  context.tr('clear_filters'),
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chips bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChipsBar extends StatelessWidget {
  final List<_FilterChip> chips;
  final Set<String> activeFilters;
  final void Function(String labelId) onToggle;

  const _FilterChipsBar({
    required this.chips,
    required this.activeFilters,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.recipeBg(context),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isActive = activeFilters.contains(chip.labelId);
          return _Chip(
            label: context.tr(chip.trKey),
            icon: chip.icon,
            isActive: isActive,
            onTap: () => onToggle(chip.labelId),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accent;

    final bgColor = isActive
        ? accent
        : (isDark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.055));

    final fgColor = isActive
        ? Colors.white
        : (isDark ? Colors.white.withValues(alpha: 0.75) : Colors.black.withValues(alpha: 0.6));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fgColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w500,
                color: fgColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipe card
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _CategoryRecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
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
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
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
                        Icon(Icons.schedule_rounded,
                            size: 12, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: TextStyle(
                              color: textSecondary, fontSize: 11),
                        ),
                        if (recipe.averageRating > 0) ...[
                          const Spacer(),
                          Icon(Icons.star_rounded,
                              size: 12,
                              color: AppColors.recipeStarColor(context)),
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
