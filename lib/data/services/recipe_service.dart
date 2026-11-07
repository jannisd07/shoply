import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/recipe_auto_labeler.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Recipes: queries, create/edit/delete, ratings and saved recipes.
///
/// The full recipe list ([getRecipes]) is fetched once and shared: concurrent
/// callers wait on the same request and the result is reused for
/// [_allRecipesTtl]. Popular / recent / category / author / search views are
/// all derived from it, so the Recipes tab no longer downloads the table
/// several times in parallel or once per search keystroke.
class RecipeService {
  static final RecipeService instance = RecipeService._();

  /// Returns the shared [instance] — the recipe cache only helps if every
  /// caller uses the same object.
  factory RecipeService() => instance;

  RecipeService._();

  final _supabase = SupabaseService.instance.client;

  /// Expose supabase client for direct queries when needed
  SupabaseClient get supabase => _supabase;

  static const String _recipeSelect = '*, recipe_ratings!left(user_id, rating)';

  // ========== SHARED RECIPE LIST CACHE ==========

  static const Duration _allRecipesTtl = Duration(seconds: 30);
  List<Recipe>? _allRecipes;
  DateTime? _allRecipesAt;
  String? _allRecipesUserId;
  Future<List<Recipe>>? _allRecipesInFlight;
  String? _inFlightUserId;
  int _cacheGeneration = 0;

  /// Drop the cached recipe list after a write so the next read refetches.
  void _invalidateRecipes() {
    _cacheGeneration++;
    _allRecipes = null;
    _allRecipesAt = null;
    _allRecipesInFlight = null;
  }

  /// All recipes, newest first. Returns an empty list on error.
  ///
  /// Each call returns a fresh list, so callers may sort it in place.
  Future<List<Recipe>> getRecipes() async {
    final userId = _supabase.auth.currentUser?.id;
    final cached = _allRecipes;
    final cachedAt = _allRecipesAt;
    if (cached != null &&
        cachedAt != null &&
        _allRecipesUserId == userId &&
        DateTime.now().difference(cachedAt) < _allRecipesTtl) {
      return List.of(cached);
    }

    var inFlight = _allRecipesInFlight;
    if (inFlight == null || _inFlightUserId != userId) {
      _inFlightUserId = userId;
      inFlight = _allRecipesInFlight = _fetchAllRecipes(userId);
    }
    return List.of(await inFlight);
  }

  Future<List<Recipe>> _fetchAllRecipes(String? userId) async {
    final generation = _cacheGeneration;
    try {
      final rows = await _supabase
          .from('recipes')
          .select(_recipeSelect)
          .order('created_at', ascending: false);
      final recipes = await _hydrate(rows, userId);

      if (generation == _cacheGeneration) {
        _allRecipes = List.unmodifiable(recipes);
        _allRecipesAt = DateTime.now();
        _allRecipesUserId = userId;
        // Feeds the Recipes tab's first-frame paint on the next cold start.
        unawaited(OfflineCacheService.instance.cacheRecipes(recipes));
      }
      return recipes;
    } catch (e) {
      // If error (e.g., no internet), return empty list
      debugPrint('❌ [RECIPE_SERVICE] Failed to get recipes: $e');
      return [];
    } finally {
      if (generation == _cacheGeneration) _allRecipesInFlight = null;
    }
  }

