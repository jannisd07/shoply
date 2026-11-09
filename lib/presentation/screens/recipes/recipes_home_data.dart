import 'package:shoply/core/constants/recipe_categories.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/ingredient_substitution_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart';

/// Pure helpers behind the Rezepte tab, the search and the category and
/// "Alle" pages (Konzept 13 §2–6): every section is derived in memory from
/// the one local recipe catalogue, so nothing waits for the network.

// ------------------------------------------------------------------ authors

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
        : rated.map((r) => r.averageRating).reduce((a, b) => a + b) /
              rated.length;
    final totalViews = authorRecipes.fold<int>(
      0,
      (sum, r) => sum + r.viewCount,
    );
    final totalRatings = authorRecipes.fold<int>(
      0,
      (sum, r) => sum + r.ratingCount,
    );
    return RecipeAuthorSummary(
      id: entry.key,
      name: first.authorName,
      avatarUrl: first.authorAvatarUrl,
      recipeCount: authorRecipes.length,
      averageRating: avgRating,
      score:
          (authorRecipes.length * 10) +
          (totalViews * 0.1) +
          (totalRatings * 2) +
          (avgRating * 5),
    );
  }).toList()..sort((a, b) => b.score.compareTo(a.score));

  return limit == null ? authors : authors.take(limit).toList();
}

/// Number of distinct recipe authors.
int creatorCountFrom(List<Recipe> recipes) =>
    recipes.map((r) => r.authorId).toSet().length;

// ------------------------------------------------------------ diet profile

/// What the signed-in person must not or does not want to eat (Konzept 13
/// §2.3), from "Ernährung & Allergien".
class RecipeDietProfile {
  const RecipeDietProfile({
    this.allergies = const [],
    this.diets = const [],
    this.autoAdapt = true,
  });

  /// The profile of [user]; [none] without one. Diets that are really "must
  /// not eat" rules (`gluten_free`, `dairy_free`, `nut_free`) count as
  /// allergies, so they are never only a ranking signal.
  factory RecipeDietProfile.of(UserModel? user) {
    if (user == null) return none;
    final allergies = [...user.allergies];
    for (final diet in user.dietPreferences) {
      for (final a in _dietAllergies[diet.trim().toLowerCase()] ?? const []) {
        if (!allergies.contains(a)) allergies.add(a);
      }
    }
    return RecipeDietProfile(allergies: allergies, diets: user.dietPreferences);
  }

  /// No allergies, no diet.
  static const none = RecipeDietProfile();

  /// Allergies as stored (`'peanuts'`, `'Nüsse'`, free text).
  final List<String> allergies;

  /// Diet ids as stored (`'vegan'`, `'vegetarian'`).
  final List<String> diets;

  /// "Rezepte automatisch anpassen" (default on). Off: no substitutes, no
  /// "Für dich angepasst"; allergy warnings stay.
  final bool autoAdapt;

  bool get hasProfile => allergies.isNotEmpty || diets.isNotEmpty;

  /// The diets recipes can be checked against (vegan, vegetarian).
  List<DietType> get checkableDiets {
    final byName = DietType.values.asNameMap();
    return [
      for (final d in diets)
        if (byName[d] case final type?)
          if (type == DietType.vegan || type == DietType.vegetarian) type,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is RecipeDietProfile &&
      other.autoAdapt == autoAdapt &&
      _sameList(other.allergies, allergies) &&
      _sameList(other.diets, diets);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(allergies), Object.hashAll(diets), autoAdapt);
}

/// Diet ids that stand for allergies (same table as the detail's
/// adaptation).
const Map<String, List<String>> _dietAllergies = {
  'gluten_free': ['gluten'],
  'dairy_free': ['milk'],
  'nut_free': ['nuts', 'peanuts'],
};

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// How a recipe fits the person (Konzept 13 §2.3).
class RecipeFit {
  const RecipeFit({
    this.unsafeAllergens = const [],
    this.adapted = 0,
    this.dietMet = true,
  });

