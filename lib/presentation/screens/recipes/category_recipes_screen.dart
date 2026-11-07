import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_grid_card.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_state_views.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';

/// Recipes carrying a category label, filtered from the app-wide recipe
/// list instead of downloading the whole table again per category. Disposed
/// when the page closes; recomputed when refreshRecipeData invalidates
/// [recipesProvider].
final categoryRecipesProvider =
    FutureProvider.autoDispose.family<List<Recipe>, String>((ref, category) async {
  final all = await ref.watch(recipesProvider.future);
  final needle = category.toLowerCase();
  return all
      .where((recipe) =>
          recipe.labels.any((label) => label.toLowerCase().contains(needle)))
      .toList();
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

    return Scaffold(
      backgroundColor: AppColors.recipeBg(context),
      appBar: recipeListAppBar(
        context,
        title: Text(_getDisplayName(context, categoryId)),
        onBack: () => context.pop(),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => RecipeErrorView(
          onRetry: () => ref.invalidate(recipesProvider),
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
                            onRefresh: () async => ref.invalidate(recipesProvider),
                          ),
                          RecipeSliverGrid(
                            recipes: filtered,
                            onTap: (recipe) => context.push(
                                '/recipes/${recipe.id}',
                                extra: recipe),
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
    return RecipeEmptyView(
      icon: hasActiveFilters
          ? Icons.filter_list_off_rounded
          : Icons.search_off_rounded,
      title: context.tr('no_recipes_found'),
      subtitle: context.tr('no_recipes_in_category'),
      action: hasActiveFilters
          ? TextButton(
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
            )
          : null,
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
