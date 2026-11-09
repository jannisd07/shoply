import 'package:flutter/cupertino.dart';

import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_cards.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

// D2-Rezepte vertical rhythm (top of each element below the previous one).
// The search field and the chips sit in 44 pt hit areas around a smaller
// visible shape, so their gaps are reduced by that inset.
const double _kTitleToSearch = 2; // D2 6, minus the field's 4 pt inset
const double _kSearchToChips = 3; // D2 7, minus the field's 4 pt inset
const double _kChipsToHero = 7; // D2
const double _kSectionTop = AvoSpacing.xl; // D2 20
const double _kHeaderToGrid = 10; // D2
const double _kStatusGap = AvoSpacing.s;

/// Photo placeholders of the first load (Konzept 13 §3.3): the hero and two
/// rows of grid tiles as calm `fill` shapes.
const int _kSkeletonRows = 2;
const double _kSkeletonTileAspect = 4 / 3; // D2 grid photo

/// Which part of the tab shows.
enum RecipesSegment { discover, plan }

/// Where an "Alle" link of the tab leads.
enum RecipesHomeLink { popular, newest, pool }

/// The resolved sections of the tab for the selected chip.
class RecipesHomeView {
  const RecipesHomeView({
    this.hero,
    this.heroKind = RecipeHeroKind.pick,
    this.popular = const [],
    this.newest = const [],
    this.poolCount = 0,
    this.categories = const [],
  });

  final Recipe? hero;
  final RecipeHeroKind heroKind;
  final List<Recipe> popular;
  final List<Recipe> newest;
  final int poolCount;

  /// Categories to browse (only under "Für dich").
  final List<RecipeCategory> categories;
}

/// Label of a tab chip.
String quickFilterLabel(BuildContext context, RecipeQuickFilter filter) =>
    context.tr(switch (filter) {
      RecipeQuickFilter.forYou => 'recipe_browse_filter_for_you',
      RecipeQuickFilter.quick => 'recipe_browse_filter_quick',
      RecipeQuickFilter.vegetarian => 'recipe_browse_filter_vegetarian',
      RecipeQuickFilter.vegan => 'recipe_browse_filter_vegan',
      RecipeQuickFilter.glutenFree => 'recipe_browse_filter_gluten_free',
      RecipeQuickFilter.healthy => 'recipe_browse_filter_healthy',
    });

/// The scrolling content of the Rezepte tab (D2-Rezepte, Konzept 13 §3–4),
/// without the toolbar, as one sliver: large title, the segment
/// "Entdecken | Wochenplan" when the meal plan module is on, the search
/// field, the filter chips, then the hero "Passt zu deiner Liste",
/// "Beliebt diese Woche", "Neu" and "Kategorien" — or, while searching,
/// [searchSliver]. Pure: data in, callbacks out.
class RecipesBrowseContent extends StatelessWidget {
  const RecipesBrowseContent({
    super.key,
    required this.loading,
    required this.catalogueEmpty,
    required this.searchController,
    required this.searchFocus,
    required this.onQueryChanged,
    this.onQuerySubmitted,
    this.searching = false,
    this.searchSliver,
    this.offline = false,
    this.refreshFailed = false,
    this.onRetry,
    this.showPlanSegment = false,
    this.segment = RecipesSegment.discover,
    this.onSegment,
    this.planContent,
    this.filters = const [RecipeQuickFilter.forYou],
    this.filter = RecipeQuickFilter.forYou,
    required this.onFilter,
    this.tip,
    this.showDietHint = false,
    this.onDietHint,
    this.onDismissDietHint,
    this.home = const RecipesHomeView(),
    this.fits = const {},
    this.showCalories = false,
    required this.onOpen,
    required this.onToList,
    this.onMenu,
    required this.onLink,
    required this.onCategory,
    required this.onCreate,
    required this.onShowAll,
  });

  /// First load without any local recipes: placeholders.
  final bool loading;

  /// The catalogue is known and empty.
  final bool catalogueEmpty;

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String>? onQuerySubmitted;

  /// The search has focus or text: [searchSliver] replaces the sections and
  /// the large title folds away.
  final bool searching;
  final Widget? searchSliver;

  final bool offline;

  /// The last refresh failed; the local state is shown.
  final bool refreshFailed;
  final VoidCallback? onRetry;

  /// The meal plan module is on.
  final bool showPlanSegment;
  final RecipesSegment segment;
  final ValueChanged<RecipesSegment>? onSegment;

  /// Teil B's Wochenplan (`buildPlanSegment`), a sliver placed below the
  /// segment control.
  final Widget? planContent;

  final List<RecipeQuickFilter> filters;
  final RecipeQuickFilter filter;
  final ValueChanged<RecipeQuickFilter> onFilter;

  /// The tab's one-time tip (T6, T7), usually a `TipSlot` that wraps its row
  /// in an `InsetSection`; it sits below the large title and takes no space
  /// without a tip. Hidden, but kept alive, while searching, loading or on
  /// the Wochenplan, so the visit stays the same.
  final Widget? tip;