  /// Fits without remarks (no profile, nothing found).
  static const neutral = RecipeFit();

  /// The person's allergens found in an ingredient without a safe
  /// substitute, each once, in the person's order. Never hidden.
  final List<AllergenMatch> unsafeAllergens;

  /// Ingredients replaced for the person ("Für dich angepasst").
  final int adapted;

  /// The diet is met, directly or after adapting.
  final bool dietMet;

  /// Shows "Enthält …" on cards.
  bool get hasWarning => unsafeAllergens.isNotEmpty;

  /// "Passt zu mir": no own allergen without a safe substitute and the diet
  /// is met. Unchecked ingredients do not exclude a recipe.
  bool get fitsMe => !hasWarning && dietMet;
}

/// Checks [recipe] against [profile]: allergens per ingredient with word
/// boundaries (AllergenMatcher), a substitute only when it contains none of
/// the person's allergens and keeps the diet.
RecipeFit recipeFitOf(Recipe recipe, RecipeDietProfile profile) {
  if (!profile.hasProfile) return RecipeFit.neutral;
  final matcher = AllergenMatcher(profile.allergies);
  final diets = profile.checkableDiets;
  final unsafe = <AllergenMatch>[];
  final seen = <String>{};
  var adapted = 0;

  if (profile.allergies.isNotEmpty) {
    for (final ingredient in recipe.ingredients) {
      final hits = matcher.matches(ingredient.name);
      if (hits.isEmpty) continue;
      if (profile.autoAdapt &&
          _hasSafeSubstitute(ingredient.name, hits, matcher, diets)) {
        adapted++;
        continue;
      }
      for (final hit in hits) {
        if (seen.add(hit.allergy)) unsafe.add(hit);
      }
    }
  }

  var dietMet = true;
  if (diets.isNotEmpty && !_hasDietLabel(recipe, diets)) {
    final check = IngredientSubstitutionService.checkRecipeCompatibility(
      recipe: recipe,
      diets: diets,
    );
    dietMet =
        check.isCompatible && (profile.autoAdapt || !check.needsModifications);
    if (profile.autoAdapt) adapted += check.possibleSubstitutions;
  }

  // Keep the person's order of allergies.
  final order = {
    for (var i = 0; i < profile.allergies.length; i++) profile.allergies[i]: i,
  };
  unsafe.sort(
    (a, b) => (order[a.allergy] ?? 0).compareTo(order[b.allergy] ?? 0),
  );
  return RecipeFit(unsafeAllergens: unsafe, adapted: adapted, dietMet: dietMet);
}

/// [recipeFitOf] for every recipe, by id. Recipes that fit without remarks
/// are left out (read them as [RecipeFit.neutral]).
Map<String, RecipeFit> recipeFitsFor(
  List<Recipe> recipes,
  RecipeDietProfile profile,
) {
  if (!profile.hasProfile) return const {};
  final out = <String, RecipeFit>{};
  for (final r in recipes) {
    final fit = recipeFitOf(r, profile);
    if (fit.hasWarning || fit.adapted > 0 || !fit.dietMet) out[r.id] = fit;
  }
  return out;
}

bool _hasSafeSubstitute(
  String ingredient,
  List<AllergenMatch> hits,
  AllergenMatcher matcher,
  List<DietType> diets,
) {
  final types = [for (final h in hits) ?h.type];
  // A free-text allergy has no known substitutes.
  if (types.length != hits.length) return false;
  final subs = SubstitutionDatabase.findSubstitutes(
    ingredient: ingredient,
    allergies: types,
    diets: diets,
  );
  return subs.any(
    (s) =>
        types.every(s.avoidsAllergies.contains) &&
        !matcher.contains(s.substitute) &&
        diets.every(s.suitableFor.contains),
  );
}

bool _hasDietLabel(Recipe recipe, List<DietType> diets) => diets.every(
  (d) => d == DietType.vegetarian
      ? isShownVegetarian(recipe)
      : isShownVegan(recipe),
);

// ------------------------------------------------------------------ labels

/// Exact, case-insensitive label match (Konzept 13 §5.1: exact label ids on
/// both sides, no substring).
bool hasRecipeLabel(Recipe recipe, String label) {
  final needle = label.toLowerCase();
  return recipe.labels.any((l) => l.trim().toLowerCase() == needle);
}

/// Vegetarian (or vegan) as the detail shows it: the label holds and no
/// ingredient breaks it ([recipeShownDiet], owner decision S5).
bool isShownVegetarian(Recipe recipe) => recipeShownDiet(recipe) != null;

/// Vegan as the detail shows it: a "vegan" recipe with honey or egg yolk
/// does not count ([recipeShownDiet], owner decision S5).
bool isShownVegan(Recipe recipe) => recipeShownDiet(recipe) == RecipeDiet.vegan;

/// Diet labels the search offers as chips (Konzept 13 §4.1).
const List<String> kRecipeDietLabels = [
  'vegetarian',
  'vegan',
  'gluten-free',
  'low-carb',
  'healthy',
];

/// Popularity over all time, as `RecipeService.getPopularRecipes` ranks it.
double recipePopularity(Recipe r) =>
    (r.viewCount * 0.1) + (r.averageRating * 20) + (r.ratingCount * 2);

/// [recipes] in the app language first, otherwise in their order.
List<Recipe> preferLanguage(List<Recipe> recipes, String? language) {
  if (language == null) return recipes;
  return [
    for (final r in recipes)
      if (r.language == language) r,
    for (final r in recipes)
      if (r.language != language) r,
  ];
}

// --------------------------------------------------------- tab quick filter

/// The chips of the tab (D2-Rezepte "Für dich / Schnell / Vegetarisch …").
/// One is always selected.
enum RecipeQuickFilter { forYou, quick, vegetarian, vegan, glutenFree, healthy }

/// Total time a "quick" recipe stays within (Konzept 13 §3.1 Nr. 8).
const int kQuickRecipeMinutes = 20;

bool matchesQuickFilter(Recipe r, RecipeQuickFilter filter) => switch (filter) {
  RecipeQuickFilter.forYou => true,
  RecipeQuickFilter.quick =>
    r.totalTimeMinutes > 0 && r.totalTimeMinutes <= kQuickRecipeMinutes,
  RecipeQuickFilter.vegetarian => isShownVegetarian(r),
  RecipeQuickFilter.vegan => isShownVegan(r),
  RecipeQuickFilter.glutenFree => hasRecipeLabel(r, 'gluten-free'),
  RecipeQuickFilter.healthy => hasRecipeLabel(r, 'healthy'),
};

/// "Für dich" and every chip with at least one recipe.
List<RecipeQuickFilter> availableQuickFilters(List<Recipe> recipes) => [
  RecipeQuickFilter.forYou,
  for (final f in RecipeQuickFilter.values.skip(1))
    if (recipes.any((r) => matchesQuickFilter(r, f))) f,
];

// -------------------------------------------------------------- list match

/// Stems of the words of [text] for matching items and ingredients
/// ("Tomaten" and "Tomate" match, "Feta-Käse" contains "Feta").
Set<String> nameStems(String text) => normalizeProductName(
  text.replaceAll(RegExp(r'[-/,()]'), ' '),
).split(' ').where((w) => w.length >= 3).map(AllergenMatcher.stem).toSet();

/// Ingredients of [recipe] that are already on the list, given the stems of
/// the list's open items ([nameStems]).
int listMatchCount(Recipe recipe, List<Set<String>> itemStems) {
  if (itemStems.isEmpty) return 0;
  var count = 0;
  for (final ingredient in recipe.ingredients) {
    final stems = nameStems(ingredient.name);
    if (stems.isEmpty) continue;
    final onList = itemStems.any(
      (item) =>
          item.isNotEmpty &&
          (item.every(stems.contains) || stems.every(item.contains)),
    );
    if (onList) count++;
  }
  return count;
}

/// Ingredients that have to be on the list for "Passt zu deiner Liste".
const int kListMatchMin = 2;

// ------------------------------------------------------------------- home

/// Why the hero shows its recipe; picks the eyebrow.
enum RecipeHeroKind {
  /// At least [kListMatchMin] ingredients are on the person's list.
  listMatch,