  /// Turns raw `recipes` rows (selected with [_recipeSelect]) into [Recipe]s:
  /// joins the current author name/avatar from `users` (one query for all
  /// rows) and folds the embedded ratings into average, count and the
  /// current user's own rating.
  Future<List<Recipe>> _hydrate(List<dynamic> rows, String? userId) async {
    if (rows.isEmpty) return [];

    final authorIds = <String>{
      for (final row in rows)
        if (row['author_id'] is String) row['author_id'] as String,
    };
    final authors = <String, Map<String, dynamic>>{};
    if (authorIds.isNotEmpty) {
      try {
        final users = await _supabase
            .from('users')
            .select('id, display_name, avatar_url')
            .inFilter('id', authorIds.toList());
        for (final user in users) {
          authors[user['id'] as String] = user;
        }
      } catch (e) {
        debugPrint('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
      }
    }

    return [
      for (final row in rows)
        _recipeFromRow(
          row as Map<String, dynamic>,
          authors[row['author_id']],
          userId,
        ),
    ];
  }

  Recipe _recipeFromRow(
    Map<String, dynamic> json,
    Map<String, dynamic>? author,
    String? userId,
  ) {
    final ratings = (json['recipe_ratings'] as List?) ?? const [];
    final ratingCount = ratings.length;
    final averageRating = ratingCount > 0
        ? ratings.fold<double>(
                0, (sum, r) => sum + (r['rating'] as num).toDouble()) /
            ratingCount
        : 0.0;
    int? userRating;
    if (userId != null) {
      for (final r in ratings) {
        if (r['user_id'] == userId) {
          userRating = r['rating'] as int?;
          break;
        }
      }
    }

    // Prefer the author's current profile, fall back to the stored copy.
    return Recipe.fromJson({
      ...json,
      'author_name': author?['display_name'] as String? ??
          json['author_name'] as String? ??
          'Unknown',
      'author_avatar_url':
          author?['avatar_url'] as String? ?? json['author_avatar_url'] as String?,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'user_rating': userRating,
    });
  }

  // ========== SINGLE RECIPE ==========

  /// Get recipe by ID. Does not count a view — call [trackRecipeView] from
  /// the screen that actually shows the recipe.
  Future<Recipe> getRecipeById(String id) async {
    if (id.isEmpty) {
      throw Exception('Recipe ID is empty');
    }

    final row = await _supabase
        .from('recipes')
        .select(_recipeSelect)
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      throw Exception('Recipe not found with ID: $id');
    }

    final recipes = await _hydrate([row], _supabase.auth.currentUser?.id);
    return recipes.first;
  }

  /// Count one view of a recipe (fire and forget; failures are ignored).
  Future<void> trackRecipeView(String recipeId) async {
    try {
      await _supabase.rpc('increment_recipe_view_count', params: {
        'recipe_id': recipeId,
      });
    } catch (e) {
      debugPrint('⚠️ [RECIPE_SERVICE] Could not track view: $e');
    }
  }

  /// Create new recipe
  Future<Recipe> createRecipe(Recipe recipe) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    debugPrint('📝 [RECIPE_SERVICE] Creating recipe: ${recipe.name}');

    // Get user's display name from users table
    String authorName = user.email ?? 'Anonymous';
    String? authorAvatarUrl;
    try {
      final userProfile = await _supabase
          .from('users')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (userProfile != null) {
        authorName = userProfile['display_name'] as String? ?? authorName;
        authorAvatarUrl = userProfile['avatar_url'] as String?;
      }
    } catch (_) {
      // Use email as fallback
    }

    // Auto-categorize recipe if no labels provided
    final ingredientMaps = recipe.ingredients.map((i) => i.toJson()).toList();
    final labels = recipe.labels.isNotEmpty
        ? recipe.labels
        : autoLabelRecipe(
            name: recipe.name,
            description: recipe.description,
            ingredients: ingredientMaps,
            prepTime: recipe.prepTimeMinutes,
            cookTime: recipe.cookTimeMinutes,
          );

