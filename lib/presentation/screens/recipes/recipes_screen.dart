import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_actions.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_avo.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_home.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_page.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_search.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';
import 'package:shoply/routes/areas/plan_routes.dart';
import 'package:shoply/routes/route_paths.dart';

export 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_home.dart'
    show RecipesSegment;

/// D2-Rezepte toolbar: the bookmark glyph is 20 pt and filled.
const double _kBookmarkSize = 20; // D2

/// Root of the "Rezepte" tab (D2-Rezepte, Konzept 13 §3–4): large title,
/// the search (recipes, ingredients, creators) as a state of the tab, the
/// chips "Für dich / Schnell / Vegetarisch …", the hero "Passt zu deiner
/// Liste" with "Zutaten auf die Liste", "Beliebt diese Woche", "Neu" and
/// "Kategorien". The toolbar holds "Gespeichert" and "Mehr" (Meine Rezepte,
/// Entwürfe, Ersteller, Neues Rezept). With the meal plan module on, the
/// segment "Entdecken | Wochenplan" shows Teil B's plan.
///
/// Everything comes from the local state at once; the server's answer
/// replaces it underneath, and what the sections show is fixed per visit so
/// nothing jumps. Sets Avo's screen context to `recipes` while visible.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key, this.initialQuery, this.initialSegment});

  /// Pre-fills the search, e.g. from Siri (`shoply://recipes/search?q=`).
  final String? initialQuery;

  /// Opens the Wochenplan segment (`/recipes?segment=plan`, `/plan`).
  final RecipesSegment? initialSegment;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with RecipesAvoContext {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _moreKey = GlobalKey();

  String _query = '';
  bool _focused = false;
  RecipeQuickFilter _filter = RecipeQuickFilter.forYou;
  late RecipesSegment _segment;

  /// What each chip shows, fixed for this visit of the tab.
  final Map<RecipeQuickFilter, RecipesHomeIds> _frozen = {};

  /// Server highlights for this visit; newer ones are saved for the next.
  RecipeHighlights? _highlights;
  bool _hadStoredHighlights = false;
  bool? _tickerOn;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment ?? RecipesSegment.discover;
    _focus.addListener(_onFocus);
    _highlights = ref.read(recipesBrowsePrefsProvider).highlights;
    _hadStoredHighlights = _highlights != null;
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _search.text = q;
      _query = q;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadHighlights());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Coming back to the tab is a new visit: sections may change now.
    final on = TickerMode.valuesOf(context).enabled;
    if (_tickerOn == false && on) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_frozen.clear);
      });
    }
    _tickerOn = on;
  }

  @override
  void didUpdateWidget(RecipesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Siri on a live tab: every new `?q=` sets the search again.
    final q = widget.initialQuery;
    if (q != null && q != oldWidget.initialQuery && q != _search.text) {
      _search.text = q;
      _query = q;
    }
    final segment = widget.initialSegment;
    if (segment != oldWidget.initialSegment) {
      _segment = segment ?? RecipesSegment.discover;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
  }

  Future<void> _loadHighlights({bool apply = false}) async {
    try {
      final loaded = await ref.read(recipeHighlightsLoaderProvider)();
      if (loaded == null || !mounted) return;
      ref.read(recipesBrowsePrefsProvider.notifier).saveHighlights(loaded);
      if (apply || !_hadStoredHighlights) {
        setState(() {
          _highlights = loaded;
          _hadStoredHighlights = true;
          _frozen.clear();
        });
      }
    } catch (e) {
      debugPrint('⚠️ [RECIPES] Highlights failed: $e');
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      refreshRecipeCatalogue(ref),
      _loadHighlights(apply: true),
    ]);
    if (mounted) setState(_frozen.clear);
  }

  // ------------------------------------------------------------- actions

  void _open(Recipe recipe) {
    if (_query.trim().isNotEmpty) _remember(_query);
    openBrowseRecipe(context, recipe);
  }

  void _remember(String query) =>
      ref.read(recipesBrowsePrefsProvider.notifier).addRecentSearch(query);

  void _setQuery(String q) {
    _search.text = q;
    _search.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q);
  }

  void _link(RecipesHomeLink link, RecipeQuickFilter filter, bool hasProfile) {
    final sort = switch (link) {
      RecipesHomeLink.newest => RecipeSort.newest,
      _ => RecipeSort.popular,
    };
    switch (filter) {
      case RecipeQuickFilter.forYou:
        switch (link) {
          case RecipesHomeLink.popular:
            context.push('${RoutePaths.recipes}/popular');
          case RecipesHomeLink.newest:
            openAllRecipes(context, sort: RecipeSort.newest);
          case RecipesHomeLink.pool:
            openAllRecipes(
              context,
              filter: hasProfile ? RecipeListFilter.fitsMe : null,
            );
        }
      case RecipeQuickFilter.quick:
        openAllRecipes(context, filter: RecipeListFilter.under20, sort: sort);
      case RecipeQuickFilter.vegetarian:
        openRecipeCategory(context, 'vegetarian', sort: sort);
      case RecipeQuickFilter.vegan:
        openRecipeCategory(context, 'vegan', sort: sort);
      case RecipeQuickFilter.glutenFree:
        openRecipeCategory(context, 'gluten-free', sort: sort);
      case RecipeQuickFilter.healthy:
        openRecipeCategory(context, 'healthy', sort: sort);
    }
  }

  void _more() {
    showAvoMenu(
      context,
      anchorKey: _moreKey,
      items: [
        AvoMenuItem(
          label: context.tr('recipe_browse_my_recipes'),
          onSelected: () => context.push('${RoutePaths.recipes}/my'),
        ),
        AvoMenuItem(
          label: context.tr('recipe_browse_drafts'),
          onSelected: () => context.push('${RoutePaths.recipes}/drafts'),
        ),
        AvoMenuItem(
          label: context.tr('recipe_browse_creators'),
          icon: AvoIcons.people,
          onSelected: () => context.push('${RoutePaths.recipes}/creators'),
        ),
        const AvoMenuDivider(),
        AvoMenuItem(
          label: context.tr('recipe_browse_new_recipe'),
          icon: AvoIcons.plus,
          onSelected: () => openRecipeEditor(context),
        ),
      ],
    );
  }

  /// The older diet hint was wiped away (before T7 took its place): T7 is
  /// hidden for good. After the frame, because hiding notifies the slot.
  void _retireDietTip() {
    final tips = ref.read(tipServiceProvider);
    if (!tips.isAttached || tips.isFinished(TipId.diet)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tips.dismiss(TipId.diet);
    });
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(recipeCatalogueProvider);
    final fits = ref.watch(recipeFitsProvider);
    final profile = ref.watch(recipeDietProfileProvider);
    final profileKnown = ref.watch(recipeDietProfileKnownProvider);
    final offline = ref.watch(isOfflineProvider);
    final calories = ref.watch(moduleEnabledProvider(AppModule.calories));
    final planOn = ref.watch(moduleEnabledProvider(AppModule.mealPlan));
    final prefs = ref.watch(recipesBrowsePrefsProvider);
    final signedIn = ref.watch(authUserIdProvider) != null;
    final language = Localizations.maybeLocaleOf(context)?.languageCode;

    // A new diet profile changes what fits: pick the sections again.
    ref.listen(recipeDietProfileProvider, (previous, next) {
      if (previous != next) setState(_frozen.clear);
    });

    final recipes = catalogue.recipes;
    final filters = availableQuickFilters(recipes);
    final filter = filters.contains(_filter)
        ? _filter
        : RecipeQuickFilter.forYou;
    RecipesHomeIds compute() => buildRecipesHome(
      catalogue: recipes,
      filter: filter,
      fits: fits,
      listItemStems: ref.read(recipeListItemStemsProvider),
      popularIds: _highlights?.popularIds ?? const [],
      weekId: _highlights?.weekId,
      language: language,
    );
    // Fixed once the recipes and the allergies are known.
    final ids = catalogue.known && profileKnown
        ? (_frozen[filter] ??= compute())
        : compute();
    final heroId = ids.heroId;
    final home = RecipesHomeView(
      hero: heroId == null
          ? null
          : resolveRecipes(recipes, [heroId]).firstOrNull,
      heroKind: ids.heroKind,
      popular: resolveRecipes(recipes, ids.popularIds),
      newest: resolveRecipes(recipes, ids.newestIds),
      poolCount: ids.poolCount,
      categories: filter == RecipeQuickFilter.forYou
          ? categoriesWithRecipes(recipes)
          : const [],
    );

    final searching = _focused || _query.trim().isNotEmpty;
    final segment = planOn ? _segment : RecipesSegment.discover;

    Widget? searchSliver;
    if (searching) {
      searchSliver = RecipesBrowseSearch(
        query: _query,
        results: searchRecipes(
          recipes,
          _query,
          categoryName: (c) => context.tr(c.nameKey),
          dietName: (d) => recipeDietLabelName(context, d),
        ),
        recent: prefs.recentSearches,
        hasProfile: profile.hasProfile,
        fits: fits,
        showCalories: calories,
        onOpen: _open,
        onMenu: (anchor, r) => showRecipeCardMenu(anchor, ref, r),
        onRecent: _setQuery,
        onRemoveRecent: (q) =>
            ref.read(recipesBrowsePrefsProvider.notifier).removeRecentSearch(q),
        onClearRecent: () =>
            ref.read(recipesBrowsePrefsProvider.notifier).clearRecentSearches(),
        onDiet: (label) {
          if (_query.trim().isNotEmpty) _remember(_query);
          openRecipeCategory(context, label);
        },
        onFitsMe: () =>
            openAllRecipes(context, filter: RecipeListFilter.fitsMe),
        onCategory: (id) {
          if (_query.trim().isNotEmpty) _remember(_query);
          openRecipeCategory(context, id);
        },
        onIngredient: (name) {
          _remember(_query);
          openRecipeCategory(
            context,
            '$kIngredientCategoryPrefix${name.toLowerCase()}',
          );
        },
        onAuthor: (a) {
          _remember(_query);
          context.push('/author/${a.id}', extra: {'authorName': a.name});
        },
        onAllCreators: () => context.push('${RoutePaths.recipes}/creators'),
        onCreate: (_) => openRecipeEditor(context),
      );
    }

    // The one-time tip of the tab (Konzept 17 §6.1) below the large title:
    // T6 "Zutaten auf die Liste" on the first visit, T7 "Ernährung und
    // Allergien" with "Einstellen" later. Someone who wiped away the older
    // diet hint does not get T7.
    if (prefs.dietHintDismissed) _retireDietTip();
    final tip = TipSlot(
      place: TipPlace.recipes,
      only: prefs.dietHintDismissed
          ? const {TipId.recipeToList}
          : const {TipId.recipeToList, TipId.diet},
      facts: TipFacts(
        ready: !signedIn || profileKnown,
        dietSet: signedIn && profileKnown ? profile.hasProfile : null,
      ),
      wrap: (context, row) => Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.s),
        child: InsetSection(children: [row]),
      ),
    );
    final content = RecipesBrowseContent(
      loading: !catalogue.known,
      catalogueEmpty: catalogue.known && recipes.isEmpty,
      searchController: _search,
      searchFocus: _focus,
      onQueryChanged: (q) => setState(() => _query = q),
      onQuerySubmitted: _remember,
      searching: searching,
      searchSliver: searchSliver,
      offline: offline,
      refreshFailed: catalogue.refreshFailed,
      onRetry: _refresh,
      showPlanSegment: planOn,
      segment: segment,
      onSegment: (s) => setState(() => _segment = s),
      planContent: segment == RecipesSegment.plan
          ? buildPlanSegment(context)
          : null,
      filters: filters,
      filter: filter,
      onFilter: (f) => setState(() => _filter = f),
      tip: tip,
      home: home,
      fits: fits,
      showCalories: calories,
      onOpen: _open,
      onToList: (r) {
        ref.read(tipServiceProvider).markDone(TipId.recipeToList);
        openRecipeToList(context, r);
      },
      onMenu: (anchor, r) => showRecipeCardMenu(anchor, ref, r),
      onLink: (link) => _link(link, filter, profile.hasProfile),
      onCategory: (id) => openRecipeCategory(context, id),
      onCreate: () => openRecipeEditor(context),
      onShowAll: () => openAllRecipes(context),
    );

    // A-P4: grey ground while the plan is shown, white for Entdecken,
    // cross-faded. The query (`week`, `day`) stays, the segment is local.
    final plan = segment == RecipesSegment.plan;
    final planBar = plan ? buildPlanFloatingBar(context) : null;
    final target = plan
        ? context.colors.background
        : context.colors.backgroundPlain;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: AvoMotion.fadeReduced,
      builder: (context, color, child) {
        final background = color ?? target;
        return ColoredBox(
          color: background,
          child: Stack(
            children: [
              child!,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ScrollEdgeFade(color: background),
              ),
              Positioned(
                top: GlassToolbar.topOffset(context),
                left: 0,
                right: 0,
                child: GlassToolbar(
                  trailing: plan
                      ? buildPlanToolbarActions(context)
                      : [_discoverActions(context)],
                ),
              ),
              if (planBar != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: ShellInsets.aboveTabBar(context),
                  child: planBar,
                ),
            ],
          ),
        );
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (!searching) CupertinoSliverRefreshControl(onRefresh: _refresh),
          SliverPadding(
            padding: EdgeInsets.only(
              top:
                  GlassToolbar.topOffset(context) +
                  AvoSizes.toolbarButton +
                  kRecipesTitleGap,
              bottom: ShellInsets.bottom(context),
            ),
            sliver: content,
          ),
        ],
      ),
    );
  }

  /// "Gespeichert" and "Mehr" of the Entdecken segment.
  Widget _discoverActions(BuildContext context) => GlassButtonGroup(
    items: [
      GlassGroupItem(
        icon: const AvoIcon(
          AvoIcons.bookmark,
          filled: true,
          size: _kBookmarkSize,
        ),
        semanticLabel: context.tr('recipe_browse_saved'),
        onPressed: () => context.push('${RoutePaths.recipes}/saved'),
      ),
      GlassGroupItem(
        icon: KeyedSubtree(key: _moreKey, child: const AvoIcon(AvoIcons.more)),
        semanticLabel: context.tr('common_more'),
        onPressed: _more,
      ),
    ],
  );
}