  /// "Rezept der Woche" from the server.
  recipeOfTheWeek,

  /// The best match of the selected chip.
  pick,
}

/// The ids the tab shows for one chip, fixed per visit so nothing jumps
/// while data refreshes (Konzept 13 §2.1). Resolve them against the current
/// catalogue with [resolveRecipes], so edits and deletions still show.
class RecipesHomeIds {
  const RecipesHomeIds({
    this.heroId,
    this.heroKind = RecipeHeroKind.pick,
    this.popularIds = const [],
    this.newestIds = const [],
    this.poolCount = 0,
  });

  final String? heroId;
  final RecipeHeroKind heroKind;
  final List<String> popularIds;
  final List<String> newestIds;

  /// Recipes in the selected view (for "Alle 5 Rezepte").
  final int poolCount;
}

/// Below this catalogue size "Beliebt" and "Neu" are left out, so no section
/// shows (nearly) every recipe (Konzept 13 §3.1).
const int kHomeSectionsMinCatalogue = 8;

/// Cards in "Beliebt diese Woche" (D2: 2 × 2) and "Neu" (Konzept: up to 6).
const int kHomePopularCount = 4;
const int kHomeNewestCount = 6;

/// Picks the hero, "Beliebt diese Woche" and "Neu" for [filter].
///
/// "Für dich" leaves out recipes that do not fit the person (allergen without
/// a safe substitute, diet not met). The hero never shows a recipe with one
/// of the person's allergens, in any view. [popularIds] is the server ranking
/// (empty: ranked locally); [weekId] the recipe of the week; [listItemStems]
/// the open items of the person's list.
RecipesHomeIds buildRecipesHome({
  required List<Recipe> catalogue,
  required RecipeQuickFilter filter,
  Map<String, RecipeFit> fits = const {},
  List<Set<String>> listItemStems = const [],
  List<String> popularIds = const [],
  String? weekId,
  String? language,
}) {
  RecipeFit fitOf(Recipe r) => fits[r.id] ?? RecipeFit.neutral;
  final pool = preferLanguage([
    for (final r in catalogue)
      if (matchesQuickFilter(r, filter) &&
          (filter != RecipeQuickFilter.forYou || fitOf(r).fitsMe))
        r,
  ], language);
  if (pool.isEmpty) return const RecipesHomeIds();

  final safe = [
    for (final r in pool)
      if (!fitOf(r).hasWarning) r,
  ];

  Recipe? hero;
  var kind = RecipeHeroKind.pick;
  if (listItemStems.isNotEmpty) {
    var best = 0;
    for (final r in safe) {
      final n = listMatchCount(r, listItemStems);
      if (n > best ||
          (n == best &&
              n > 0 &&
              r.averageRating > (hero?.averageRating ?? 0))) {
        best = n;
        hero = r;
      }
    }
    if (best >= kListMatchMin) {
      kind = RecipeHeroKind.listMatch;
    } else {
      hero = null;
    }
  }
  if (hero == null && weekId != null) {
    for (final r in safe) {
      if (r.id == weekId) {
        hero = r;
        kind = RecipeHeroKind.recipeOfTheWeek;
        break;
      }
    }
  }
  if (hero == null && safe.isNotEmpty) {
    hero = ([...safe]..sort(_byPopularity)).first;
    kind = RecipeHeroKind.pick;
  }

  final heroId = hero?.id;
  final rest = [
    for (final r in pool)
      if (r.id != heroId) r,
  ];
  if (catalogue.length < kHomeSectionsMinCatalogue || rest.isEmpty) {
    return RecipesHomeIds(
      heroId: heroId,
      heroKind: kind,
      poolCount: pool.length,
    );
  }

  // Popular: the server order where it knows the recipes, filled up with the
  // local ranking.
  final byId = {for (final r in rest) r.id: r};
  final popular = <String>[];
  for (final id in popularIds) {
    if (popular.length >= kHomePopularCount) break;
    if (byId.containsKey(id) && !popular.contains(id)) popular.add(id);
  }
  if (popular.length < kHomePopularCount) {
    for (final r in [...rest]..sort(_byPopularity)) {
      if (popular.length >= kHomePopularCount) break;
      if (!popular.contains(r.id)) popular.add(r.id);
    }
  }
  // Half rule: never more than half of the view in one section.
  final half = (pool.length / 2).floor();
  if (popular.length > half) popular.removeRange(half, popular.length);

  final newest = [
    for (final r in rest)
      if (!popular.contains(r.id)) r,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final newestIds = [
    for (final r in newest.take(_min(kHomeNewestCount, half))) r.id,
  ];

  return RecipesHomeIds(
    heroId: heroId,
    heroKind: kind,
    popularIds: popular,
    newestIds: newestIds,
    poolCount: pool.length,
  );
}

int _min(int a, int b) => a < b ? a : b;

int _byPopularity(Recipe a, Recipe b) {
  final c = recipePopularity(b).compareTo(recipePopularity(a));
  return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
}

/// [ids] mapped to the recipes of [catalogue], skipping unknown ids.
List<Recipe> resolveRecipes(List<Recipe> catalogue, List<String> ids) {
  if (ids.isEmpty) return const [];
  final byId = {for (final r in catalogue) r.id: r};
  return [for (final id in ids) ?byId[id]];
}

/// Categories with at least one recipe, in the order of [recipeCategories].
List<RecipeCategory> categoriesWithRecipes(List<Recipe> catalogue) => [
  for (final c in recipeCategories)
    if (catalogue.any((r) => hasRecipeLabel(r, c.id))) c,
];

// ------------------------------------------------------------------ search

/// What the search in the tab finds (Konzept 13 §4.1).
class RecipeSearchResults {
  const RecipeSearchResults({
    this.recipes = const [],
    this.ingredient,
    this.ingredientCount = 0,
    this.categories = const [],
    this.dietLabels = const [],
    this.authors = const [],
  });

  /// Title hits before ingredient hits before the rest, then by rating.
  final List<Recipe> recipes;

  /// The ingredient for "Rezepte mit Feta" (as typed), or null.
  final String? ingredient;
  final int ingredientCount;

  final List<RecipeCategory> categories;

  /// Diet label ids ([kRecipeDietLabels]) whose name matches.
  final List<String> dietLabels;

  /// Up to [kSearchAuthorCount] creators.
  final List<RecipeAuthorSummary> authors;

  bool get isEmpty =>
      recipes.isEmpty &&
      ingredient == null &&
      categories.isEmpty &&
      dietLabels.isEmpty &&
      authors.isEmpty;
}

/// Creators shown in the search.
const int kSearchAuthorCount = 3;

/// Characters from which ingredients, categories and diets are searched.
const int kSearchIngredientFrom = 3;
const int kSearchChipsFrom = 2;

/// Searches name, description, ingredients, labels and author of
/// [catalogue] for [query]. [categoryName] and [dietName] give the
/// localised names of categories and diet labels.
RecipeSearchResults searchRecipes(
  List<Recipe> catalogue,
  String query, {
  required String Function(RecipeCategory category) categoryName,
  required String Function(String label) dietName,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const RecipeSearchResults();
  final folded = AllergenMatcher.fold(q);
  bool has(String text) =>
      text.toLowerCase().contains(q) ||
      AllergenMatcher.fold(text).contains(folded);

  final scored = <(Recipe, int)>[];
  var ingredientCount = 0;
  for (final r in catalogue) {
    final byIngredient = r.ingredients.any((i) => has(i.name));
    if (byIngredient) ingredientCount++;
    final int score;
    if (has(r.name)) {
      score = 3;
    } else if (byIngredient) {
      score = 2;
    } else if (has(r.description) || has(r.authorName) || r.labels.any(has)) {
      score = 1;
    } else {
      continue;
    }
    scored.add((r, score));
  }
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : b.$1.averageRating.compareTo(a.$1.averageRating);
  });

  final chips = q.length >= kSearchChipsFrom;
  final categories = chips
      ? [
          for (final c in recipeCategories)
            if (has(categoryName(c)) || c.keywords.any((k) => k.contains(q))) c,
        ]
      : const <RecipeCategory>[];
  final diets = chips
      ? [
          for (final d in kRecipeDietLabels)
            if (has(dietName(d)) || d.contains(q)) d,
        ]
      : const <String>[];

  final authors = [
    for (final a in topAuthorsFrom(catalogue))
      if (has(a.name)) a,
  ].take(kSearchAuthorCount).toList();

  final ingredient = q.length >= kSearchIngredientFrom && ingredientCount > 0
      ? query.trim()
      : null;

  return RecipeSearchResults(
    recipes: [for (final s in scored) s.$1],
    ingredient: ingredient,
    ingredientCount: ingredient == null ? 0 : ingredientCount,
    categories: categories,
    dietLabels: diets,
    authors: authors,
  );
}

// -------------------------------------------------------------- list pages

/// Filter chips of the category and "Alle" pages (Konzept 13 §5.1). Several
/// can be on at once; they combine with AND.
enum RecipeListFilter {
  fitsMe('fits-me'),
  under20('under-20'),
  upTo30('up-to-30'),
  easy('easy'),
  medium('medium'),
  advanced('advanced'),
  vegetarian('vegetarian'),
  vegan('vegan'),
  glutenFree('gluten-free'),
  healthy('healthy');

