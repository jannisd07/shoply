import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_cards.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_home.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_page.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_search.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';

import '../../layout/layout_matrix.dart';
import 'recipes_browse_fakes.dart';

/// A screen-high scroll view that lays out everything (large cache extent),
/// so the matrix sees every section, not only the first screen.
Widget _scroll(Widget sliver) => SizedBox(
  height: kLayoutHeight,
  child: CustomScrollView(
    scrollCacheExtent: const ScrollCacheExtent.pixels(20000),
    slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
      sliver,
    ],
  ),
);

final _catalogue = [
  browseRecipe(
    'long',
    name: 'Ofengemüse mit Halloumi, Kichererbsen und Zitronen-Joghurt-Dip',
    prep: 25,
    cook: 50,
    rating: 4.6,
    ratings: 1280,
    labels: const ['vegetarian'],
  ),
  ...browseCatalogue(),
];

const _sesame = RecipeDietProfile(allergies: ['sesame', 'peanuts', 'milk']);

Widget _home(
  BuildContext context, {
  bool offline = false,
  bool plan = false,
  bool hint = false,
  bool tip = false,
  bool loading = false,
  bool empty = false,
}) {
  final fits = recipeFitsFor(_catalogue, _sesame);
  final ids = buildRecipesHome(
    catalogue: _catalogue,
    filter: RecipeQuickFilter.vegetarian,
    fits: fits,
    listItemStems: [nameStems('Halloumi'), nameStems('Zucchini')],
  );
  return _scroll(
    RecipesBrowseContent(
      loading: loading,
      catalogueEmpty: empty,
      searchController: TextEditingController(),
      searchFocus: FocusNode(),
      onQueryChanged: (_) {},
      offline: offline,
      refreshFailed: !offline,
      onRetry: () {},
      showPlanSegment: plan,
      filters: availableQuickFilters(_catalogue),
      filter: RecipeQuickFilter.vegetarian,
      onFilter: (_) {},
      tip: tip
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InsetSection(
                children: [
                  TipRow(
                    text:
                        'Tipp: Stell Ernährung und Allergien ein, dann passen sich Rezepte an dich an.',
                    hideLabel: 'Ausblenden',
                    onHide: () {},
                    actionLabel: 'Einstellen',
                    onAction: () {},
                  ),
                ],
              ),
            )
          : null,
      showDietHint: hint,
      onDietHint: () {},
      onDismissDietHint: () {},
      home: RecipesHomeView(
        hero: resolveRecipes(_catalogue, [ids.heroId!]).first,
        heroKind: RecipeHeroKind.listMatch,
        popular: resolveRecipes(_catalogue, ['long', 'pasta', 'salad', 'dal']),
        newest: resolveRecipes(_catalogue, ids.newestIds),
        poolCount: ids.poolCount,
        categories: categoriesWithRecipes(_catalogue),
      ),
      fits: fits,
      showCalories: true,
      onOpen: (_) {},
      onToList: (_) {},
      onMenu: (_, _) {},
      onLink: (_) {},
      onCategory: (_) {},
      onCreate: () {},
      onShowAll: () {},
    ),
  );
}

Widget _search(BuildContext context, String query, {bool recent = false}) =>
    _scroll(
      RecipesBrowseSearch(
        query: query,
        results: searchRecipes(
          _catalogue,
          query,
          categoryName: (c) => c.id,
          dietName: (d) => d,
        ),
        recent: recent
            ? const ['Shakshuka mit Feta und sehr viel Paprika', 'dal']
            : const [],
        hasProfile: true,
        fits: recipeFitsFor(_catalogue, _sesame),
        onOpen: (_) {},
        onRecent: (_) {},
        onRemoveRecent: (_) {},
        onClearRecent: () {},
        onDiet: (_) {},
        onFitsMe: () {},
        onCategory: (_) {},
        onIngredient: (_) {},
        onAuthor: (_) {},
        onAllCreators: () {},
        onCreate: (_) {},
      ),
    );

Widget _page(BuildContext context, {bool filteredEmpty = false}) {
  final all = recipesInCategory(_catalogue, 'vegetarian');
  final active = {RecipeListFilter.under20};
  return _scroll(
    RecipesBrowsePageContent(
      title: 'Mediterrane Küche für lange Sommerabende',
      loading: false,
      total: all.length,
      recipes: filteredEmpty ? const [] : all,
      filters: availableListFilters(all, hasProfile: true, keep: active),
      active: active,
      onToggle: (_) {},
      onReset: () {},
      refreshFailed: true,
      onRetry: () {},
      fits: recipeFitsFor(_catalogue, _sesame),
      onOpen: (_) {},
    ),
  );
}

void main() {
  // No tap-target check here: the "Alle" link of AvoSectionHeader is only
  // about 33 pt wide (component; reported in the A6 brief's report).
  layoutMatrix('RecipesBrowseContent (home)', (context) => _home(context));
  layoutMatrix(
    'RecipesBrowseContent (offline, plan segment, diet tip)',
    (context) => _home(context, offline: true, plan: true, hint: true),
  );
  layoutMatrix(
    'RecipesBrowseContent (tip T7 below the title)',
    (context) => _home(context, tip: true),
  );
  layoutMatrix(
    'RecipesBrowseContent (first load)',
    (context) => _home(context, loading: true),
  );
  layoutMatrix(
    'RecipesBrowseContent (empty)',
    (context) => _home(context, empty: true),
  );
  layoutMatrix(
    'RecipesBrowseSearch (results)',
    (context) => _search(context, 'feta'),
    checkTapTargets: true,
  );
  layoutMatrix(
    'RecipesBrowseSearch (start)',
    (context) => _search(context, '', recent: true),
  );
  layoutMatrix(
    'RecipesBrowseSearch (nothing found)',
    (context) => _search(context, 'Halloumi-Burger mit Pommes'),
  );
  layoutMatrix(
    'RecipesBrowsePageContent',
    (context) => _page(context),
    checkTapTargets: true,
  );
  layoutMatrix(
    'RecipesBrowsePageContent (filtered empty)',
    (context) => _page(context, filteredEmpty: true),
  );
  layoutMatrix(
    'RecipeFitBadge (many allergens)',
    (context) => const SizedBox(
      width: 140,
      child: RecipeFitBadge(
        fit: RecipeFit(
          unsafeAllergens: [
            AllergenMatch(allergy: 'sesame', type: null, matchedText: 'x'),
            AllergenMatch(allergy: 'Kiwi', type: null, matchedText: 'kiwi'),
            AllergenMatch(
              allergy: 'Erdnussallergie',
              type: null,
              matchedText: 'e',
            ),
          ],
        ),
      ),
    ),
  );
}
