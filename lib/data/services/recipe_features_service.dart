import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/recipe_service.dart';

/// Picks the featured "Recipe of the Week" shown on the Recipes tab.
class RecipeFeaturesService {
  static final RecipeFeaturesService instance = RecipeFeaturesService._();
  RecipeFeaturesService._();
  
  final _supabase = SupabaseService.instance.client;

  // =============================================
  // RECIPE OF THE WEEK
  // =============================================

  /// Get this week's featured recipe.
  /// Algorithm:
  ///   1. Try ratings from last 7 days → top 5.
  ///   2. If fewer than 5 found, expand window to 30 days.
  ///   3. If still fewer than 5, use all-time ratings from recipe_ratings.
  ///   4. Use a week-stable seed (days since fixed epoch ÷ 7) to pick one
  ///      consistently for the entire week, changing automatically each Monday.
  Future<Recipe?> getRecipeOfTheWeek() async {
    try {
      // Try progressively wider windows until we have at least 1 candidate
      List<String> topIds = await _getTopIdsByRatings(days: 7, limit: 5);
      if (topIds.isEmpty) {
        topIds = await _getTopIdsByRatings(days: 30, limit: 5);
      }
      if (topIds.isEmpty) {
        topIds = await _getTopIdsByRatings(days: null, limit: 5); // all-time
      }
      // Last resort: pick by view_count (always populated)
      if (topIds.isEmpty) {
        final fallback = await _supabase
            .from('recipes')
            .select('id')
            .order('view_count', ascending: false)
            .limit(5);
        topIds = (fallback as List).map((r) => r['id'] as String).toList();
      }

      if (topIds.isEmpty) return null;

      // Week-stable seed: number of complete weeks since 2020-01-06 (a Monday)
      final daysSinceEpoch =
          DateTime.now().difference(DateTime(2020, 1, 6)).inDays;
      final weekSeed = daysSinceEpoch ~/ 7;
      final selectedId = topIds[weekSeed % topIds.length];

      debugPrint(
          '🏆 [FEATURES] Recipe of the Week: $selectedId (week $weekSeed, top ${topIds.length})');
      return await RecipeService.instance.getRecipeById(selectedId);
    } catch (e) {
      debugPrint('⚠️ [FEATURES] Error fetching recipe of the week: $e');
      return null;
    }
  }

  /// Returns the top [limit] recipe IDs ranked by rating activity.
  /// [days] = null means all-time. Uses recipe_ratings aggregation (no
  /// dependency on computed columns that may not exist on the recipes table).
  Future<List<String>> _getTopIdsByRatings({int? days, required int limit}) async {
    var query = _supabase
        .from('recipe_ratings')
        .select('recipe_id, rating');

    if (days != null) {
      final since = DateTime.now().subtract(Duration(days: days));
      query = query.gte('created_at', since.toIso8601String());
    }

    final response = await query;
    if ((response as List).isEmpty) return [];

    final ratings = <String, List<int>>{};
    for (final r in response) {
      final id = r['recipe_id'] as String;
      final rating = r['rating'] as int;
      ratings.putIfAbsent(id, () => []).add(rating);
    }

    final sorted = ratings.entries.toList()
      ..sort((a, b) {
        final countCmp = b.value.length.compareTo(a.value.length);
        if (countCmp != 0) return countCmp;
        final avgA = a.value.reduce((x, y) => x + y) / a.value.length;
        final avgB = b.value.reduce((x, y) => x + y) / b.value.length;
        return avgB.compareTo(avgA);
      });

    return sorted.take(limit).map((e) => e.key).toList();
  }
}