  /// The older diet hint row ("Ernährung und Allergien einstellen"); the tab
  /// shows T7 through [tip] instead.
  final bool showDietHint;
  final VoidCallback? onDietHint;
  final VoidCallback? onDismissDietHint;

  final RecipesHomeView home;
  final Map<String, RecipeFit> fits;
  final bool showCalories;

  final ValueChanged<Recipe> onOpen;

  /// "Zutaten auf die Liste" on the hero.
  final ValueChanged<Recipe> onToList;
  final RecipeMenuOpener? onMenu;
  final ValueChanged<RecipesHomeLink> onLink;
  final ValueChanged<String> onCategory;

  /// "Erstes Rezept schreiben".
  final VoidCallback onCreate;

  /// "Alle Rezepte zeigen" when nothing fits.
  final VoidCallback onShowAll;

  bool get _plan => showPlanSegment && segment == RecipesSegment.plan;

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[SliverToBoxAdapter(child: _header(context))];
    if (_plan) {
      slivers.add(planContent ?? const SliverToBoxAdapter());
    } else if (searching) {
      slivers.add(searchSliver ?? const SliverToBoxAdapter());
    } else if (loading) {
      slivers.add(const SliverToBoxAdapter(child: _BrowseSkeleton()));
    } else if (catalogueEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxxl),
            child: EmptyState(
              title: context.tr('recipe_browse_empty_title'),
              actionLabel: context.tr('recipe_browse_empty_action'),
              onAction: onCreate,
              pose: AvoPose.excited,
            ),
          ),
        ),
      );
    } else {
      slivers.addAll(_sections(context));
    }
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _header(BuildContext context) {
    final colors = context.colors;
    final children = <Widget>[
      // Folds away while searching (Konzept 13 §4.1); the field below keeps
      // its element, so focus survives.
      AnimatedSize(
        key: const ValueKey('title'),
        duration: context.reduceMotion ? Duration.zero : AvoMotion.fadeReduced,
        alignment: Alignment.topCenter,
        child: searching
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.screen,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    context.tr('common_tab_recipes'),
                    style: context.text(AvoTextStyle.largeTitle),
                  ),
                ),
              ),
      ),
    ];

    final status = _status(context);
    if (status != null) {
      children.add(
        Padding(
          key: const ValueKey('status'),
          padding: const EdgeInsets.only(top: _kStatusGap),
          child: status,
        ),
      );
    }

    final tipWidget = tip;
    if (tipWidget != null) {
      children.add(
        KeyedSubtree(
          key: const ValueKey('tip'),
          child: Offstage(
            offstage: _plan || searching || loading,
            child: tipWidget,
          ),
        ),
      );
    }

    if (showPlanSegment && !searching) {
      children.add(
        Padding(
          key: const ValueKey('segment'),
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            AvoSpacing.s,
            AvoSpacing.screen,
            0,
          ),
          child: AppSegmentedControl<RecipesSegment>(
            segments: [
              SegmentItem(
                value: RecipesSegment.discover,
                label: context.tr('recipe_browse_segment_discover'),
              ),
              SegmentItem(
                value: RecipesSegment.plan,
                label: context.tr('recipe_browse_segment_plan'),
              ),
            ],
            selected: segment,
            onChanged: (s) => onSegment?.call(s),
            semanticLabel: context.tr('recipe_browse_segment_label'),
          ),
        ),
      );
    }

    if (!_plan) {
      children.add(
        Padding(
          key: const ValueKey('search'),
          padding: EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            searching ? 0 : _kTitleToSearch,
            AvoSpacing.screen,
            0,
          ),
          child: AvoSearchField(
            controller: searchController,
            focusNode: searchFocus,
            hint: context.tr('recipe_browse_search_hint'),
            onChanged: onQueryChanged,
            onSubmitted: onQuerySubmitted,
          ),
        ),
      );
    }

    final showChips =
        !_plan &&
        !searching &&
        !loading &&
        !catalogueEmpty &&
        filters.length > 1;
    if (showChips) {
      children.add(
        Padding(
          key: const ValueKey('chips'),
          padding: const EdgeInsets.only(top: _kSearchToChips),
          child: Semantics(
            container: true,
            label: context.tr('recipe_browse_filters'),
            child: ChipRow(
              chips: [
                for (final f in filters)
                  AppFilterChip(
                    label: quickFilterLabel(context, f),
                    selected: f == filter,
                    onSelected: (_) => onFilter(f),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (showDietHint && !_plan && !searching && !loading) {
      children.add(
        Padding(
          key: const ValueKey('hint'),
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kChipsToHero,
            AvoSpacing.screen,
            0,
          ),
          child: HintRow(
            text: context.tr('recipe_browse_diet_hint'),
            leading: AvoIcon(AvoIcons.leafArrowCirclepath, color: colors.tint),
            actionLabel: context.tr('recipe_browse_diet_hint_action'),
            onTap: onDietHint,
            onDismiss: onDismissDietHint,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget? _status(BuildContext context) {
    if (offline) {
      return StatusRow(
        kind: StatusKind.offline,
        text: context.tr(
          searching ? 'recipe_browse_offline_search' : 'recipe_browse_offline',
        ),
      );
    }
    if (refreshFailed && !_plan) {
      return StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr('recipe_browse_update_failed'),
        actionLabel: onRetry == null ? null : context.tr('common_try_again'),
        onAction: onRetry,
      );
    }
    return null;
  }

  List<Widget> _sections(BuildContext context) {
    final hero = home.hero;
    if (hero == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxl),
            child: EmptyState(
              title: context.tr('recipe_browse_for_you_empty_title'),
              message: context.tr('recipe_browse_for_you_empty_message'),
              actionLabel: context.tr('recipe_browse_for_you_empty_action'),
              onAction: onShowAll,
            ),
          ),
        ),
      ];
    }

    final out = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kChipsToHero,
            AvoSpacing.screen,
            0,
          ),
          child: _hero(context, hero),
        ),
      ),
    ];

    final hasSections = home.popular.isNotEmpty || home.newest.isNotEmpty;
    if (!hasSections && home.poolCount > 1) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.s),
            child: Center(
              child: AppButton.plain(
                label: context.tr(
                  'recipe_browse_see_all_count',
                  params: {'n': '${home.poolCount}'},
                ),
                onPressed: () => onLink(RecipesHomeLink.pool),
              ),
            ),
          ),
        ),
      );
    }

    void section(String title, List<Recipe> recipes, RecipesHomeLink link) {
      if (recipes.isEmpty) return;
      out
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: _kSectionTop),
              child: AvoSectionHeader(
                title,
                actionLabel: context.tr('common_all'),
                onAction: () => onLink(link),
              ),
            ),
          ),
        )
        ..add(const SliverToBoxAdapter(child: SizedBox(height: _kHeaderToGrid)))
        ..add(
          RecipeGridSliver(
            recipes: recipes,
            fits: fits,
            showCalories: showCalories,
            onOpen: onOpen,
            onMenu: onMenu,
          ),
        );
    }

    section(
      context.tr('recipe_browse_popular'),
      home.popular,
      RecipesHomeLink.popular,
    );
    section(
      context.tr('recipe_browse_new'),
      home.newest,
      RecipesHomeLink.newest,
    );

    if (home.categories.isNotEmpty) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: _kSectionTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AvoSectionHeader(context.tr('recipe_browse_categories')),
                const SizedBox(height: AvoSpacing.xs),
                ChipRow(
                  chips: [
                    for (final c in home.categories)
                      AppFilterChip(
                        label: context.tr(c.nameKey),
                        selected: false,
                        onSelected: (_) => onCategory(c.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _hero(BuildContext context, Recipe hero) {
    final fit = fits[hero.id] ?? RecipeFit.neutral;
    final eyebrow = switch (home.heroKind) {
      RecipeHeroKind.listMatch => context.tr('recipe_browse_hero_list'),
      RecipeHeroKind.recipeOfTheWeek => context.tr('recipe_browse_hero_week'),
      RecipeHeroKind.pick => quickFilterLabel(context, filter),
    };
    final meta = recipeHeroMeta(
      context,
      hero,
      showCalories: showCalories,
      adapted: fit.adapted > 0,
    );
    final card = RecipeHeroCard(
      image: RecipeBrowsePhoto(url: hero.imageUrl, columns: 1),
      title: hero.name,
      eyebrow: eyebrow,
      meta: meta,
      actionLabel: context.tr('recipe_browse_to_list'),
      actionIcon: AvoIcons.plus,
      onAction: () => onToList(hero),
      onTap: () => onOpen(hero),
      semanticLabel: [
        recipeSemanticLabel(context, hero, showCalories: showCalories),
        eyebrow,
      ].join(', '),
    );
    final menu = onMenu;
    if (menu == null) return card;
    // The hero's action stays its own VoiceOver button, so the long press
    // is for touch only.
    return Builder(
      builder: (anchor) => GestureDetector(
        excludeFromSemantics: true,
        onLongPress: () {
          AvoHaptics.light();
          menu(anchor, hero);
        },
        child: card,
      ),
    );
  }
}

/// The first load without any local recipes: the hero and grid tiles as
/// calm tone shapes, no shimmer, no spinner (Konzept 13 §3.3). One VoiceOver
/// element, "Wird geladen".
class _BrowseSkeleton extends StatelessWidget {
  const _BrowseSkeleton();

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
    final columns = recipeGridColumns(context);
    return Semantics(
      container: true,
      label: context.tr('loading'),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kChipsToHero,
            AvoSpacing.screen,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: RecipeHeroCard.browseHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AvoRadii.group),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionTop + _kHeaderToGrid),
              for (var row = 0; row < _kSkeletonRows; row++) ...[
                if (row > 0) const SizedBox(height: AvoSpacing.xl),
                if (columns == 1)
                  tile()
                else
                  Row(
                    children: [
                      Expanded(child: tile()),
                      const SizedBox(width: AvoSpacing.m),
                      Expanded(child: tile()),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
