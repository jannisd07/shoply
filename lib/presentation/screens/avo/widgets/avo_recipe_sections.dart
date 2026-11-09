import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/routes/app_destinations.dart';
import 'package:shoply/routes/route_paths.dart';

// Kap. 5.3: recipes and nutrition.
const int _maxRecipes = 3; // Kap. 5.3
const double _recipeImage = 56; // D2
const double _nutritionCellMin = 88; // D2 one value of the NutritionRow

/// "35 Min · 2 Portionen · 520 kcal" (kcal only with module calories).
String avoRecipeMeta(BuildContext context, Recipe r, {required bool kcal}) => [
  context.tr('avo_card_minutes', params: {'n': '${r.totalTimeMinutes}'}),
  avoTrCount(context, 'avo_card_servings', r.defaultServings),
  if (kcal && r.nutrition?.calories != null)
    '${avoInt(context, r.nutrition!.calories!)} kcal',
].join(' · ');

/// One recipe as a row: photo 56, name (up to 2 lines), meta; a tap opens
/// it.
class AvoRecipeRow extends ConsumerWidget {
  const AvoRecipeRow({
    super.key,
    required this.title,
    required this.meta,
    this.imageUrl,
    this.onTap,
  });

  final String title;
  final String meta;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ax = context.isAccessibilityText;
    final url = imageUrl;
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title, $meta',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Row(
              children: [
                if (!ax) ...[
                  ItemThumb(
                    size: _recipeImage,
                    radius: AvoRadii.imageSmall,
                    image: url == null || url.isEmpty
                        ? null
                        : NetworkImage(url),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: ax ? null : 2,
                        overflow: ax ? null : TextOverflow.ellipsis,
                        style: context.text(AvoTextStyle.headline),
                      ),
                      Text(
                        meta,
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: context.colors.secondaryLabel,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `search_recipes` / `get_saved_recipes` (Kap. 5.3).
class AvoRecipesSection extends ConsumerWidget {
  const AvoRecipesSection({super.key, required this.card});

  final AvoRecipesCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kcal = ref.watch(moduleEnabledProvider(AppModule.calories));
    final recipes = card.recipes.take(_maxRecipes).toList();
    final hidden = card.allergensHidden
        ? context.tr('avo_card_allergens_hidden')
        : null;
    void more() {
      if (card.saved) {
        openAppDestination(context, AppDestinations.savedRecipes);
        return;
      }
      final q = card.query;
      context.go(
        q == null
            ? RoutePaths.recipes
            : Uri(
                path: RoutePaths.recipes,
                queryParameters: {'q': q},
              ).toString(),
      );
    }

    if (recipes.isEmpty) {
      return AvoResultSection(
        title: context.tr(
          card.saved ? 'avo_card_saved_empty' : 'avo_card_recipes_empty',
        ),
        leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.forkKnife)),
        footnote: hidden,
      );
    }
    return AvoResultSection(
      title: context.tr(card.saved ? 'avo_card_saved' : 'avo_card_recipes'),
      leading: AvoSymbolTile(
        icon: AvoIcon(card.saved ? AvoIcons.bookmark : AvoIcons.forkKnife),
      ),
      detailIndent: context.isAccessibilityText
          ? AvoSpacing.l
          : AvoSpacing.l + _recipeImage + AvoSpacing.m,
      details: [
        for (final r in recipes)
          AvoRecipeRow(
            title: r.name,
            meta: avoRecipeMeta(context, r, kcal: kcal),
            imageUrl: r.imageUrl,
            onTap: () =>
                openAppDestination(context, AppDestinations.recipe(r.id)),
          ),
      ],
      footnote: hidden,
      actions: [
        AvoCardAction(
          label: context.tr('avo_card_more_recipes'),
          onPressed: more,
        ),
      ],
    );
  }
}

/// `get_recipe_nutrition`: four values per serving, "geschätzt" when Avo
/// estimated them (Kap. 5.3).
AvoResultSection avoRecipeNutritionSection(
  BuildContext context,
  AvoRecipeNutritionCard card,
) => AvoResultSection(
  title: card.recipeName,
  leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.forkKnife)),
  semanticLabel: [
    card.recipeName,
    avoNutritionSentence(
      context,
      kcal: card.kcal,
      protein: card.proteinG,
      carbs: card.carbsG,
      fat: card.fatG,
    ),
    context.tr('avo_per_serving'),
    if (card.estimated) context.tr('avo_estimated'),
  ].join(', '),
  details: [
    AvoNutritionRow(
      kcal: card.kcal,
      protein: card.proteinG,
      carbs: card.carbsG,
      fat: card.fatG,
    ),
  ],
  footnote: [
    context.tr('avo_per_serving'),
    if (card.estimated) context.tr('avo_estimated'),
  ].join(', '),
);

/// "520 kcal, 24 g Protein, 48 g Kohlenhydrate, 26 g Fett".
String avoNutritionSentence(
  BuildContext context, {
  int? kcal,
  double? protein,
  double? carbs,
  double? fat,
}) => [
  if (kcal != null) '${avoInt(context, kcal)} kcal',
  if (protein != null)
    context.tr('avo_nutr_protein', params: {'n': avoInt(context, protein)}),
  if (carbs != null)
    context.tr('avo_nutr_carbs', params: {'n': avoInt(context, carbs)}),
  if (fat != null)
    context.tr('avo_nutr_fat', params: {'n': avoInt(context, fat)}),
].join(', ');

/// Calories and the three macros side by side, two by two when narrow or
/// from AX1 (Kap. 12.2). Values tabular, labels below.
class AvoNutritionRow extends StatelessWidget {
  const AvoNutritionRow({
    super.key,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
  });

  final int? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    String grams(double? g) => g == null ? '–' : '${avoInt(context, g)} g';
    final cells = [
      (kcal == null ? '–' : avoInt(context, kcal!), 'kcal'),
      (grams(protein), context.tr('avo_nutr_protein_label')),
      (grams(carbs), context.tr('avo_nutr_carbs_label')),
      (grams(fat), context.tr('avo_nutr_fat_label')),
    ];
    Widget cell((String, String) c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.$1, style: context.text(AvoTextStyle.headline, tabular: true)),
        Text(
          c.$2,
          style: context.text(
            AvoTextStyle.footnote,
            color: colors.secondaryLabel,
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.xs,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                context.isAccessibilityText ||
                    constraints.maxWidth < 4 * _nutritionCellMin
                ? 2
                : 4;
            final rows = <Widget>[];
            for (var i = 0; i < cells.length; i += columns) {
              if (i > 0) rows.add(const SizedBox(height: AvoSpacing.s));
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = i; j < i + columns; j++)
                      Expanded(child: cell(cells[j])),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            );
          },
        ),
      ),
    );
  }
}