    try {
      final response = await _supabase
          .from('recipes')
          .insert({
            'name': recipe.name,
            'description': recipe.description,
            'image_url': recipe.imageUrl,
            'prep_time_minutes': recipe.prepTimeMinutes,
            'cook_time_minutes': recipe.cookTimeMinutes,
            'default_servings': recipe.defaultServings,
            'ingredients': ingredientMaps,
            'instructions': recipe.instructions,
            'author_id': user.id,
            'author_name': authorName,
            'author_avatar_url': authorAvatarUrl,
            'labels': labels,
            'view_count': 0,
          })
          .select()
          .single();

      _invalidateRecipes();
      debugPrint('✅ [RECIPE_SERVICE] Recipe created: ${response['id']}');
      return Recipe.fromJson(response);
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to create recipe: $e');
      rethrow;
    }
  }

  /// Delete recipe (only by author)
  Future<void> deleteRecipe(String recipeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First verify the user is the author
      final recipe = await _supabase
          .from('recipes')
          .select('author_id')
          .eq('id', recipeId)
          .single();

      if (recipe['author_id'] != user.id) {
        throw Exception('You can only delete your own recipes');
      }

      // Delete dependent rows first (foreign key constraints)
      await Future.wait([
        _supabase.from('recipe_ratings').delete().eq('recipe_id', recipeId),
        _supabase.from('saved_recipes').delete().eq('recipe_id', recipeId),
      ]);

      await _supabase.from('recipes').delete().eq('id', recipeId);

      _invalidateRecipes();
      debugPrint('✅ [RECIPE_SERVICE] Recipe deleted: $recipeId');
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to delete recipe: $e');
      rethrow;
    }
  }

  /// Update existing recipe (only by author)
  Future<void> updateRecipe(
    String recipeId, {
    String? name,
    String? description,
    String? imageUrl,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? defaultServings,
    List<Ingredient>? ingredients,
    List<String>? instructions,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Verify the user is the author; also read the fields needed to
      // re-label the recipe, so no second fetch is required.
      final current = await _supabase
          .from('recipes')
          .select(
              'author_id, name, description, ingredients, prep_time_minutes, cook_time_minutes')
          .eq('id', recipeId)
          .single();

      if (current['author_id'] != user.id) {
        throw Exception('You can only edit your own recipes');
      }

      final ingredientMaps = ingredients?.map((i) => i.toJson()).toList();
      final updateData = <String, dynamic>{
        'name': ?name,
        'description': ?description,
        'image_url': ?imageUrl,
        'prep_time_minutes': ?prepTimeMinutes,
        'cook_time_minutes': ?cookTimeMinutes,
        'default_servings': ?defaultServings,
        'ingredients': ?ingredientMaps,
        'instructions': ?instructions,
      };

      // Re-label if name or ingredients changed
      if (name != null || ingredients != null) {
        updateData['labels'] = autoLabelRecipe(
          name: name ?? current['name'] as String? ?? '',
          description:
              description ?? current['description'] as String? ?? '',
          ingredients:
              ingredientMaps ?? (current['ingredients'] as List?) ?? const [],
          prepTime: prepTimeMinutes ?? current['prep_time_minutes'] as int?,
          cookTime: cookTimeMinutes ?? current['cook_time_minutes'] as int?,
        );
      }

      await _supabase.from('recipes').update(updateData).eq('id', recipeId);

      _invalidateRecipes();
      debugPrint('✅ [RECIPE_SERVICE] Recipe updated: $recipeId');
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to update recipe: $e');
      rethrow;
    }
  }

  // ========== RATINGS ==========

  /// Rate recipe (1-5 stars). The author gets a push for a first rating.
  Future<void> rateRecipe(String recipeId, int rating) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    // Is this a new rating (not an update)? Fetch the recipe for the push
    // notification in the same round trip.
    final lookups = await Future.wait([
      _supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', recipeId)
          .eq('user_id', userId)
          .maybeSingle(),
      _supabase
          .from('recipes')
          .select('name, author_id')
          .eq('id', recipeId)
          .maybeSingle(),
    ]);
    final isNewRating = lookups[0] == null;
    final recipeRow = lookups[1];

    await _supabase.from('recipe_ratings').upsert(
      {
        'recipe_id': recipeId,
        'user_id': userId,
        'rating': rating,
      },
      onConflict: 'recipe_id,user_id',
    );
    _invalidateRecipes();

    debugPrint(
        '✅ [RECIPE_SERVICE] Rating ${isNewRating ? 'added' : 'updated'}: $rating stars for recipe $recipeId');

    // Notify the author (not self) about new ratings only.
    final authorId = recipeRow?['author_id'] as String?;
    if (isNewRating && recipeRow != null && authorId != null && authorId != userId) {
      final recipeName = recipeRow['name'] as String? ?? '';
      final raterName = _supabase.auth.currentUser?.userMetadata?['display_name']
              as String? ??
          'Someone';
      unawaited(PushNotificationService.instance.sendToUsers(
        userIds: [authorId],
        title: 'New Rating!',
        body: '$raterName rated "$recipeName" ${'⭐' * rating} ($rating/5)',
        data: {
          'type': 'recipe_rating',
          // Tap handlers (NavigationService.handleNotificationData) read
          // 'recipeId'.
          'recipeId': recipeId,
        },
      ));
    }
  }

  // ========== SHARING / IMAGES ==========

  /// Get share text with recipe details
  String getShareText(Recipe recipe) {
    final webLink = 'https://shoplyai.app/recipe/${recipe.id}';
    return '🍳 Check out this recipe: ${recipe.name}\n\n'
        '⏱ Ready in ${recipe.totalTimeMinutes} min\n'
        '⭐ ${recipe.averageRating.toStringAsFixed(1)} rating\n\n'
        '$webLink';
  }

  /// Upload recipe image
  Future<String> uploadRecipeImage(String filePath, String fileName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final path = 'recipes/$userId/$fileName';
    await _supabase.storage.from('recipe-images').upload(
          path,
          File(filePath),
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('recipe-images').getPublicUrl(path);
  }

  // ========== SEARCH ==========

  /// Search recipes - searches name, description, labels, author name, and
  /// ingredients. Sorted by rating (highest first).
  Future<List<Recipe>> searchRecipes(String query) async {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) return [];

    final allRecipes = await getRecipes();
    final results = allRecipes.where((recipe) {
      return recipe.name.toLowerCase().contains(queryLower) ||
          recipe.description.toLowerCase().contains(queryLower) ||
          recipe.authorName.toLowerCase().contains(queryLower) ||
          recipe.labels.any((l) => l.toLowerCase().contains(queryLower)) ||
          recipe.ingredients
              .any((ing) => ing.name.toLowerCase().contains(queryLower));
    }).toList()
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return results;
  }

  // ========== SAVED RECIPES (BOOKMARKS) ==========

  /// Save a recipe (bookmark)
  Future<bool> saveRecipe(String recipeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('❌ [RECIPE_SERVICE] Cannot save - user not logged in');
      return false;
    }

    try {
      await _supabase.from('saved_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });
      return true;
    } on PostgrestException catch (e) {
      // Already saved is fine
      if (e.code == '23505') return true;
      debugPrint(
          '❌ [RECIPE_SERVICE] Failed to save recipe: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to save recipe: $e');
      return false;
    }
  }

  /// Unsave a recipe (remove bookmark)
  Future<bool> unsaveRecipe(String recipeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('saved_recipes')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_id', recipeId);
      return true;
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to unsave recipe: $e');
      return false;
    }
  }

  /// Get all saved recipes for current user, most recently saved first.
  Future<List<Recipe>> getSavedRecipes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final saved = await _supabase
          .from('saved_recipes')
          .select('recipe_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final savedRecipeIds = [
        for (final r in saved)
          if (r['recipe_id'] != null) r['recipe_id'] as String,
      ];
      if (savedRecipeIds.isEmpty) return [];

      final rows = await _supabase
          .from('recipes')
          .select(_recipeSelect)
          .inFilter('id', savedRecipeIds);
      final recipes = await _hydrate(rows, userId);

      // Sort by saved order
      final order = {
        for (var i = 0; i < savedRecipeIds.length; i++) savedRecipeIds[i]: i,
      };
      recipes.sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
      return recipes;
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to get saved recipes: $e');
      return [];
    }
  }

  /// Get saved recipe IDs for current user (for quick checks)
  Future<Set<String>> getSavedRecipeIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase
          .from('saved_recipes')
          .select('recipe_id')
          .eq('user_id', userId);

      return {for (final r in response) r['recipe_id'] as String};
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to get saved recipe IDs: $e');
      return {};
    }
  }

  // ========== USER RECIPES ==========

  /// Get recipes created by current user
  Future<List<Recipe>> getMyRecipes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _supabase
          .from('recipes')
          .select(_recipeSelect)
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      return await _hydrate(rows, userId);
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to get my recipes: $e');
      return [];
    }
  }

  // ========== POPULAR / FEATURED ==========

  /// For small recipe counts, show at most half of the recipes (min 1), so
  /// a section never lists everything.
  static int _effectiveLimit(int total, int limit) {
    return total <= limit * 2 ? (total / 2).ceil().clamp(1, limit) : limit;
  }

  /// Get popular recipes.
  ///
  /// With [thisWeekOnly], ranks by number (then average) of ratings given in
  /// the last 7 days. Otherwise, or when there were no ratings this week,
  /// ranks all recipes by views, average rating and rating count.
  Future<List<Recipe>> getPopularRecipes({
    int limit = 10,
    bool thisWeekOnly = false,
  }) async {
    try {
      final allRecipesFuture = getRecipes();

      if (thisWeekOnly) {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final response = await _supabase
            .from('recipe_ratings')
            .select('recipe_id, rating')
            .gte('created_at', weekAgo.toIso8601String());

        if (response.isNotEmpty) {
          final weeklyRatings = <String, List<int>>{};
          for (final rating in response) {
            weeklyRatings
                .putIfAbsent(rating['recipe_id'] as String, () => [])
                .add(rating['rating'] as int);
          }

          // Sort by weekly rating count, then by average
          final sorted = weeklyRatings.entries.toList()
            ..sort((a, b) {
              final countCompare = b.value.length.compareTo(a.value.length);
              if (countCompare != 0) return countCompare;
              final avgA = a.value.reduce((x, y) => x + y) / a.value.length;
              final avgB = b.value.reduce((x, y) => x + y) / b.value.length;
              return avgB.compareTo(avgA);
            });
          final topIds = sorted.take(limit).map((e) => e.key).toList();

          final byId = {for (final r in await allRecipesFuture) r.id: r};
          return [
            for (final id in topIds)
              if (byId[id] != null) byId[id]!,
          ];
        }
      }

      // All-time popularity: (views * 0.1) + (avg rating * 20) + (ratings * 2)
      double score(Recipe r) =>
          (r.viewCount * 0.1) + (r.averageRating * 20) + (r.ratingCount * 2);
      final allRecipes = await allRecipesFuture
        ..sort((a, b) => score(b).compareTo(score(a)));
      return allRecipes
          .take(_effectiveLimit(allRecipes.length, limit))
          .toList();
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to get popular recipes: $e');
      return [];
    }
  }

  /// Get recently added recipes
  Future<List<Recipe>> getRecentRecipes({int limit = 10}) async {
    final allRecipes = await getRecipes()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allRecipes.take(_effectiveLimit(allRecipes.length, limit)).toList();
  }

  /// Get recipes by category/label
  Future<List<Recipe>> getRecipesByCategory(String category) async {
    final categoryLower = category.toLowerCase();
    final allRecipes = await getRecipes();
    return allRecipes
        .where((recipe) => recipe.labels
            .any((label) => label.toLowerCase().contains(categoryLower)))
        .toList();
  }

  /// Get unique authors with recipe counts, ranked by
  /// (recipes * 10) + (views * 0.1) + (ratings * 2) + (avg rating * 5).
  Future<List<Map<String, dynamic>>> getTopAuthors({int limit = 10}) async {
    final allRecipes = await getRecipes();

    final authorMap = <String, Map<String, dynamic>>{};
    for (final recipe in allRecipes) {
      final author = authorMap.putIfAbsent(
        recipe.authorId,
        () => {
          'authorId': recipe.authorId,
          'authorName': recipe.authorName,
          'authorAvatarUrl': recipe.authorAvatarUrl,
          'recipeCount': 0,
          'totalRating': 0.0,
          'ratedRecipes': 0,
          'totalViews': 0,
          'totalRatingCount': 0,
        },
      );
      author['recipeCount'] = (author['recipeCount'] as int) + 1;
      author['totalViews'] = (author['totalViews'] as int) + recipe.viewCount;
      author['totalRatingCount'] =
          (author['totalRatingCount'] as int) + recipe.ratingCount;
      if (recipe.ratingCount > 0) {
        author['totalRating'] =
            (author['totalRating'] as double) + recipe.averageRating;
        author['ratedRecipes'] = (author['ratedRecipes'] as int) + 1;
      }
    }

    final authors = authorMap.values.map((author) {
      final ratedRecipes = author['ratedRecipes'] as int;
      final avgRating = ratedRecipes > 0
          ? (author['totalRating'] as double) / ratedRecipes
          : 0.0;
      author['averageRating'] = avgRating;
      author['score'] = ((author['recipeCount'] as int) * 10) +
          ((author['totalViews'] as int) * 0.1) +
          ((author['totalRatingCount'] as int) * 2) +
          (avgRating * 5);
      return author;
    }).toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return authors.take(limit).toList();
  }

  /// Search authors by name
  Future<List<Map<String, dynamic>>> searchAuthors(String query) async {
    final queryLower = query.toLowerCase();
    final allRecipes = await getRecipes();

    final authorMap = <String, Map<String, dynamic>>{};
    for (final recipe in allRecipes) {
      if (!recipe.authorName.toLowerCase().contains(queryLower)) continue;
      final author = authorMap.putIfAbsent(
        recipe.authorId,
        () => {
          'authorId': recipe.authorId,
          'authorName': recipe.authorName,
          'authorAvatarUrl': recipe.authorAvatarUrl,
          'recipeCount': 0,
        },
      );
      author['recipeCount'] = (author['recipeCount'] as int) + 1;
    }
    return authorMap.values.toList();
  }

  /// All recipes by [authorId], newest first, with ratings and author info.
  Future<List<Recipe>> getRecipesByAuthor(String authorId) async {
    try {
      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_ratings!left(user_id, rating)
          ''')
          .eq('author_id', authorId)
          .order('created_at', ascending: false);

      // Fetch author display name
      Map<String, Map<String, dynamic>> authorData = {};
      try {
        final usersResponse = await _supabase
            .from('users')
            .select('id, display_name, avatar_url')
            .eq('id', authorId);
        
        for (final user in usersResponse as List) {
          authorData[user['id'] as String] = user;
        }
      } catch (e) {
        debugPrint('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
      }

      final recipes = (response as List).map((json) {
        final ratings = (json['recipe_ratings'] as List?) ?? [];
        final ratingCount = ratings.length;
        final averageRating = ratingCount > 0
            ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
            : 0.0;
        
        // Get author name from users table, fallback to stored author_name
        final recipeAuthorId = json['author_id'] as String?;
        final userData = recipeAuthorId != null ? authorData[recipeAuthorId] : null;
        final authorName = userData?['display_name'] as String? ?? json['author_name'] as String? ?? 'Unknown';
        final authorAvatarUrl = userData?['avatar_url'] as String? ?? json['author_avatar_url'] as String?;

        return Recipe.fromJson({
          ...json,
          'author_name': authorName,
          'author_avatar_url': authorAvatarUrl,
          'average_rating': averageRating,
          'rating_count': ratingCount,
        });
      }).toList();

      return recipes;
    } catch (e) {
      debugPrint('❌ [RECIPE_SERVICE] Failed to get recipes by author: $e');
      return [];
    }
  }
}
