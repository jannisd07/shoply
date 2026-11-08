import 'package:flutter/cupertino.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';

// D2-Rezepte grid: two columns 12 apart, rows 20 apart.
const double _kGridColumnGap = AvoSpacing.m; // D2
const double _kGridRowGap = AvoSpacing.xl; // D2

/// Separator of meta lines ("25 Min · ★ 4,8").
const String _kDot = ' · ';

/// Opens a recipe's menu (long press): anchor and recipe.
typedef RecipeMenuOpener = void Function(BuildContext anchor, Recipe recipe);

// ------------------------------------------------------------------ texts

/// "35 Min", from 60 on "1 Std. 10 Min" (Konzept 13 §2.2); null without a
/// time.
String? recipeTimeText(BuildContext context, int minutes) {
  if (minutes <= 0) return null;
  if (minutes < 60) {
    return context.tr('recipe_browse_minutes', params: {'n': '$minutes'});
  }
  final h = '${minutes ~/ 60}';
  final m = minutes % 60;
  if (m == 0) return context.tr('recipe_browse_hours', params: {'h': h});
  return context.tr('recipe_browse_hours_minutes', params: {'h': h, 'm': '$m'});
}

/// "4,7" in the app language.
String recipeRatingText(BuildContext context, double rating) => NumberFormat(
  '0.0',
  Localizations.maybeLocaleOf(context)?.toLanguageTag(),
).format(rating);

String? _kcal(BuildContext context, Recipe recipe, bool showCalories) {
  final kcal = recipe.nutrition?.calories;
  if (!showCalories || kcal == null || kcal <= 0) return null;
  return context.tr('recipe_browse_kcal', params: {'n': '$kcal'});
}

/// Meta line of a grid card: "35 Min · ★ 4,6", kcal with the calories
/// module.
String? recipeCardMeta(
  BuildContext context,
  Recipe recipe, {
  bool showCalories = false,
}) {
  final parts = [
    ?recipeTimeText(context, recipe.totalTimeMinutes),
    if (recipe.ratingCount > 0)
      '★ ${recipeRatingText(context, recipe.averageRating)}',
    ?_kcal(context, recipe, showCalories),
  ];
  return parts.isEmpty ? null : parts.join(_kDot);
}

/// Meta line of the hero: "25 Min · ★ 4,8 (126) · vegetarisch".
String? recipeHeroMeta(
  BuildContext context,
  Recipe recipe, {
  bool showCalories = false,
  bool adapted = false,
}) {
  final String? diet;
  if (hasRecipeLabel(recipe, 'vegan')) {
    diet = context.tr('recipe_browse_meta_vegan');
  } else if (hasRecipeLabel(recipe, 'vegetarian')) {
    diet = context.tr('recipe_browse_meta_vegetarian');
  } else {
    diet = null;
  }
  final parts = [
    ?recipeTimeText(context, recipe.totalTimeMinutes),
    if (recipe.ratingCount > 0)
      '★ ${recipeRatingText(context, recipe.averageRating)} '
          '(${recipe.ratingCount})',
    ?diet,
    ?_kcal(context, recipe, showCalories),
    if (adapted) context.tr('recipe_browse_adapted'),
  ];
  return parts.isEmpty ? null : parts.join(_kDot);
}

/// What VoiceOver reads for a card: "Avocado-Pasta, 15 Minuten, Bewertung
/// 4,5 von 5".
String recipeSemanticLabel(
  BuildContext context,
  Recipe recipe, {
  bool showCalories = false,
}) {
  final minutes = recipe.totalTimeMinutes;
  return [
    recipe.name,
    if (minutes > 0)
      context.tr('recipe_browse_sem_minutes', params: {'n': '$minutes'}),
    if (recipe.ratingCount > 0)
      context.tr(
        'recipe_browse_sem_rating',
        params: {'r': recipeRatingText(context, recipe.averageRating)},
      ),
    ?_kcal(context, recipe, showCalories),
  ].join(', ');
}

/// "Erdnüsse, Milch": the person's allergens in the app language (free-text
/// allergies as stored).
String allergenNames(BuildContext context, List<AllergenMatch> matches) => [
  for (final m in matches)
    if (m.type case final type?)
      context.tr('recipe_browse_allergen_${type.name}')
    else
      m.allergy,
].join(', ');

// ------------------------------------------------------------------ photo

/// The photo of a recipe card, filling its box. Without a URL (or when it
/// fails) the box keeps its `fill` placeholder; the photo fades in over it
/// (Reduce Motion: shorter, no movement anyway).
class RecipeBrowsePhoto extends StatelessWidget {
  const RecipeBrowsePhoto({super.key, required this.url, this.columns = 2});

  final String url;