  const RecipeListFilter(this.id);

  /// Stable id, also used in links (`/recipes/all?filter=under-20`).
  final String id;

  static RecipeListFilter? byId(String? id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }
}

bool matchesListFilter(
  Recipe r,
  RecipeListFilter filter,
  RecipeFit fit,
) => switch (filter) {
  RecipeListFilter.fitsMe => fit.fitsMe,
  RecipeListFilter.under20 => matchesQuickFilter(r, RecipeQuickFilter.quick),
  RecipeListFilter.upTo30 => r.totalTimeMinutes > 0 && r.totalTimeMinutes <= 30,
  RecipeListFilter.easy => hasRecipeLabel(r, 'easy'),
  RecipeListFilter.medium => hasRecipeLabel(r, 'medium'),
  RecipeListFilter.advanced => hasRecipeLabel(r, 'advanced'),
  RecipeListFilter.vegetarian => isShownVegetarian(r),
  RecipeListFilter.vegan => isShownVegan(r),
  RecipeListFilter.glutenFree => hasRecipeLabel(r, 'gluten-free'),
  RecipeListFilter.healthy => hasRecipeLabel(r, 'healthy'),
};

/// The chips that make sense for [recipes]: only filters that occur (and
/// that do not repeat the page's own [categoryId]); "Passt zu mir" only with
/// a diet profile. Filters in [keep] (active ones) always stay.
List<RecipeListFilter> availableListFilters(
  List<Recipe> recipes, {
  required bool hasProfile,
  Map<String, RecipeFit> fits = const {},
  String? categoryId,
  Set<RecipeListFilter> keep = const {},
}) => [
  for (final f in RecipeListFilter.values)
    if (keep.contains(f) ||
        (f == RecipeListFilter.fitsMe
            ? hasProfile
            : f.id != categoryId &&
                  recipes.any(
                    (r) => matchesListFilter(
                      r,
                      f,
                      fits[r.id] ?? RecipeFit.neutral,
                    ),
                  )))
      f,
];

List<Recipe> applyListFilters(
  List<Recipe> recipes,
  Set<RecipeListFilter> filters, {
  Map<String, RecipeFit> fits = const {},
}) {
  if (filters.isEmpty) return recipes;
  return [
    for (final r in recipes)
      if (filters.every(
        (f) => matchesListFilter(r, f, fits[r.id] ?? RecipeFit.neutral),
      ))
        r,
  ];
}

/// The sort menu of the list pages (Konzept 13 §5.1).
enum RecipeSort {
  popular('popular'),
  newest('newest'),
  fastest('fastest'),
  rating('rating');

