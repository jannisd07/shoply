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

/// "Alle Rezepte" and "Beliebt diese Woche" (R-04, Konzept 13 §6) in the
/// D2-Rezepte style.
///
/// "Alle": like a category page (count, filters, sort menu, default "Neu").
/// "Beliebt": the server's ranking (kept on the device, so it shows at once)
/// with "Nach Bewertungen", no filters; recipes the ranking does not know
/// follow in the local order.
class AllRecipesScreen extends ConsumerStatefulWidget {
  const AllRecipesScreen({
    super.key,
    this.popularOnly = false,
    this.initialFilter,
    this.initialSort,
  });

  final bool popularOnly;

  /// A filter that starts on (`?filter=`).
  final RecipeListFilter? initialFilter;

  /// The order to start with (`?sort=`).
  final RecipeSort? initialSort;

  @override
  ConsumerState<AllRecipesScreen> createState() => _AllRecipesScreenState();
}

class _AllRecipesScreenState extends ConsumerState<AllRecipesScreen>
    with RecipesAvoContext {
  late final Set<RecipeListFilter> _active = {?widget.initialFilter};
  late RecipeSort _sort = widget.initialSort ?? RecipeSort.newest;

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
    final all = catalogue.recipes;

    void open(Recipe r) => openBrowseRecipe(context, r);
    void menu(BuildContext anchor, Recipe r) =>
        showRecipeCardMenu(anchor, ref, r);

    if (widget.popularOnly) {
      final ids = ref.watch(
        recipesBrowsePrefsProvider.select((p) => p.highlights?.popularIds),
      );
      final ranked = popularRecipes(all, ids ?? const []);
      return RecipesBrowsePage(
        onBack: () => context.pop(),
        onRefresh: () => refreshRecipeCatalogue(ref),
        content: RecipesBrowsePageContent(
          title: context.tr('recipe_browse_popular'),
          subtitle: context.tr('recipe_browse_popular_meta'),
          loading: !catalogue.known,
          total: ranked.length,
          recipes: ranked,
          offline: offline,
          refreshFailed: catalogue.refreshFailed,
          onRetry: () => refreshRecipeCatalogue(ref),
          fits: fits,
          showCalories: calories,
          onOpen: open,
          onMenu: menu,
          onCreate: () => openRecipeEditor(context),
        ),
      );
    }

    final filters = availableListFilters(
      all,
      hasProfile: profile.hasProfile,
      fits: fits,
      keep: _active,
    );
    final shown = sortRecipes(
      applyListFilters(all, _active, fits: fits),
      _sort,
    );
    return RecipesBrowsePage(
      onBack: () => context.pop(),
      sort: _sort,
      onSort: (s) => setState(() => _sort = s),
      onRefresh: () => refreshRecipeCatalogue(ref),
      content: RecipesBrowsePageContent(
        title: context.tr('recipe_browse_all_title'),
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
        onOpen: open,
        onMenu: menu,
        onCreate: () => openRecipeEditor(context),
      ),
    );
  }
}
