import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_cards.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Space between the toolbar row and the large title (D2-Rezepte: toolbar
/// ends at 98, the title starts at 106).
const double kRecipesTitleGap = 8; // D2

const double _kMetaToChips = AvoSpacing.xs;
const double _kChipsToGrid = AvoSpacing.m;
const double _kSkeletonTileAspect = 4 / 3; // D2 grid photo

/// Category label ids and the translation keys of their names, including
/// the diet ids the search links here (`gluten-free`, `low-carb`).
const Map<String, String> _kCategoryNameKeys = {
  'italian': 'category_italian',
  'asian': 'category_asian',
  'vegetarian': 'category_vegetarian',
  'vegan': 'category_vegan',
  'snack': 'category_desserts',
  'breakfast': 'category_breakfast',
  'quick': 'category_quick',
  'healthy': 'category_healthy',
  'comfort-food': 'category_comfort',
  'mexican': 'category_mexican',
  'mediterranean': 'category_mediterranean',
  'seafood': 'category_seafood',
  'soup': 'category_soup',
  'gluten-free': 'recipe_browse_filter_gluten_free',
  'low-carb': 'recipe_browse_filter_low_carb',
};

/// Title of a category page: the category's name, "Rezepte mit Feta" for an
/// ingredient, else the id in title case.
String recipeCategoryTitle(BuildContext context, String categoryId) {
  final ingredient = ingredientOfCategory(categoryId);
  if (ingredient != null) {
    return context.tr(
      'recipe_browse_with_ingredient',
      params: {'name': ingredient},
    );
  }
  final key = _kCategoryNameKeys[categoryId];
  if (key != null) {
    final name = context.tr(key);
    if (name != key) return name;
  }
  return categoryId
      .replaceAll(RegExp(r'[_-]'), ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Label of a list filter chip.
String listFilterLabel(BuildContext context, RecipeListFilter filter) =>
    context.tr(switch (filter) {
      RecipeListFilter.fitsMe => 'recipe_browse_filter_fits_me',
      RecipeListFilter.under20 => 'recipe_browse_filter_under_20',
      RecipeListFilter.upTo30 => 'recipe_browse_filter_up_to_30',
      RecipeListFilter.easy => 'recipe_browse_filter_easy',
      RecipeListFilter.medium => 'recipe_browse_filter_medium',
      RecipeListFilter.advanced => 'recipe_browse_filter_advanced',
      RecipeListFilter.vegetarian => 'recipe_browse_filter_vegetarian',
      RecipeListFilter.vegan => 'recipe_browse_filter_vegan',
      RecipeListFilter.glutenFree => 'recipe_browse_filter_gluten_free',
      RecipeListFilter.healthy => 'recipe_browse_filter_healthy',
    });

/// Label of a sort option.
String recipeSortLabel(BuildContext context, RecipeSort sort) =>
    context.tr(switch (sort) {
      RecipeSort.popular => 'recipe_browse_sort_popular',
      RecipeSort.newest => 'recipe_browse_sort_newest',
      RecipeSort.fastest => 'recipe_browse_sort_fastest',
      RecipeSort.rating => 'recipe_browse_sort_rating',
    });

/// "38 Rezepte", with filters "17 von 38 Rezepten".
String recipeCountLine(BuildContext context, int shown, int total) {
  if (shown != total) {
    return context.tr(
      'recipe_browse_count_filtered',
      params: {'n': '$shown', 'total': '$total'},
    );
  }
  return context.tr(
    total == 1 ? 'recipe_browse_count_one' : 'recipe_browse_count',
    params: {'n': '$total'},
  );
}

/// The scrolling content of a category, "Alle Rezepte" or "Beliebt" page
/// (Konzept 13 §5–6, in the style of D2-Rezepte) as one sliver: large title,
/// meta line, status, filter chips with "Zurücksetzen", then the grid or a
/// state. Pure: data in, callbacks out.
class RecipesBrowsePageContent extends StatelessWidget {
  const RecipesBrowsePageContent({
    super.key,
    required this.title,
    this.subtitle,
    required this.loading,
    required this.total,
    required this.recipes,
    this.filters = const [],
    this.active = const {},
    this.onToggle,
    this.onReset,
    this.offline = false,
    this.refreshFailed = false,
    this.onRetry,
    this.fits = const {},
    this.showCalories = false,
    required this.onOpen,
    this.onMenu,
    this.emptyTitle,
    this.emptyMessage,
    this.onCreate,
  });

  final String title;

  /// Meta line instead of the count ("Nach Bewertungen").
  final String? subtitle;

  /// First load without any local recipes.
  final bool loading;

  /// Recipes of the page before filters.
  final int total;

  /// The recipes to show, filtered and sorted.
  final List<Recipe> recipes;

  final List<RecipeListFilter> filters;
  final Set<RecipeListFilter> active;
  final ValueChanged<RecipeListFilter>? onToggle;
  final VoidCallback? onReset;

  final bool offline;
  final bool refreshFailed;
  final VoidCallback? onRetry;

  final Map<String, RecipeFit> fits;
  final bool showCalories;
  final ValueChanged<Recipe> onOpen;
  final RecipeMenuOpener? onMenu;

  /// The page has no recipes at all.
  final String? emptyTitle;
  final String? emptyMessage;

  /// "Rezept schreiben" in the empty state.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[SliverToBoxAdapter(child: _header(context))];
    if (loading) {
      slivers.add(const SliverToBoxAdapter(child: _GridSkeleton()));
    } else if (total == 0) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxl),
            child: EmptyState(
              title: emptyTitle ?? context.tr('recipe_browse_empty_title'),
              message: emptyMessage,
              actionLabel: onCreate == null
                  ? null
                  : context.tr('recipe_browse_write_recipe'),
              onAction: onCreate,
            ),
          ),
        ),
      );
    } else if (recipes.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.xxl,
              AvoSpacing.screen,
              0,
            ),
            child: Column(
              children: [
                Text(
                  context.tr('recipe_browse_filter_empty'),
                  textAlign: TextAlign.center,
                  style: context.text(
                    AvoTextStyle.body,
                    color: context.colors.secondaryLabel,
                  ),
                ),
                if (onReset != null)
                  AppButton.plain(
                    label: context.tr('recipe_browse_filter_reset'),
                    onPressed: onReset,
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        RecipeGridSliver(
          recipes: recipes,
          fits: fits,
          showCalories: showCalories,
          onOpen: onOpen,
          onMenu: onMenu,
        ),
      );
    }
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _header(BuildContext context) {
    final colors = context.colors;
    final meta = loading
        ? null
        : subtitle ??
              (total > 0
                  ? recipeCountLine(context, recipes.length, total)
                  : null);
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: Semantics(
          header: true,
          child: Text(title, style: context.text(AvoTextStyle.largeTitle)),
        ),
      ),
      if (meta != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Semantics(
            liveRegion: true,
            child: Text(
              meta,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
                tabular: true,
              ),
            ),
          ),
        ),
    ];

    final status = offline
        ? StatusRow(
            kind: StatusKind.offline,
            text: context.tr('recipe_browse_offline'),
          )
        : refreshFailed
        ? StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('recipe_browse_update_failed'),
            actionLabel: onRetry == null
                ? null
                : context.tr('common_try_again'),
            onAction: onRetry,
          )
        : null;
    if (status != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: status,
        ),
      );
    }

    final toggle = onToggle;
    if (!loading && total > 0 && filters.isNotEmpty && toggle != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: _kMetaToChips),
          child: Semantics(
            container: true,
            label: context.tr('recipe_browse_filters'),
            child: ChipRow(
              chips: [
                for (final f in filters)
                  AppFilterChip(
                    label: listFilterLabel(context, f),
                    selected: active.contains(f),
                    onSelected: (_) => toggle(f),
                  ),
                if (active.isNotEmpty && onReset != null)
                  AppButton.plain(
                    label: context.tr('common_reset'),
                    onPressed: onReset,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    children.add(const SizedBox(height: _kChipsToGrid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Grid placeholders for the very first load: calm `fill` tiles.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.fill;
    Widget tile() => AspectRatio(
      aspectRatio: _kSkeletonTileAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AvoRadii.card),
        ),
      ),
    );
    final row = recipeGridColumns(context) == 1
        ? tile()
        : Row(
            children: [
              Expanded(child: tile()),
              const SizedBox(width: AvoSpacing.m),
              Expanded(child: tile()),
            ],
          );
    return Semantics(
      container: true,
      label: context.tr('loading'),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Column(
            children: [
              row,
              const SizedBox(height: AvoSpacing.xl),
              row,
            ],
          ),
        ),
      ),
    );
  }
}