  /// Columns of the grid, to decode the image at its shown size.
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.expand();
    final width =
        MediaQuery.sizeOf(context).width /
        columns *
        MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: width.round(),
      fadeInDuration: context.reduceMotion
          ? Duration.zero
          : AvoMotion.fadeReduced,
      placeholder: (_, _) => const SizedBox.expand(),
      errorWidget: (_, _, _) => const SizedBox.expand(),
    );
  }
}

// ------------------------------------------------------------------ badge

/// The line below a card's meta (Konzept 13 §2.3): an allergen of the person
/// without a safe substitute as a warning (never left out), else "Für dich
/// angepasst"; nothing when the recipe simply fits.
class RecipeFitBadge extends StatelessWidget {
  const RecipeFitBadge({super.key, required this.fit});

  final RecipeFit fit;

  /// Whether [fit] shows anything.
  static bool shows(RecipeFit fit) => fit.hasWarning || fit.adapted > 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = context.typography.sizeOf(AvoTextStyle.footnote);
    final warning = fit.hasWarning;
    final text = warning
        ? context.tr(
            'recipe_browse_contains',
            params: {'allergens': allergenNames(context, fit.unsafeAllergens)},
          )
        : fit.adapted > 0
        ? context.tr('recipe_browse_adapted')
        : null;
    if (text == null) return const SizedBox.shrink();
    final color = warning ? colors.destructive : colors.secondaryLabel;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ExcludeSemantics(
              child: Icon(
                warning
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.leaf_arrow_circlepath,
                size: size,
                color: color,
              ),
            ),
          ),
          TextSpan(text: ' $text'),
        ],
      ),
      style: context.text(
        AvoTextStyle.footnote,
        color: color,
        weight: warning ? FontWeight.w600 : null,
      ),
    );
  }
}

// ------------------------------------------------------------------- card

/// One recipe as a D2 grid tile ([RecipeCard] grid) with its photo, meta
/// line and fit line. Tap opens it, a long press opens its menu.
class RecipeBrowseCard extends StatelessWidget {
  const RecipeBrowseCard({
    super.key,
    required this.recipe,
    this.fit = RecipeFit.neutral,
    this.showCalories = false,
    this.columns = 2,
    required this.onOpen,
    this.onMenu,
  });

  final Recipe recipe;
  final RecipeFit fit;
  final bool showCalories;
  final int columns;
  final ValueChanged<Recipe> onOpen;
  final RecipeMenuOpener? onMenu;

  @override
  Widget build(BuildContext context) {
    final menu = onMenu;
    final card = RecipeCard(
      image: RecipeBrowsePhoto(url: recipe.imageUrl, columns: columns),
      title: recipe.name,
      meta: recipeCardMeta(context, recipe, showCalories: showCalories),
      badge: RecipeFitBadge.shows(fit) ? RecipeFitBadge(fit: fit) : null,
      semanticLabel: recipeSemanticLabel(
        context,
        recipe,
        showCalories: showCalories,
      ),
      onTap: () => onOpen(recipe),
    );
    if (menu == null) return card;
    // One VoiceOver element: the card's label, tap opens, long press
    // ("Aktionen") opens the menu.
    return Builder(
      builder: (anchor) => MergeSemantics(
        child: GestureDetector(
          onLongPress: () {
            AvoHaptics.light();
            menu(anchor, recipe);
          },
          child: card,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- grid

/// Columns of a recipe grid: two, one from AX1 on (Konzept 13 §2.7).
int recipeGridColumns(BuildContext context) =>
    context.isAccessibilityText ? 1 : 2;

/// The D2-Rezepte grid as a sliver: rows of two [RecipeBrowseCard]s, 12 pt
/// apart, 20 pt between rows; each row is as tall as its tallest card (no
/// fixed aspect ratio, nothing clipped). One column from AX1 on. Built
/// lazily, so long lists stay cheap.
class RecipeGridSliver extends StatelessWidget {
  const RecipeGridSliver({
    super.key,
    required this.recipes,
    this.fits = const {},
    this.showCalories = false,
    required this.onOpen,
    this.onMenu,
  });

  final List<Recipe> recipes;
  final Map<String, RecipeFit> fits;
  final bool showCalories;
  final ValueChanged<Recipe> onOpen;
  final RecipeMenuOpener? onMenu;

  @override
  Widget build(BuildContext context) {
    final columns = recipeGridColumns(context);
    final rows = (recipes.length + columns - 1) ~/ columns;
    Widget cell(int index) => index < recipes.length
        ? RecipeBrowseCard(
            recipe: recipes[index],
            fit: fits[recipes[index].id] ?? RecipeFit.neutral,
            showCalories: showCalories,
            columns: columns,
            onOpen: onOpen,
            onMenu: onMenu,
          )
        : const SizedBox.shrink();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      sliver: SliverList.builder(
        itemCount: rows,
        itemBuilder: (context, row) {
          final first = row * columns;
          return Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : _kGridRowGap),
            child: columns == 1
                ? cell(first)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cell(first)),
                      const SizedBox(width: _kGridColumnGap),
                      Expanded(child: cell(first + 1)),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
