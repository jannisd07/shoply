import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/food_log_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/recipe_service.dart';

/// Connects calorie tracking (Feature 6) to recipes and the Avo nudge
/// surface (Feature 5): "N kcal left today — 3 dinner ideas from your
/// list." Only ever suggests recipes that already carry stored
/// `nutrition.calories` — never calls Gemini itself, so this never competes
/// with the 1.1s-throttled categorization pipeline and costs nothing beyond
/// ordinary Supabase reads.
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

  /// Up to [limit] recipes that fit [remainingCalories], respecting the
  /// user's diet preferences (every preference must match one of the
  /// recipe's labels, same rule Avo's `search_recipes` tool already uses)
  /// and allergies (excluded when any allergen keyword appears in an
  /// ingredient name). Candidates are pooled from saved, recently added, and
  /// popular recipes — recipes without a stored calorie count are skipped
  /// rather than estimated on the spot.
  Future<List<Recipe>> getSuggestions({
    required int remainingCalories,
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    int limit = 3,
  }) async {
    if (remainingCalories < minRemainingCalories) return [];
    try {
      final pools = await Future.wait([
        RecipeService.instance.getSavedRecipes(),
        RecipeService.instance.getPopularRecipes(limit: 20),
        RecipeService.instance.getRecentRecipes(limit: 20),
      ]);

      final seen = <String>{};
      final candidates = <Recipe>[];
      for (final pool in pools) {
        for (final recipe in pool) {
          if (seen.add(recipe.id)) candidates.add(recipe);
        }
      }

      return filterAndSort(
        candidates: candidates,
        remainingCalories: remainingCalories,
        dietPreferences: dietPreferences,
        allergies: allergies,
        limit: limit,
      );
    } catch (e) {
      debugPrint('🥑 [CALORIE_NUDGE] Failed to compute recipe suggestions: $e');
      return [];
    }
  }

  /// Pure filter/sort step of [getSuggestions], split out so it can be unit
  /// tested without a live Supabase connection: recipes must carry a stored
  /// calorie count that fits [remainingCalories], satisfy every diet
  /// preference (matched against the recipe's labels) and contain no
  /// allergy keyword (matched against ingredient names). Survivors are
  /// ordered by best use of the remaining budget (closest to, without
  /// exceeding, what's left), tie-broken by rating.
  @visibleForTesting
  static List<Recipe> filterAndSort({
    required List<Recipe> candidates,
    required int remainingCalories,
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    int limit = 3,
  }) {
    final allergensLower =
        allergies.map((a) => a.toLowerCase()).where((a) => a.isNotEmpty).toList();
    final dietLower =
        dietPreferences.map((d) => d.toLowerCase()).where((d) => d.isNotEmpty).toList();

    final fits = candidates.where((recipe) {
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

    fits.sort((a, b) {
      final diff = (remainingCalories - a.nutrition!.calories!)
          .compareTo(remainingCalories - b.nutrition!.calories!);
      if (diff != 0) return diff;
      return b.averageRating.compareTo(a.averageRating);
    });

    return fits.take(limit).toList();
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