  const RecipeSort(this.id);

  /// Stable id, also used in links (`?sort=newest`).
  final String id;

  static RecipeSort? byId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

List<Recipe> sortRecipes(List<Recipe> recipes, RecipeSort sort) {
  final out = [...recipes];
  switch (sort) {
    case RecipeSort.popular:
      out.sort(_byPopularity);
    case RecipeSort.newest:
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case RecipeSort.fastest:
      out.sort((a, b) {
        // Recipes without a time go last.
        final ta = a.totalTimeMinutes > 0 ? a.totalTimeMinutes : 1 << 20;
        final tb = b.totalTimeMinutes > 0 ? b.totalTimeMinutes : 1 << 20;
        return ta.compareTo(tb);
      });
    case RecipeSort.rating:
      out.sort((a, b) {
        final c = b.averageRating.compareTo(a.averageRating);
        return c != 0 ? c : b.ratingCount.compareTo(a.ratingCount);
      });
  }
  return out;
}

/// Prefix of a category id that lists recipes with one ingredient
/// (`/recipes/category/ingredient:feta`, Konzept 13 E-10).
const String kIngredientCategoryPrefix = 'ingredient:';

/// The ingredient of an ingredient category id, else null.
String? ingredientOfCategory(String categoryId) =>
    categoryId.startsWith(kIngredientCategoryPrefix)
    ? categoryId.substring(kIngredientCategoryPrefix.length).trim()
    : null;

/// The recipes of a category page: exact label (vegan and vegetarian only
/// while no ingredient breaks them), or for `ingredient:<name>` every recipe with
/// that ingredient.
List<Recipe> recipesInCategory(List<Recipe> catalogue, String categoryId) {
  final ingredient = ingredientOfCategory(categoryId);
  if (ingredient != null) {
    final q = AllergenMatcher.fold(ingredient.toLowerCase());
    if (q.isEmpty) return const [];
    return [
      for (final r in catalogue)
        if (r.ingredients.any((i) => AllergenMatcher.fold(i.name).contains(q)))
          r,
    ];
  }
  final bool Function(Recipe) inCategory = switch (categoryId) {
    'vegan' => isShownVegan,
    'vegetarian' =>
      (r) => hasRecipeLabel(r, 'vegetarian') && isShownVegetarian(r),
    _ => (r) => hasRecipeLabel(r, categoryId),
  };
  return [
    for (final r in catalogue)
      if (inCategory(r)) r,
  ];
}

/// The popular page: the server ranking where it knows the recipes, the
/// rest of the catalogue ranked locally (at most [limit]).
List<Recipe> popularRecipes(
  List<Recipe> catalogue,
  List<String> serverIds, {
  int limit = 50,
}) {
  final ranked = resolveRecipes(catalogue, serverIds);
  final seen = {for (final r in ranked) r.id};
  final out = [
    ...ranked,
    for (final r in [...catalogue]..sort(_byPopularity))
      if (!seen.contains(r.id)) r,
  ];
  return out.take(limit).toList();
}
