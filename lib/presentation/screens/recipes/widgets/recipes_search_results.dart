import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_home_widgets.dart';

/// Dietary preferences a search can jump to, with the words that match them
/// and the translation key of their display name.
///
/// 'dairy-free' is deliberately absent — RecipeLabelingService never
/// generates that label, so /recipes/category/dairy-free would always be an
/// empty results page.
const Map<String, ({List<String> keywords, String trKey})> _preferences = {
  'vegan': (keywords: ['vegan', 'plant-based', 'pflanzlich'], trKey: 'category_vegan'),
  'vegetarian': (keywords: ['vegetarian', 'vegetarisch', 'veggie'], trKey: 'category_vegetarian'),
  'quick': (keywords: ['quick', 'schnell', 'fast', 'easy'], trKey: 'category_quick'),
  'healthy': (keywords: ['healthy', 'gesund', 'light', 'leicht'], trKey: 'category_healthy'),
  'gluten-free': (keywords: ['gluten-free', 'glutenfrei', 'gluten free'], trKey: 'filter_gluten_free'),
  'low-carb': (keywords: ['low-carb', 'keto', 'low carb'], trKey: 'diet_low_carb'),
};

/// Suggestions (categories, diets, creators) plus the recipe grid for a
/// Recipes-tab search.
class RecipesSearchResults extends StatelessWidget {
  final String query;
  final List<Recipe> results;
  final List<RecipeAuthorSummary> authors;
  final void Function(Recipe recipe) onRecipeTap;

  const RecipesSearchResults({
    super.key,
    required this.query,
    required this.results,
    required this.authors,
    required this.onRecipeTap,
  });

  /// Category/diet chips need two characters: one letter used to match
  /// nearly every chip.
  static const _minSuggestionLength = 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final q = query.toLowerCase().trim();
    final suggest = q.length >= _minSuggestionLength;

    final matchingCategories = !suggest
        ? const <RecipeCategory>[]
        : recipeCategories
            .where((cat) =>
                context.tr(cat.nameKey).toLowerCase().contains(q) ||
                cat.id.toLowerCase().contains(q) ||
                cat.keywords.any((k) => k.toLowerCase().contains(q)))
            .toList();

    final matchingPreferences = !suggest
        ? const <String>[]
        : [
            for (final entry in _preferences.entries)
              if (entry.value.keywords
                  .any((k) => k.contains(q) || q.contains(k)))
                entry.key,
          ];

    final matchingAuthors = q.isEmpty
        ? const <RecipeAuthorSummary>[]
        : authors.where((a) => a.name.toLowerCase().contains(q)).take(3).toList();

    Widget sectionTitle(String text) => Text(
          text,
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        );

    Widget chip({required Widget leading, required String label, required VoidCallback onTap, required Color color}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    final nothingFound = results.isEmpty &&
        matchingCategories.isEmpty &&
        matchingAuthors.isEmpty &&
        matchingPreferences.isEmpty;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (matchingCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle(context.tr('recipe_search_categories')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in matchingCategories)
                        chip(
                          leading: Text(cat.icon, style: const TextStyle(fontSize: 16)),
                          label: context.tr(cat.nameKey),
                          color: cat.color.withValues(alpha: 0.15),
                          onTap: () => context.push('/recipes/category/${cat.id}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (matchingPreferences.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle(context.tr('recipe_search_diets')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pref in matchingPreferences)
                        chip(
                          leading: Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                          ),
                          label: context.tr(_preferences[pref]!.trKey),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          onTap: () => context.push('/recipes/category/$pref'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (matchingAuthors.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle(context.tr('creators')),
                  const SizedBox(height: 8),
                  for (final author in matchingAuthors)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AuthorAvatar(
                        name: author.name,
                        avatarUrl: author.avatarUrl,
                        size: 40,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : PaperColors.cream,
                        initialStyle: TextStyle(color: textPrimary),
                      ),
                      title: Text(
                        author.name.isEmpty ? context.tr('unknown_author') : author.name,
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${author.recipeCount} ${context.tr(author.recipeCount == 1 ? 'recipe_singular' : 'recipes_plural')}',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      onTap: () => context.push(
                        '/author/${author.id}',
                        extra: {'authorName': author.name},
                      ),
                    ),
                ],
              ),
            ),
          ),

        if (results.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: sectionTitle(context.tr(
                'recipe_search_recipes_count',
                params: {'count': '${results.length}'},
              )),
            ),
          ),

        if (nothingFound && q.isNotEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('no_results'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('try_different_search'), style: TextStyle(color: textSecondary)),
                ],
              ),
            ),
          )
        else if (results.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 100 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => DietAwareRecipeCard(
                  recipe: results[index],
                  onTap: () => onRecipeTap(results[index]),
                ),
                childCount: results.length,
              ),
            ),
          ),
      ],
    );
  }
}
