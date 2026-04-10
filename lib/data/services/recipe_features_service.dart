import 'package:shoply/data/models/recipe_collection.dart';
import 'package:shoply/data/models/weekly_challenge.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/recipe_service.dart';

/// Service for recipe features: collections, follows, challenges, etc.
class RecipeFeaturesService {
  static final RecipeFeaturesService instance = RecipeFeaturesService._();
  RecipeFeaturesService._();
  
  final _supabase = SupabaseService.instance.client;

  // =============================================
  // RECIPE COLLECTIONS
  // =============================================

  /// Get all featured collections
  Future<List<RecipeCollection>> getFeaturedCollections() async {
    try {
      final response = await _supabase
          .from('recipe_collections')
          .select()
          .eq('is_featured', true)
          .order('display_order');

      return (response as List).map((json) => RecipeCollection.fromJson(json)).toList();
    } catch (e) {
      print('⚠️ [FEATURES] Error fetching collections: $e');
      return _getDefaultCollections();
    }
  }

  /// Get all collections
  Future<List<RecipeCollection>> getAllCollections() async {
    try {
      final response = await _supabase
          .from('recipe_collections')
          .select()
          .order('display_order');

      return (response as List).map((json) => RecipeCollection.fromJson(json)).toList();
    } catch (e) {
      print('⚠️ [FEATURES] Error fetching collections: $e');
      return _getDefaultCollections();
    }
  }

  /// Get recipes in a collection
  Future<List<Recipe>> getCollectionRecipes(String collectionId) async {
    try {
      final response = await _supabase
          .from('recipe_collection_items')
          .select('recipe_id')
          .eq('collection_id', collectionId)
          .order('sort_order');

      final recipeIds = (response as List).map((r) => r['recipe_id'] as String).toList();
      
      if (recipeIds.isEmpty) return [];
      
      // Get recipes from database
      final recipesResponse = await _supabase
          .from('recipes')
          .select('*, recipe_ratings!left(user_id, rating)')
          .inFilter('id', recipeIds);
      
      final recipes = (recipesResponse as List).map((json) {
        final ratings = (json['recipe_ratings'] as List?) ?? [];
        final ratingCount = ratings.length;
        final averageRating = ratingCount > 0
            ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
            : 0.0;
        return Recipe.fromJson({
          ...json,
          'average_rating': averageRating,
          'rating_count': ratingCount,
        });
      }).toList();
      
      // Sort by original order
      recipes.sort((a, b) {
        final aIndex = recipeIds.indexOf(a.id);
        final bIndex = recipeIds.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });
      
      return recipes;
    } catch (e) {
      print('⚠️ [FEATURES] Error fetching collection recipes: $e');
      return [];
    }
  }

  /// Default collections when database not available
  /// Note: recipeIds will be populated dynamically when fetched
  List<RecipeCollection> _getDefaultCollections() {
    return [
      RecipeCollection(
        id: 'quick-weeknight',
        name: 'Quick Weeknight Dinners',
        nameDE: 'Schnelle Feierabendküche',
        description: 'Ready in 30 minutes or less',
        descriptionDE: 'Fertig in 30 Minuten oder weniger',
        icon: '⚡',
        isFeatured: true,
        displayOrder: 1,
        recipeIds: [], // Will be populated from database
        createdAt: DateTime.now(),
      ),
      RecipeCollection(
        id: 'healthy',
        name: 'Healthy Meal Prep',
        nameDE: 'Gesunde Meal Prep',
        description: 'Nutritious recipes for the week',
        descriptionDE: 'Nahrhafte Rezepte für die Woche',
        icon: '🥗',
        isFeatured: true,
        displayOrder: 2,
        recipeIds: [], // Will be populated from database
        createdAt: DateTime.now(),
      ),
      RecipeCollection(
        id: 'comfort-food',
        name: 'Comfort Food Classics',
        nameDE: 'Comfort Food Klassiker',
        description: 'Hearty dishes that warm the soul',
        descriptionDE: 'Herzhafte Gerichte die die Seele wärmen',
        icon: '🍲',
        isFeatured: true,
        displayOrder: 3,
        recipeIds: [], // Will be populated from database
        createdAt: DateTime.now(),
      ),
    ];
  }

  // =============================================
  // CREATOR FOLLOWS
  // =============================================

  /// Check if user follows a creator
  Future<bool> isFollowing(String creatorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('creator_follows')
          .select()
          .eq('follower_id', userId)
          .eq('creator_id', creatorId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Follow a creator
  Future<bool> followCreator(String creatorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('creator_follows').upsert({
        'follower_id': userId,
        'creator_id': creatorId,
      });

      print('✅ [FEATURES] Now following creator: $creatorId');
      return true;
    } catch (e) {
      print('❌ [FEATURES] Error following creator: $e');
      return false;
    }
  }

  /// Unfollow a creator
  Future<bool> unfollowCreator(String creatorId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('creator_follows')
          .delete()
          .eq('follower_id', userId)
          .eq('creator_id', creatorId);

      print('✅ [FEATURES] Unfollowed creator: $creatorId');
      return true;
    } catch (e) {
      print('❌ [FEATURES] Error unfollowing creator: $e');
      return false;
    }
  }

