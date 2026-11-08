import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_actions.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_avo.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_page.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';

/// A category or diet page (R-03, Konzept 13 §5) in the D2-Rezepte style:
/// large title ("Mediterran", "Rezepte mit Feta"), "38 Rezepte" or "17 von 38
/// Rezepten", filter chips (AND, only filters that occur, "Passt zu mir"
/// preselected with allergies), the sort menu and the two-column grid.
///
/// Recipes come from the local catalogue at once; filters last for this
/// visit only.
class CategoryRecipesScreen extends ConsumerStatefulWidget {
  const CategoryRecipesScreen({
    super.key,
    required this.categoryId,
    this.initialFilter,
    this.initialSort,
  });

  /// A label id (`mediterranean`, `gluten-free`) or `ingredient:<name>`.
  final String categoryId;

  /// A filter that starts on (`?filter=`).
  final RecipeListFilter? initialFilter;

  /// The order to start with (`?sort=`); default "Beliebt".
  final RecipeSort? initialSort;

  @override
  ConsumerState<CategoryRecipesScreen> createState() =>
      _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends ConsumerState<CategoryRecipesScreen>
    with RecipesAvoContext {
  late final Set<RecipeListFilter> _active = {?widget.initialFilter};
  late RecipeSort _sort = widget.initialSort ?? RecipeSort.popular;
  bool _defaultsApplied = false;

  void _toggle(RecipeListFilter f) => setState(() {
    if (!_active.remove(f)) _active.add(f);
  });

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(recipeCatalogueProvider);
    final fits = ref.watch(recipeFitsProvider);
    final profile = ref.watch(recipeDietProfileProvider);
    final offline = ref.watch(isOfflineProvider);
    final calories = ref.watch(moduleEnabledProvider(AppModule.calories));

    // "Passt zu mir" starts on with an allergy profile (Konzept 13 §5.3).
    if (!_defaultsApplied && ref.watch(recipeDietProfileKnownProvider)) {
      _defaultsApplied = true;
      if (profile.allergies.isNotEmpty && widget.initialFilter == null) {
        _active.add(RecipeListFilter.fitsMe);
      }
    }

    final all = recipesInCategory(catalogue.recipes, widget.categoryId);
    final filters = availableListFilters(
      all,
      hasProfile: profile.hasProfile,
      fits: fits,
      categoryId: widget.categoryId,
      keep: _active,
    );
    final shown = sortRecipes(
      applyListFilters(all, _active, fits: fits),
      _sort,
    );
    final title = recipeCategoryTitle(context, widget.categoryId);

    return RecipesBrowsePage(
      onBack: () => context.pop(),
      sort: _sort,
      onSort: (s) => setState(() => _sort = s),
      onRefresh: () => refreshRecipeCatalogue(ref),
      content: RecipesBrowsePageContent(
        title: title,
        loading: !catalogue.known,
        total: all.length,
        recipes: shown,
        filters: filters,
        active: _active,
        onToggle: _toggle,
        onReset: () => setState(_active.clear),
        offline: offline,
        refreshFailed: catalogue.refreshFailed,
        onRetry: () => refreshRecipeCatalogue(ref),
        fits: fits,
        showCalories: calories,
        onOpen: (Recipe r) => openBrowseRecipe(context, r),
        onMenu: (anchor, r) => showRecipeCardMenu(anchor, ref, r),
        emptyTitle: context.tr(
          'recipe_browse_category_empty_title',
          params: {'name': title},
        ),
        onCreate: () => openRecipeEditor(context),
      ),
    );
  }
}
