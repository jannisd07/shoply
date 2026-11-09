import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_cards.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

const double _kSectionTop = AvoSpacing.xl; // D2 section margin 20
const double _kHeaderGap = 10; // D2 header to content

/// A fallback ingredient for "Versuch es mit einer Zutat" when the query is
/// a single word.
const String _kExampleIngredient = 'Feta';

/// Display name of a diet label of the search chips.
String recipeDietLabelName(BuildContext context, String label) =>
    context.tr(switch (label) {
      'vegetarian' => 'recipe_browse_filter_vegetarian',
      'vegan' => 'recipe_browse_filter_vegan',
      'gluten-free' => 'recipe_browse_filter_gluten_free',
      'low-carb' => 'recipe_browse_filter_low_carb',
      'healthy' => 'recipe_browse_filter_healthy',
      _ => label,
    });

/// The search state of the Rezepte tab (Konzept 13 §4) as one sliver.
///
/// Before the first letter: "Zuletzt gesucht" and the diet chips. With text:
/// "Rezepte" (the D2 grid, local hits at once), "Mit Zutat", "Kategorien",
/// "Ernährung" and "Ersteller"; empty sections are left out. Pure: data in,
/// callbacks out.
class RecipesBrowseSearch extends StatelessWidget {
  const RecipesBrowseSearch({
    super.key,
    required this.query,
    this.results = const RecipeSearchResults(),
    this.recent = const [],
    this.hasProfile = false,
    this.fits = const {},
    this.showCalories = false,
    required this.onOpen,
    this.onMenu,
    required this.onRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onDiet,
    required this.onFitsMe,
    required this.onCategory,
    required this.onIngredient,
    required this.onAuthor,
    required this.onAllCreators,
    required this.onCreate,
  });

  final String query;
  final RecipeSearchResults results;
  final List<String> recent;

  /// The person has a diet profile: the chip "Passt zu mir" shows.
  final bool hasProfile;
  final Map<String, RecipeFit> fits;
  final bool showCalories;

  final ValueChanged<Recipe> onOpen;
  final RecipeMenuOpener? onMenu;
  final ValueChanged<String> onRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;

  /// A diet chip (label id); "Passt zu mir" calls [onFitsMe].
  final ValueChanged<String> onDiet;
  final VoidCallback onFitsMe;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onIngredient;
  final ValueChanged<RecipeAuthorSummary> onAuthor;
  final VoidCallback onAllCreators;

