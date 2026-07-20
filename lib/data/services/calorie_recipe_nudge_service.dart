import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A candidate dinner idea plus *why* it was suggested: which of its
/// ingredients are already sitting unchecked on one of the user's shopping
/// lists (the "pantry/list data" signal from the Feature 5 brief).
class RecipeSuggestion {
  final Recipe recipe;
  final List<String> matchedListItems;

  const RecipeSuggestion({required this.recipe, this.matchedListItems = const []});

  bool get usesListItems => matchedListItems.isNotEmpty;
}

/// Connects calorie tracking (Feature 6) to recipes and the Avo nudge
/// surface (Feature 5): "N kcal left today — 3 dinner ideas from your
/// list." Only ever suggests recipes that already carry stored
/// `nutrition.calories` — never calls Gemini itself, so this never competes
/// with the 1.1s-throttled categorization pipeline and costs nothing beyond
/// ordinary Supabase reads. Ranking also factors in what's already on the
/// user's shopping lists (favor recipes that use it) and what they cooked
/// recently (avoid repeating the same dinner within a few days).
class CalorieRecipeNudgeService {
  static CalorieRecipeNudgeService? _instance;
  static CalorieRecipeNudgeService get instance {
    _instance ??= CalorieRecipeNudgeService._();
    return _instance!;
  }

  CalorieRecipeNudgeService._();

  /// Below this, there isn't enough budget left for a real meal suggestion
  /// to make sense.
  static const int minRemainingCalories = 150;

  static const String _dismissedDateKey = 'avo_calorie_nudge_dismissed_date';

  /// Today's remaining calorie budget, or null when there's nothing to
  /// compute against: tracking is off, no goal has been configured yet, or
  /// the user is signed out. Shared by the home card and the evening
  /// reminder so both agree on the same number.
  Future<int?> getRemainingCaloriesToday() async {
    try {
      final goal = await NutritionGoalService.instance.getGoal();
      if (goal == null || !goal.calorieTrackingEnabled) return null;
      final target = goal.dailyCalorieTarget;
      if (target == null || target <= 0) return null;

      final entries =
          await FoodLogService.instance.getEntriesForDate(DateTime.now());
      final totals = DailyNutritionTotals.fromEntries(entries);
      return target - totals.calories;
    } catch (e) {
      debugPrint('🥑 [CALORIE_NUDGE] Failed to compute remaining calories: $e');
      return null;
    }
  }

  /// Recipes cooked in the last [_recentMealDays] days are deprioritized so
  /// the same dinner doesn't get suggested again right away.
  static const int _recentMealDays = 5;

  /// Up to [limit] recipes that fit [remainingCalories], respecting the
  /// user's diet preferences (every preference must match one of the
  /// recipe's labels, same rule Avo's `search_recipes` tool already uses)
  /// and allergies (excluded when any allergen keyword appears in an
  /// ingredient name). Candidates are pooled from saved, recently added, and
  /// popular recipes — recipes without a stored calorie count are skipped
  /// rather than estimated on the spot. Thin wrapper around
  /// [getRankedSuggestions] for callers (e.g. the evening reminder) that
  /// only need the recipe, not why it was picked.
  Future<List<Recipe>> getSuggestions({
    required int remainingCalories,
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    int limit = 3,
  }) async {
    final ranked = await getRankedSuggestions(
      remainingCalories: remainingCalories,
      dietPreferences: dietPreferences,
      allergies: allergies,
      limit: limit,
    );
    return ranked.map((s) => s.recipe).toList();
  }

  /// Same candidate pool as [getSuggestions], but ranked using two extra
  /// signals from the Feature 5 brief: recipes that reuse items already
  /// unchecked on one of the user's shopping lists ("pantry/list data") are
  /// preferred, and recipes logged as a meal in the last [_recentMealDays]
  /// days ("past meals") are avoided unless excluding them would leave
  /// nothing to suggest.
  Future<List<RecipeSuggestion>> getRankedSuggestions({
    required int remainingCalories,
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    int limit = 3,
  }) async {
    if (remainingCalories < minRemainingCalories) return [];
    try {
      // Each call below starts running immediately (before any `await`), so
      // this is fully concurrent despite the sequential-looking awaits.
      final poolsFuture = Future.wait([
        RecipeService.instance.getSavedRecipes(),
        RecipeService.instance.getPopularRecipes(limit: 20),
        RecipeService.instance.getRecentRecipes(limit: 20),
      ]);
      final recentRecipeIdsFuture =
          FoodLogService.instance.getRecentSourceRecipeIds(days: _recentMealDays);
      final listItemNamesLowerFuture = _getOpenListItemNamesLower();

      final pools = await poolsFuture;
      final recentRecipeIds = await recentRecipeIdsFuture;
      final listItemNamesLower = await listItemNamesLowerFuture;

      final seen = <String>{};
      final candidates = <Recipe>[];
      for (final pool in pools) {
        for (final recipe in pool) {
          if (seen.add(recipe.id)) candidates.add(recipe);
        }
      }

      return rankSuggestions(
        candidates: candidates,
        remainingCalories: remainingCalories,
        dietPreferences: dietPreferences,
        allergies: allergies,
        recentRecipeIds: recentRecipeIds,
        listItemNamesLower: listItemNamesLower,
        limit: limit,
      );
    } catch (e) {
      debugPrint('🥑 [CALORIE_NUDGE] Failed to compute recipe suggestions: $e');
      return [];
    }
  }

