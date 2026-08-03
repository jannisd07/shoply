import 'package:shoply/data/models/recipe.dart';

/// Pure scoring function behind the Recipes screen's "For You" section.
///
/// Combines the pre-existing diet-preference/allergy/engagement/freshness
/// signals with two honest, direct extensions of Feature 7's
/// `users.app_priorities` ("what brings you to Shoply?", see
/// `kAppPriorities`) onto recipe content specifically:
/// - `eat_healthier` boosts recipes carrying the existing `healthy` browse
///   category label (`recipeCategories` in `recipe_categories.dart`).
/// - `discover_recipes` doubles the freshness bonus, favoring recently
///   added recipes over already-popular ones for a user who said they want
///   to discover new things.
///
/// `save_money`, `share_lists`, and `stay_organized` are deliberately left
/// unmapped here, same precedent `orderedHomeNudgeCards` set for priorities
/// with no honest, direct effect on *what a good recipe looks like* — they
/// aren't about recipe content, so faking a mapping for them would be
/// exactly the "fake working integration" the product brief warns against.
double scoreForYouRecipe(
  Recipe recipe, {
  required List<String> dietPreferences,
  required List<String> allergies,
  Set<String> appPriorities = const {},
  DateTime? now,
}) {
  double score = 0;

  for (final pref in dietPreferences) {
    if (recipe.labels.any((l) => l.toLowerCase().contains(pref.toLowerCase()))) {
      score += 2.0;
    }
  }

  for (final allergy in allergies) {
    if (recipe.ingredients.any(
      (ing) => ing.name.toLowerCase().contains(allergy.toLowerCase()),
    )) {
      score -= 5.0; // Heavy penalty for allergens
    }
  }

  // Boost by rating (0-5 stars → 0-2.5 points)
  score += recipe.averageRating * 0.5;

  // Boost by view count (capped so viral recipes don't dominate)
  if (recipe.viewCount > 0) {
    score += (recipe.viewCount.toDouble()).clamp(0, 100) * 0.01;
  }

  // Boost by rating count (social proof)
  score += (recipe.ratingCount * 0.2).clamp(0, 2);

  if (appPriorities.contains('eat_healthier') &&
      recipe.labels.any((l) => l.toLowerCase().contains('healthy'))) {
    score += 1.5;
  }

  // Freshness boost (recipes from the last 7/30 days get a bonus),
  // doubled for a user who said they want to discover new recipes.
  final age = (now ?? DateTime.now()).difference(recipe.createdAt).inDays;
  final discoveryMultiplier = appPriorities.contains('discover_recipes') ? 2.0 : 1.0;
  if (age <= 7) {
    score += 1.0 * discoveryMultiplier;
  } else if (age <= 30) {
    score += 0.5 * discoveryMultiplier;
  }

  return score;
}