  /// "Eigenes Rezept schreiben" (with the query as its name).
  final ValueChanged<String> onCreate;

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    final slivers = q.isEmpty ? _start(context) : _results(context, q);
    return SliverMainAxisGroup(slivers: slivers);
  }

  // ------------------------------------------------ before the first letter

  List<Widget> _start(BuildContext context) {
    final out = <Widget>[];
    if (recent.isNotEmpty) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: _kSectionTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InsetSection(
                  header: context.tr('recipe_browse_recent'),
                  separatorIndent:
                      AvoSpacing.l + _iconBox(context) + AvoSpacing.m,
                  children: [
                    for (final r in recent)
                      Dismissible(
                        key: ValueKey('recent-$r'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => onRemoveRecent(r),
                        child: NavRow(
                          title: r,
                          leading: const _RowIcon(AvoIcons.clock),
                          onTap: () => onRecent(r),
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AvoSpacing.s,
                    ),
                    child: AppButton.plain(
                      label: context.tr('recipe_browse_clear_recent'),
                      onPressed: onClearRecent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    out.add(
      SliverToBoxAdapter(
        child: _chipSection(context, context.tr('recipe_browse_diet_section'), [
          if (hasProfile)
            AppFilterChip(
              label: context.tr('recipe_browse_filter_fits_me'),
              selected: false,
              onSelected: (_) => onFitsMe(),
            ),
          for (final d in kRecipeDietLabels)
            AppFilterChip(
              label: recipeDietLabelName(context, d),
              selected: false,
              onSelected: (_) => onDiet(d),
            ),
        ]),
      ),
    );
    return out;
  }

  // ------------------------------------------------------------ with text

  List<Widget> _results(BuildContext context, String q) {
    final r = results;
    if (r.isEmpty) {
      final words = q.split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty);
      final example = words.length > 1 ? words.first : _kExampleIngredient;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xxl),
            child: EmptyState(
              title: context.tr(
                'recipe_browse_no_results_title',
                params: {'q': q},
              ),
              message: context.tr(
                'recipe_browse_no_results_message',
                params: {'example': example},
              ),
              actionLabel: context.tr('recipe_browse_no_results_action'),
              onAction: () => onCreate(q),
              pose: AvoPose.thinking,
            ),
          ),
        ),
      ];
    }

    final out = <Widget>[];
    if (r.recipes.isNotEmpty) {
      out
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: _kSectionTop,
                bottom: _kHeaderGap,
              ),
              child: AvoSectionHeader(context.tr('recipe_browse_results')),
            ),
          ),
        )
        ..add(
          RecipeGridSliver(
            recipes: r.recipes,
            fits: fits,
            showCalories: showCalories,
            onOpen: onOpen,
            onMenu: onMenu,
          ),
        );
    }

    final ingredient = r.ingredient;
    if (ingredient != null) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: _kSectionTop),
            child: InsetSection(
              header: context.tr('recipe_browse_with_ingredient_section'),
              children: [
                NavRow(
                  title: context.tr(
                    'recipe_browse_with_ingredient',
                    params: {'name': ingredient},
                  ),
                  value: '${r.ingredientCount}',
                  onTap: () => onIngredient(ingredient),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (r.categories.isNotEmpty) {
      out.add(
        SliverToBoxAdapter(
          child: _chipSection(context, context.tr('recipe_browse_categories'), [
            for (final c in r.categories)
              AppFilterChip(
                label: context.tr(c.nameKey),
                selected: false,
                onSelected: (_) => onCategory(c.id),
              ),
          ]),
        ),
      );
    }

    if (r.dietLabels.isNotEmpty) {
      out.add(
        SliverToBoxAdapter(
          child:
              _chipSection(context, context.tr('recipe_browse_diet_section'), [
                for (final d in r.dietLabels)
                  AppFilterChip(
                    label: recipeDietLabelName(context, d),
                    selected: false,
                    onSelected: (_) => onDiet(d),
                  ),
              ]),
        ),
      );
    }

    if (r.authors.isNotEmpty) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: _kSectionTop),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InsetSection(
                  header: context.tr('recipe_browse_creators'),
                  separatorIndent:
                      AvoSpacing.l + AvatarSize.large.dimension + AvoSpacing.m,
                  children: [
                    for (final a in r.authors)
                      NavRow(
                        title: a.name,
                        subtitle: context.tr(
                          a.recipeCount == 1
                              ? 'recipe_browse_count_one'
                              : 'recipe_browse_count',
                          params: {'n': '${a.recipeCount}'},
                        ),
                        leading: Avatar(name: a.name, size: AvatarSize.large),
                        onTap: () => onAuthor(a),
                      ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AvoSpacing.s,
                    ),
                    child: AppButton.plain(
                      label: context.tr('recipe_browse_all_creators'),
                      onPressed: onAllCreators,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _chipSection(BuildContext context, String title, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(top: _kSectionTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvoSectionHeader(title),
          const SizedBox(height: AvoSpacing.xs),
          ChipRow(chips: chips),
        ],
      ),
    );
  }
}

/// Side of the leading symbol of a search row; grows with Dynamic Type.
double _iconBox(BuildContext context) =>
    context.typography.sizeOf(AvoTextStyle.body);

/// A plain symbol before a row title ("Zuletzt gesucht").
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final AvoIconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AvoIcon(
      icon,
      size: _iconBox(context),
      color: context.colors.secondaryLabel,
    ),
  );
}