  /// Unchecked item names (lowercased) across every shopping list the
  /// current user can see, via the same RLS-scoped pattern
  /// `AvoNudgeService._getOpenItemNames` uses. Fails open to an empty set —
  /// this is only a ranking bonus, so a lookup failure should never block
  /// calorie-fit suggestions from showing.
  Future<Set<String>> _getOpenListItemNamesLower() async {
    try {
      final rows = await Supabase.instance.client
          .from('shopping_items')
          .select('name')
          .eq('is_checked', false);
      return (rows as List)
          .map((r) => (r['name'] as String? ?? '').trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('🥑 [CALORIE_NUDGE] Failed to load open list items: $e');
      return {};
    }
  }

  /// Whether [ingredientName] is (a close match for) one of the user's open
  /// list items — case-insensitive, and tolerant of one side carrying extra
  /// words ("rote Zwiebel" list item vs. "Zwiebel" ingredient) as long as
  /// the shorter side is at least 4 characters, to avoid trivial matches.
  static bool _ingredientOnList(String ingredientName, Set<String> listItemNamesLower) {
    final ing = ingredientName.trim().toLowerCase();
    if (ing.isEmpty) return false;
    for (final item in listItemNamesLower) {
      if (item.isEmpty) continue;
      if (ing == item) return true;
      if (ing.length >= 4 && item.contains(ing)) return true;
      if (item.length >= 4 && ing.contains(item)) return true;
    }
    return false;
  }

  /// Pure filter/rank step, split out so it can be unit tested without a
  /// live Supabase connection: recipes must carry a stored calorie count
  /// that fits [remainingCalories], satisfy every diet preference (matched
  /// against the recipe's labels) and contain no allergy keyword (matched
  /// against ingredient names). Recipes in [recentRecipeIds] are dropped
  /// unless doing so would leave nothing left to suggest (a small recipe
  /// library shouldn't go silent just because the user cooked recently).
  /// Survivors are ordered by how many ingredients match
  /// [listItemNamesLower] (most first), then by best use of the remaining
  /// budget (closest to, without exceeding, what's left), tied-broken by
  /// rating.
  @visibleForTesting
  static List<RecipeSuggestion> rankSuggestions({
    required List<Recipe> candidates,
    required int remainingCalories,
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    Set<String> recentRecipeIds = const {},
    Set<String> listItemNamesLower = const {},
    int limit = 3,
  }) {
    final allergensLower =
        allergies.map((a) => a.toLowerCase()).where((a) => a.isNotEmpty).toList();
    final dietLower =
        dietPreferences.map((d) => d.toLowerCase()).where((d) => d.isNotEmpty).toList();

    var fits = candidates.where((recipe) {
      final calories = recipe.nutrition?.calories;
      if (calories == null || calories <= 0 || calories > remainingCalories) {
        return false;
      }
      if (dietLower.isNotEmpty &&
          !dietLower.every(
              (pref) => recipe.labels.any((l) => l.toLowerCase() == pref))) {
        return false;
      }
      if (allergensLower.isNotEmpty) {
        final ingredientText =
            recipe.ingredients.map((i) => i.name.toLowerCase()).join(' ');
        if (allergensLower.any((a) => ingredientText.contains(a))) return false;
      }
      return true;
    }).toList();

    if (recentRecipeIds.isNotEmpty) {
      final notRecent =
          fits.where((r) => !recentRecipeIds.contains(r.id)).toList();
      if (notRecent.isNotEmpty) fits = notRecent;
    }

    final suggestions = fits.map((recipe) {
      final matched = listItemNamesLower.isEmpty
          ? const <String>[]
          : recipe.ingredients
              .where((i) => _ingredientOnList(i.name, listItemNamesLower))
              .map((i) => i.name)
              .toSet()
              .toList();
      return RecipeSuggestion(recipe: recipe, matchedListItems: matched);
    }).toList();

    suggestions.sort((a, b) {
      final matchDiff =
          b.matchedListItems.length.compareTo(a.matchedListItems.length);
      if (matchDiff != 0) return matchDiff;
      final diff = (remainingCalories - a.recipe.nutrition!.calories!)
          .compareTo(remainingCalories - b.recipe.nutrition!.calories!);
      if (diff != 0) return diff;
      return b.recipe.averageRating.compareTo(a.recipe.averageRating);
    });

    return suggestions.take(limit).toList();
  }

  /// Whether the user already dismissed today's card — resets automatically
  /// the next day since the stored date stops matching.
  Future<bool> isDismissedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_dismissedDateKey);
      return stored == _todayKey();
    } catch (e) {
      return false;
    }
  }

  Future<void> dismissToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedDateKey, _todayKey());
    } catch (e) {
      debugPrint('🥑 [CALORIE_NUDGE] Failed to store dismissal: $e');
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
