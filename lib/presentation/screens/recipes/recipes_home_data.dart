import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/presentation/screens/recipes/recipe_personalization.dart';

/// Pure helpers that derive every Recipes-tab section from the one recipe
/// list the tab already loads.
///
/// The tab used to fetch the full `recipes` table three times in parallel
/// (all, recent, top authors) and once more per search keystroke. Deriving
/// the sections in memory keeps it to a single fetch.

/// One recipe author with the aggregates the creator lists show.
class RecipeAuthorSummary {
  final String id;
  final String name;
  final String? avatarUrl;
  final int recipeCount;

  /// Mean of the author's rated recipes' average ratings (0 if none rated).
  final double averageRating;

  /// Popularity + quality score used to rank creators.
  final double score;

  const RecipeAuthorSummary({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.recipeCount,
    required this.averageRating,
    required this.score,
  });
}

/// For small recipe counts, show at most half of the recipes (min 1), so a
/// section never lists the whole catalogue.
int _effectiveLimit(int total, int limit) =>
    total <= limit * 2 ? (total / 2).ceil().clamp(1, limit) : limit;

/// Newest recipes first.
List<Recipe> recentRecipesFrom(List<Recipe> recipes, {int limit = 10}) {
  if (recipes.isEmpty) return const [];
  final sorted = [...recipes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(_effectiveLimit(sorted.length, limit)).toList();
}

/// Groups recipes by author and ranks authors by
/// `(recipes * 10) + (views * 0.1) + (ratings * 2) + (avgRating * 5)`.
List<RecipeAuthorSummary> topAuthorsFrom(List<Recipe> recipes, {int? limit}) {
  final byAuthor = <String, List<Recipe>>{};
  for (final recipe in recipes) {
    byAuthor.putIfAbsent(recipe.authorId, () => []).add(recipe);
  }

  final authors = byAuthor.entries.map((entry) {
    final authorRecipes = entry.value;
    final first = authorRecipes.first;
    final rated = authorRecipes.where((r) => r.ratingCount > 0).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((r) => r.averageRating).reduce((a, b) => a + b) / rated.length;
    final totalViews = authorRecipes.fold<int>(0, (sum, r) => sum + r.viewCount);
    final totalRatings = authorRecipes.fold<int>(0, (sum, r) => sum + r.ratingCount);
    return RecipeAuthorSummary(
      id: entry.key,
      name: first.authorName,
      avatarUrl: first.authorAvatarUrl,
      recipeCount: authorRecipes.length,
      averageRating: avgRating,
      score: (authorRecipes.length * 10) +
          (totalViews * 0.1) +
          (totalRatings * 2) +
          (avgRating * 5),
    );
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return limit == null ? authors : authors.take(limit).toList();
}

/// Number of distinct recipe authors.
int creatorCountFrom(List<Recipe> recipes) =>
    recipes.map((r) => r.authorId).toSet().length;

/// Recipes per browse category (label substring match, as before).
Map<String, int> categoryCountsFrom(List<Recipe> recipes) {
  return {
    for (final category in recipeCategories)
      category.id: recipes
          .where((r) => r.labels
              .any((l) => l.toLowerCase().contains(category.id.toLowerCase())))
          .length,
  };
}

/// Local full-text search over name, description, author, labels and
/// ingredients, best-rated first. Matches what `RecipeService.searchRecipes`
/// does server-side-free, without downloading the table again.
List<Recipe> searchRecipesLocally(List<Recipe> recipes, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return const [];
  final results = recipes.where((recipe) {
    return recipe.name.toLowerCase().contains(q) ||
        recipe.description.toLowerCase().contains(q) ||
        recipe.authorName.toLowerCase().contains(q) ||
        recipe.labels.any((label) => label.toLowerCase().contains(q)) ||
        recipe.ingredients.any((ing) => ing.name.toLowerCase().contains(q));
  }).toList()
    ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
  return results;
}

/// "For You" picks: diet/allergy/priority-scored when the user has a
/// profile, otherwise top-rated. [excludeIds] are already shown elsewhere.
List<Recipe> forYouRecipesFrom(
  List<Recipe> recipes, {
  required UserModel? user,
  Set<String> excludeIds = const {},
}) {
  final candidates = recipes.where((r) => !excludeIds.contains(r.id)).toList();
  if (candidates.isEmpty) return const [];
  final limit = candidates.length <= 6
      ? (candidates.length / 2).ceil().clamp(1, 3)
      : 6;

  final appPriorities = user?.appPriorities.toSet() ?? const <String>{};
  if (user != null &&
      (user.dietPreferences.isNotEmpty ||
          user.allergies.isNotEmpty ||
          appPriorities.isNotEmpty)) {
    final scored = <MapEntry<Recipe, double>>[];
    for (final recipe in candidates) {
      final score = scoreForYouRecipe(
        recipe,
        dietPreferences: user.dietPreferences,
        allergies: user.allergies,
        appPriorities: appPriorities,
      );
      if (score > 0) scored.add(MapEntry(recipe, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final picks = scored.take(limit).map((e) => e.key).toList();
    if (picks.isNotEmpty) return picks;
  }

  // No personalised matches: top rated with a little engagement weight.
  double fallbackScore(Recipe r) =>
      r.averageRating * 2 + (r.ratingCount * 0.1) + (r.viewCount * 0.01);
  final sorted = [...candidates]
    ..sort((a, b) => fallbackScore(b).compareTo(fallbackScore(a)));
  return sorted.take(limit).toList();
}