  /// Get list of followed creator IDs
  Future<Set<String>> getFollowedCreatorIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('creator_follows')
          .select('creator_id')
          .eq('follower_id', userId);

      return (response as List).map((r) => r['creator_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Get follower count for a creator
  Future<int> getFollowerCount(String creatorId) async {
    try {
      final response = await _supabase
          .from('creator_follows')
          .select()
          .eq('creator_id', creatorId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // =============================================
  // WEEKLY CHALLENGES
  // =============================================

  /// Get current active challenge
  /// Note: weekly_challenges table does not exist yet — returns default challenge
  Future<WeeklyChallenge?> getCurrentChallenge() async {
    return _getDefaultChallenge();
  }

  WeeklyChallenge _getDefaultChallenge() {
    final now = DateTime.now();
    return WeeklyChallenge(
      id: 'default-challenge',
      title: '5 Ingredient Challenge',
      titleDE: '5-Zutaten-Challenge',
      description: 'Create a delicious meal using only 5 ingredients!',
      descriptionDE: 'Kreiere ein leckeres Gericht mit nur 5 Zutaten!',
      startDate: now.subtract(Duration(days: now.weekday - 1)),
      endDate: now.add(Duration(days: 7 - now.weekday)),
      hashtag: '#Avo5Ingredients',
      isActive: true,
    );
  }

  /// Submit entry to a challenge
  /// Note: challenge_entries table does not exist yet — returns false
  Future<bool> submitChallengeEntry({
    required String challengeId,
    required String recipeId,
    String? photoUrl,
    String? notes,
  }) async {
    print('⚠️ [FEATURES] Challenge entries not yet supported (table missing)');
    return false;
  }

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

      print(
          '🏆 [FEATURES] Recipe of the Week: $selectedId (week $weekSeed, top ${topIds.length})');
      return await RecipeService.instance.getRecipeById(selectedId);
    } catch (e) {
      print('⚠️ [FEATURES] Error fetching recipe of the week: $e');
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

  // Kept for backwards compatibility (push_notification_service uses it)
  Future<Recipe?> getRecipeOfTheDay() => getRecipeOfTheWeek();

  // =============================================
  // NUTRITION INFO
  // =============================================

  /// Get nutrition info for a recipe
  /// Reads from recipes.nutrition JSONB field (no separate recipe_nutrition table)
  Future<NutritionInfo?> getNutritionInfo(String recipeId) async {
    try {
      final response = await _supabase
          .from('recipes')
          .select('nutrition')
          .eq('id', recipeId)
          .maybeSingle();

      if (response != null && response['nutrition'] != null) {
        return NutritionInfo.fromJson(response['nutrition'] as Map<String, dynamic>);
      }

      return _getEstimatedNutrition(recipeId);
    } catch (e) {
      return _getEstimatedNutrition(recipeId);
    }
  }

  /// Estimated nutrition for sample recipes
  NutritionInfo? _getEstimatedNutrition(String recipeId) {
    // Provide some default estimates based on recipe type
    final sampleNutrition = {
      'recipe_001': const NutritionInfo(calories: 520, proteinG: 28, carbsG: 45, fatG: 24, fiberG: 3),
      'recipe_002': const NutritionInfo(calories: 380, proteinG: 12, carbsG: 62, fatG: 8, fiberG: 4),
      'recipe_003': const NutritionInfo(calories: 290, proteinG: 8, carbsG: 35, fatG: 12, fiberG: 6),
      'recipe_004': const NutritionInfo(calories: 680, proteinG: 35, carbsG: 52, fatG: 32, fiberG: 2),
      'recipe_005': const NutritionInfo(calories: 420, proteinG: 22, carbsG: 38, fatG: 18, fiberG: 5),
    };
    
    return sampleNutrition[recipeId];
  }

  // =============================================
  // SHARING (Deep Links)
  // =============================================

  /// Generate a shareable deep link for a recipe
  String getRecipeShareLink(String recipeId) {
    // Use Supabase project URL or custom domain
    return 'https://shoplyai.app/recipe/$recipeId';
  }

  /// Generate share text for a recipe
  String getShareText(Recipe recipe) {
    final link = getRecipeShareLink(recipe.id);
    return '🍳 Check out this recipe: ${recipe.name}\n\n'
           '⏱ ${recipe.totalTimeMinutes} min | ⭐ ${recipe.averageRating.toStringAsFixed(1)}\n\n'
           '$link';
  }
}