/// A pushed recipes page (category, "Alle", "Beliebt"): the plain D2
/// background, the scrolling [content] under the glass toolbar with back
/// and, when [sort] is set, the sort menu (Konzept 13 §5.1).
class RecipesBrowsePage extends StatelessWidget {
  const RecipesBrowsePage({
    super.key,
    required this.content,
    required this.onBack,
    this.sort,
    this.onSort,
    this.onRefresh,
  });

  /// One sliver, usually a [RecipesBrowsePageContent].
  final Widget content;
  final VoidCallback onBack;

  /// The current order; null hides the sort button.
  final RecipeSort? sort;
  final ValueChanged<RecipeSort>? onSort;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final background = context.colors.backgroundPlain;
    final refresh = onRefresh;
    final current = sort;
    return ColoredBox(
      color: background,
      child: Stack(
        children: [
          CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (refresh != null)
                CupertinoSliverRefreshControl(onRefresh: refresh),
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
              leading: GlassIconButton(
                icon: const AvoIcon(AvoIcons.chevronBack),
                semanticLabel: context.tr('back'),
                onPressed: onBack,
              ),
              trailing: [
                if (current != null && onSort != null)
                  Builder(
                    builder: (anchor) => GlassIconButton(
                      icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
                      semanticLabel:
                          '${context.tr('recipe_browse_sort')}, '
                          '${recipeSortLabel(context, current)}',
                      onPressed: () => showAvoMenu(
                        anchor,
                        semanticLabel: context.tr('recipe_browse_sort'),
                        items: [
                          for (final s in RecipeSort.values)
                            AvoMenuItem(
                              label: recipeSortLabel(context, s),
                              checked: s == current,
                              onSelected: () => onSort?.call(s),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
