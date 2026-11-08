import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart';

// Sentences of the allergy notice and the ingredient sublines (Konzept 13
// §2.3, §12.1 Nr. 4), shared by the detail and "Zutaten auf die Liste".

/// "Erdnuss", "Laktose", or the free text the person entered ("Kiwi").
String recipeAllergenName(BuildContext context, AllergyConstraint c) {
  final type = c.type;
  return type == null
      ? c.raw.trim()
      : context.tr('recipe_detail_allergen_${type.name}');
}

/// "Du hast eine Erdnussallergie eingetragen.", "Du isst glutenfrei.".
String recipeAllergyProfileSentence(BuildContext context, AllergyConstraint c) {
  final diet = c.fromDiet;
  if (diet != null) return context.tr('recipe_detail_profile_$diet');
  final type = c.type;
  return type == null
      ? context.tr(
          'recipe_detail_you_listed',
          params: {'allergy': c.raw.trim()},
        )
      : context.tr('recipe_detail_profile_${type.name}');
}

/// "vegan", "vegetarisch", "pescetarisch".
String recipeDietName(BuildContext context, RecipeDiet diet) =>
    context.tr('recipe_detail_diet_${diet.name}');

/// "statt Feta · wegen Laktose" / "statt Speck · weil du vegetarisch isst".
String? recipeInsteadText(BuildContext context, AdaptedIngredient i) {
  if (!i.isAdapted) return null;
  if (i.allergens.isNotEmpty) {
    return context.tr(
      'recipe_detail_instead_allergen',
      params: {
        'name': i.original.name,
        'reason': recipeAllergenName(context, i.allergens.first),
      },
    );
  }
  return context.tr(
    'recipe_detail_instead_diet',
    params: {
      'name': i.original.name,
      'diet': recipeDietName(context, i.diets.first),
    },
  );
}

/// What a line of the notice is about; picks its symbol.
enum RecipeNoticeKind {
  /// An allergen of the person (with or without substitute).
  allergen,

  /// Replaced because of a diet (no allergen).
  adapted,

  /// Breaks a diet and nothing replaces it.
  diet,

  /// Could not be checked for allergens.
  unchecked,
}

/// One sentence of the allergy notice.
class RecipeNoticeLine {
  const RecipeNoticeLine(this.kind, this.text);

  final RecipeNoticeKind kind;
  final String text;
}

String _names(Iterable<AdaptedIngredient> list) =>
    list.map((i) => i.original.name.trim()).toSet().join(', ');

/// The notice in the order of Konzept 13 §12.1 Nr. 4: allergens without a
/// substitute, allergens with one, adaptations for a diet, diet conflicts,
/// unchecked ingredients. Empty when there is nothing to say.
List<RecipeNoticeLine> recipeNoticeLines(
  BuildContext context,
  RecipeAdaptation adaptation,
) {
  final unsafe = <RecipeNoticeLine>[];
  final substituted = <RecipeNoticeLine>[];
  for (final c in adaptation.profile.allergies) {
    final hits = [
      for (final i in adaptation.ingredients)
        if (i.allergens.contains(c)) i,
    ];
    if (hits.isEmpty) continue;
    final name = recipeAllergenName(context, c);
    final profile = recipeAllergyProfileSentence(context, c);
    final missing = hits.where((i) => !i.isAdapted);
    final replaced = hits.where((i) => i.isAdapted);
    if (missing.isNotEmpty) {
      final contains = context.tr(
        'recipe_detail_contains',
        params: {'allergen': name, 'ingredients': _names(missing)},
      );
      final none = context.tr(
        'recipe_detail_no_safe_substitute',
        params: {'allergen': name},
      );
      unsafe.add(
        RecipeNoticeLine(RecipeNoticeKind.allergen, '$contains $profile $none'),
      );
    }
    if (replaced.isNotEmpty) {
      final contains = context.tr(
        'recipe_detail_contains',
        params: {'allergen': name, 'ingredients': _names(replaced)},
      );
      final suggested = context.tr('recipe_detail_substitute_suggested');
      substituted.add(
        RecipeNoticeLine(
          RecipeNoticeKind.allergen,
          '$contains $profile $suggested',
        ),
      );
    }
  }

  final diets = <RecipeNoticeLine>[];
  for (final d in adaptation.profile.diets) {
    final hits = [
      for (final i in adaptation.ingredients)
        if (i.allergens.isEmpty && i.diets.contains(d)) i,
    ];
    if (hits.isEmpty) continue;
    final diet = recipeDietName(context, d);
    final replaced = hits.where((i) => i.isAdapted).length;
    if (replaced > 0) {
      diets.add(
        RecipeNoticeLine(
          RecipeNoticeKind.adapted,
          replaced == 1
              ? context.tr(
                  'recipe_detail_adapted_diet_one',
                  params: {'diet': diet},
                )
              : context.tr(
                  'recipe_detail_adapted_diet_many',
                  params: {'count': '$replaced', 'diet': diet},
                ),
        ),
      );
    }
    final missing = hits.where((i) => !i.isAdapted);
    if (missing.isNotEmpty) {
      diets.add(
        RecipeNoticeLine(
          RecipeNoticeKind.diet,
          context.tr(
            'recipe_detail_diet_conflict',
            params: {'diet': diet, 'ingredients': _names(missing)},
          ),
        ),
      );
    }
  }

  final unchecked = adaptation.unchecked;
  return [
    ...unsafe,
    ...substituted,
    ...diets,
    if (unchecked.isNotEmpty)
      RecipeNoticeLine(
        RecipeNoticeKind.unchecked,
        unchecked.length == 1
            ? context.tr(
                'recipe_detail_unchecked_one',
                params: {'ingredients': _names(unchecked)},
              )
            : context.tr(
                'recipe_detail_unchecked_many',
                params: {
                  'count': '${unchecked.length}',
                  'ingredients': _names(unchecked),
                },
              ),
      ),
  ];
}
