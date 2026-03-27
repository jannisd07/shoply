import 'dart:io';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_comment.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/push_notification_service.dart';
// Sample recipes removed - all recipes are now in database
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper class for keyword-based category scoring
class _KeywordWeight {
  final String keyword;
  final int weight;
  const _KeywordWeight(this.keyword, this.weight);
}

class RecipeService {
  static final RecipeService instance = RecipeService();
  final _supabase = SupabaseService.instance.client;
  
  /// Expose supabase client for direct queries when needed
  SupabaseClient get supabase => _supabase;
  
  /// Auto-categorize recipe based on name, description, and ingredients
  /// Returns a list of 1-3 best-fitting category labels
  /// Uses keyword scoring: 1 category most likely, 2 okay, 3 almost never
  /// 
  /// **IMPORTANT**: Label IDs must match QuickFilters in recipe_filter.dart:
  /// - Cuisine: italian, asian, mexican, mediterranean
  /// - Diet: vegetarian, vegan, gluten-free, keto, low-carb
  /// - Meal: breakfast, lunch, dinner, snack
  /// - Time: quick, 30min, under-hour
  /// - Difficulty: easy, medium, advanced
  /// - Other: healthy, comfort-food, seafood, soup
  List<String> _autoCategorizeRecipe({
    required String name,
    required String description,
    required List<dynamic> ingredients,
    int? prepTime,
    int? cookTime,
  }) {
    final ingredientNames = ingredients.map((i) => i is Map ? (i['name'] ?? '').toString() : i.toString()).join(' ');
    final searchText = '$name $description $ingredientNames'.toLowerCase();
    
    // Category keywords mapping with weights - more specific keywords have higher weight
    // Format: categoryId -> List of (keyword, weight) pairs
    final categoryKeywords = <String, List<_KeywordWeight>>{
      // Cuisine types - high specificity
      'italian': [
        _KeywordWeight('pasta', 3), _KeywordWeight('pizza', 3), _KeywordWeight('risotto', 3),
        _KeywordWeight('lasagne', 3), _KeywordWeight('italienisch', 3), _KeywordWeight('italian', 3),
        _KeywordWeight('spaghetti', 3), _KeywordWeight('carbonara', 3), _KeywordWeight('bolognese', 3),
        _KeywordWeight('pesto', 2), _KeywordWeight('mozzarella', 2), _KeywordWeight('parmesan', 1),
        _KeywordWeight('tiramisu', 3), _KeywordWeight('gnocchi', 3), _KeywordWeight('ravioli', 3),
        _KeywordWeight('bruschetta', 3), _KeywordWeight('parmigiana', 3),
      ],
      'asian': [
        _KeywordWeight('asiatisch', 3), _KeywordWeight('chinese', 3), _KeywordWeight('chinesisch', 3),
        _KeywordWeight('japanese', 3), _KeywordWeight('japanisch', 3), _KeywordWeight('thai', 3),
        _KeywordWeight('vietnamese', 3), _KeywordWeight('korean', 3), _KeywordWeight('sushi', 3),
        _KeywordWeight('wok', 2), _KeywordWeight('curry', 2), _KeywordWeight('teriyaki', 3),
        _KeywordWeight('ramen', 3), _KeywordWeight('pho', 3), _KeywordWeight('pad thai', 3),
        _KeywordWeight('gyoza', 3), _KeywordWeight('miso', 2), _KeywordWeight('kimchi', 3),
        _KeywordWeight('sojasauce', 2), _KeywordWeight('soy sauce', 2), _KeywordWeight('tofu', 2),
      ],
      'mexican': [
        _KeywordWeight('mexican', 3), _KeywordWeight('mexikanisch', 3), _KeywordWeight('taco', 3),
        _KeywordWeight('burrito', 3), _KeywordWeight('enchilada', 3), _KeywordWeight('tex-mex', 3),
        _KeywordWeight('quesadilla', 3), _KeywordWeight('fajita', 3), _KeywordWeight('nachos', 3),
        _KeywordWeight('guacamole', 2), _KeywordWeight('salsa', 1), _KeywordWeight('tortilla', 2),
        _KeywordWeight('jalapeño', 2), _KeywordWeight('chimichanga', 3), _KeywordWeight('churro', 3),
      ],
      'mediterranean': [
        _KeywordWeight('mediterran', 3), _KeywordWeight('mediterranean', 3), _KeywordWeight('greek', 3),
        _KeywordWeight('griechisch', 3), _KeywordWeight('hummus', 3), _KeywordWeight('falafel', 3),
        _KeywordWeight('tzatziki', 3), _KeywordWeight('feta', 2), _KeywordWeight('pita', 2),
        _KeywordWeight('couscous', 3), _KeywordWeight('tabouleh', 3), _KeywordWeight('shakshuka', 3),
      ],
      
      // Meal types - moderate specificity
      'breakfast': [
        _KeywordWeight('frühstück', 3), _KeywordWeight('breakfast', 3), _KeywordWeight('brunch', 3),
        _KeywordWeight('pancake', 3), _KeywordWeight('pfannkuchen', 3), _KeywordWeight('omelette', 3),
        _KeywordWeight('müsli', 3), _KeywordWeight('granola', 3), _KeywordWeight('porridge', 3),
        _KeywordWeight('waffel', 3), _KeywordWeight('waffle', 3), _KeywordWeight('croissant', 3),
        _KeywordWeight('french toast', 3),
      ],
      'snack': [
        _KeywordWeight('snack', 3), _KeywordWeight('dessert', 3), _KeywordWeight('nachtisch', 3),
        _KeywordWeight('kuchen', 3), _KeywordWeight('cake', 3), _KeywordWeight('torte', 3),
        _KeywordWeight('brownie', 3), _KeywordWeight('cookie', 3), _KeywordWeight('keks', 3),
        _KeywordWeight('muffin', 3), _KeywordWeight('cupcake', 3), _KeywordWeight('cheesecake', 3),
        _KeywordWeight('eis', 2), _KeywordWeight('ice cream', 3), _KeywordWeight('pudding', 3),
      ],
      
      // Style categories
      'healthy': [
        _KeywordWeight('gesund', 3), _KeywordWeight('healthy', 3), _KeywordWeight('light', 2),
        _KeywordWeight('salat', 2), _KeywordWeight('salad', 2), _KeywordWeight('superfood', 3),
        _KeywordWeight('quinoa', 2), _KeywordWeight('bowl', 2), _KeywordWeight('smoothie', 3),
        _KeywordWeight('low-cal', 3), _KeywordWeight('kalorienarm', 3),
      ],
      'comfort-food': [
        _KeywordWeight('comfort', 3), _KeywordWeight('herzhaft', 2), _KeywordWeight('soul food', 3),
        _KeywordWeight('eintopf', 3), _KeywordWeight('stew', 2), _KeywordWeight('auflauf', 3),
        _KeywordWeight('gratin', 3), _KeywordWeight('mac and cheese', 3), _KeywordWeight('käsespätzle', 3),
        _KeywordWeight('schnitzel', 3), _KeywordWeight('braten', 2),
      ],
      'seafood': [
        _KeywordWeight('seafood', 3), _KeywordWeight('meeresfrüchte', 3), _KeywordWeight('fish', 2),
        _KeywordWeight('fisch', 2), _KeywordWeight('shrimp', 3), _KeywordWeight('garnelen', 3),
        _KeywordWeight('salmon', 3), _KeywordWeight('lachs', 3), _KeywordWeight('tuna', 3),
        _KeywordWeight('thunfisch', 3), _KeywordWeight('lobster', 3), _KeywordWeight('hummer', 3),
        _KeywordWeight('muscheln', 3), _KeywordWeight('mussels', 3),
      ],
      'soup': [
        _KeywordWeight('soup', 3), _KeywordWeight('suppe', 3), _KeywordWeight('brühe', 2),
        _KeywordWeight('chowder', 3), _KeywordWeight('bisque', 3), _KeywordWeight('gazpacho', 3),
        _KeywordWeight('minestrone', 3),
      ],
      
      // Diet types - only add if explicitly mentioned
      'vegetarian': [
        _KeywordWeight('vegetarisch', 3), _KeywordWeight('vegetarian', 3), _KeywordWeight('veggie', 2),
      ],
      'vegan': [
        _KeywordWeight('vegan', 3), _KeywordWeight('pflanzlich', 2), _KeywordWeight('plant-based', 3),
      ],
      'gluten-free': [
        _KeywordWeight('glutenfrei', 3), _KeywordWeight('gluten-free', 3), _KeywordWeight('gluten free', 3),
      ],
    };
    
    // Calculate score for each category
    final categoryScores = <String, int>{};
    
    for (final entry in categoryKeywords.entries) {
      final categoryId = entry.key;
      final keywords = entry.value;
      int score = 0;
      
      for (final kw in keywords) {
        if (searchText.contains(kw.keyword)) {
          score += kw.weight;
        }
      }
      
      if (score > 0) {
        categoryScores[categoryId] = score;
      }
    }
    
    // Sort categories by score (highest first)
    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take only the top 1-3 categories
    // - Always take the top category if score >= 2
    // - Take 2nd category only if score >= 3
    // - Take 3rd category only if score >= 4 (very rarely)
    final labels = <String>[];
    
    for (int i = 0; i < sortedCategories.length && labels.length < 3; i++) {
      final entry = sortedCategories[i];
      final minScore = i == 0 ? 2 : (i == 1 ? 3 : 4);
      
      if (entry.value >= minScore) {
        labels.add(entry.key);
      }
    }
    
    // If no categories matched, add a default based on time/ingredients
    if (labels.isEmpty) {
      final totalTime = (prepTime ?? 0) + (cookTime ?? 0);
      final ingredientCount = ingredients.length;
      
      if (totalTime >= 45 || ingredientCount >= 10) {
        labels.add('comfort-food');
      } else {
        labels.add('healthy');
      }
    }
    
    print('🏷️ [RECIPE_SERVICE] Auto-categorized recipe "$name" with ${labels.length} labels: $labels (scores: $categoryScores)');
    return labels;
  }
  
  /// Update all existing recipes with auto-generated labels
  /// Call this once to backfill labels for existing recipes
  Future<int> updateAllRecipesWithLabels() async {
    try {
      print('🔄 [RECIPE_SERVICE] Starting to update all recipes with labels...');
      
      // Get all recipes
      final response = await _supabase
          .from('recipes')
          .select('id, name, description, ingredients, prep_time_minutes, cook_time_minutes, labels');
      
      int updatedCount = 0;
      
      for (final recipe in response as List) {
        final currentLabels = (recipe['labels'] as List?) ?? [];
        
        // Skip if already has labels
        if (currentLabels.isNotEmpty) {
          print('⏭️ Skipping ${recipe['name']} - already has labels: $currentLabels');
          continue;
        }
        
        // Generate labels
        final newLabels = _autoCategorizeRecipe(
          name: recipe['name'] ?? '',
          description: recipe['description'] ?? '',
          ingredients: (recipe['ingredients'] as List?) ?? [],
          prepTime: recipe['prep_time_minutes'] as int?,
          cookTime: recipe['cook_time_minutes'] as int?,
        );
        
        // Update recipe
        await _supabase
            .from('recipes')
            .update({'labels': newLabels})
            .eq('id', recipe['id']);
        
        print('✅ Updated "${recipe['name']}" with labels: $newLabels');
        updatedCount++;
      }
      
      print('🎉 [RECIPE_SERVICE] Updated $updatedCount recipes with labels');
      return updatedCount;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to update recipes with labels: $e');
      return 0;
    }
  }

  /// Fix recipes that have more than 3 categories by re-categorizing them
  /// This ensures all recipes have max 3 categories (usually 1-2)
  Future<int> fixRecipesWithTooManyCategories() async {
    try {
      print('🔧 [RECIPE_SERVICE] Fixing recipes with too many categories...');
      
      // Get all recipes
      final response = await _supabase
          .from('recipes')
          .select('id, name, description, ingredients, prep_time_minutes, cook_time_minutes, labels');
      
      int fixedCount = 0;
      
      for (final recipe in response as List) {
        final currentLabels = (recipe['labels'] as List?) ?? [];
        
        // Only fix recipes with more than 3 labels
        if (currentLabels.length <= 3) {
          continue;
        }
        
        print('🔄 Fixing "${recipe['name']}" - has ${currentLabels.length} labels: $currentLabels');
        
        // Re-generate labels with proper limits
        final newLabels = _autoCategorizeRecipe(
          name: recipe['name'] ?? '',
          description: recipe['description'] ?? '',
          ingredients: (recipe['ingredients'] as List?) ?? [],
          prepTime: recipe['prep_time_minutes'] as int?,
          cookTime: recipe['cook_time_minutes'] as int?,
        );
        
        // Update recipe
        await _supabase
            .from('recipes')
            .update({'labels': newLabels})
            .eq('id', recipe['id']);
        
        print('✅ Fixed "${recipe['name']}" - now has ${newLabels.length} labels: $newLabels');
        fixedCount++;
      }
      
      print('🎉 [RECIPE_SERVICE] Fixed $fixedCount recipes with too many categories');
      return fixedCount;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to fix recipes: $e');
      return 0;
    }
  }

  /// Get all recipes (includes sample recipes if database is empty)
  Future<List<Recipe>> getRecipes() async {
    try {
      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_ratings!left(user_id, rating)
          ''')
          .order('created_at', ascending: false);

      final userId = _supabase.auth.currentUser?.id;
      
      // Collect all unique author IDs to fetch display names
      final authorIds = <String>{};
      for (final json in response as List) {
        final authorId = json['author_id'] as String?;
        if (authorId != null) authorIds.add(authorId);
      }
      
      // Fetch all authors in one query
      Map<String, Map<String, dynamic>> authorData = {};
      if (authorIds.isNotEmpty) {
        try {
          final usersResponse = await _supabase
              .from('users')
              .select('id, display_name, avatar_url')
              .inFilter('id', authorIds.toList());
          
          for (final user in usersResponse as List) {
            authorData[user['id'] as String] = user;
          }
        } catch (e) {
          print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
        }
      }
      
      final recipes = (response as List).map((json) {
        final ratings = (json['recipe_ratings'] as List?) ?? [];
        final ratingCount = ratings.length;
        final averageRating = ratingCount > 0
            ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
            : 0.0;
        int? userRating;
        if (userId != null && ratings.isNotEmpty) {
          try {
            final userRatingData = ratings.firstWhere(
              (r) => r['user_id'] == userId,
            );
            userRating = userRatingData['rating'] as int?;
          } catch (e) {
            userRating = null;
          }
        }
        
        // Get author name from users table, fallback to stored author_name
        final authorId = json['author_id'] as String?;
        final userData = authorId != null ? authorData[authorId] : null;
        final authorName = userData?['display_name'] as String? ?? json['author_name'] as String? ?? 'Unknown';
        final authorAvatarUrl = userData?['avatar_url'] as String? ?? json['author_avatar_url'] as String?;

        return Recipe.fromJson({
          ...json,
          'author_name': authorName,
          'author_avatar_url': authorAvatarUrl,
          'average_rating': averageRating,
          'rating_count': ratingCount,
          'user_rating': userRating,
        });
      }).toList();

      return recipes;
    } catch (e) {
      // If error (e.g., no internet), return empty list
      print('❌ [RECIPE_SERVICE] Failed to get recipes: $e');
      return [];
    }
  }

  /// Get ONLY database recipes (excludes sample recipes)
  /// Use this for admin operations like batch labeling
  Future<List<Recipe>> getDatabaseRecipesOnly() async {
    try {
      
      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_likes!left(user_id)
          ''')
          .order('created_at', ascending: false);

      
      final userId = _supabase.auth.currentUser?.id;
      
      final recipes = (response as List).map((json) {
        final likes = (json['recipe_likes'] as List?)?.length ?? 0;
        final isLiked = userId != null &&
            (json['recipe_likes'] as List?)
                ?.any((like) => like['user_id'] == userId) ==
            true;

        return Recipe.fromJson({
          ...json,
          'likes': likes,
          'is_liked_by_user': isLiked,
        });
      }).toList();

      
      // DO NOT include sample recipes - return only database recipes
      return recipes;
    } catch (e, stackTrace) {
      // Return empty list on error (don't return sample recipes)
      return [];
    }
  }

  /// Get recipe by ID
  Future<Recipe> getRecipeById(String id) async {
    print('🔎 [RECIPE_SERVICE] getRecipeById called with ID: $id');
    print('📏 [RECIPE_SERVICE] ID length: ${id.length}');
    print('📝 [RECIPE_SERVICE] ID type: ${id.runtimeType}');
    
    if (id.isEmpty) {
      throw Exception('Recipe ID is empty');
    }
    
    try {
      print('📡 [RECIPE_SERVICE] Querying database for recipe with ID: $id');
      
      // Query the recipe with ratings
      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_ratings!left(user_id, rating)
          ''')
          .eq('id', id)
          .maybeSingle(); // Use maybeSingle instead of single to avoid exception

      if (response == null) {
        print('⚠️ [RECIPE_SERVICE] Recipe not found in database with ID: $id');
        
        // Debug: Show all recipes in database
        final allRecipes = await _supabase
            .from('recipes')
            .select('id, name, author_id')
            .limit(20);
        print('📚 [RECIPE_SERVICE] Total recipes in database: ${(allRecipes as List).length}');
        for (var r in allRecipes) {
          print('   - ID: ${r['id']} | Name: ${r['name']} | Author: ${r['author_id']}');
        }
        
        throw Exception('Recipe not found with ID: $id');
      }

      print('✅ [RECIPE_SERVICE] Recipe found in database: ${response['name']}');
      
      // Fetch author data separately
      String authorName = response['author_name'] as String? ?? 'Unknown';
      String? authorAvatarUrl = response['author_avatar_url'] as String?;
      final authorId = response['author_id'] as String?;
      
      if (authorId != null) {
        try {
          final userData = await _supabase
              .from('users')
              .select('display_name, avatar_url')
              .eq('id', authorId)
              .maybeSingle();
          
          if (userData != null) {
            authorName = userData['display_name'] as String? ?? authorName;
            authorAvatarUrl = userData['avatar_url'] as String? ?? authorAvatarUrl;
          }
        } catch (e) {
          print('⚠️ [RECIPE_SERVICE] Could not fetch author data: $e');
        }
      }
      
      final userId = _supabase.auth.currentUser?.id;
      final ratingsList = (response['recipe_ratings'] as List?) ?? [];
      final ratings = ratingsList.length;
      print('📊 [RECIPE_SERVICE] Total ratings in database: $ratings');
      print('📊 [RECIPE_SERVICE] Ratings data: ${ratingsList.map((r) => '${r['user_id']}: ${r['rating']}').join(', ')}');
      
      // Calculate average rating
      double averageRating = 0.0;
      if (ratings > 0) {
        final sum = ratingsList.fold<double>(0, (prev, curr) => prev + (curr['rating'] as num).toDouble());
        averageRating = sum / ratings;
      }
      
      // Get user's rating
      int? userRating;
      if (userId != null && ratingsList.isNotEmpty) {
        try {
          final userRatingData = ratingsList.firstWhere(
            (r) => r['user_id'] == userId,
          );
          userRating = userRatingData['rating'] as int?;
          print('⭐ [RECIPE_SERVICE] User rating found: $userRating');
        } catch (e) {
          userRating = null;
          print('ℹ️ [RECIPE_SERVICE] No user rating yet');
        }
      }

      final recipe = Recipe.fromJson({
        ...response,
        'author_name': authorName,
        'author_avatar_url': authorAvatarUrl,
        'average_rating': averageRating,
        'rating_count': ratings,
        'user_rating': userRating,
      });
      
      print('✅ [RECIPE_SERVICE] Recipe parsed successfully: ${recipe.name} (${recipe.id})');
      
      // Track view asynchronously (don't wait for it)
      _incrementViewCount(id);
      
      return recipe;
    } catch (e, stackTrace) {
      print('❌ [RECIPE_SERVICE] Database query failed: $e');
      print('🔍 [RECIPE_SERVICE] Stack trace: $stackTrace');
      
      throw Exception('Recipe not found: $e');
    }
  }

  /// Increment view count for a recipe (fire and forget)
  Future<void> _incrementViewCount(String recipeId) async {
    try {
      await _supabase.rpc('increment_recipe_view_count', params: {
        'recipe_id': recipeId,
      });
      print('👁️ [RECIPE_SERVICE] View count incremented for recipe: $recipeId');
    } catch (e) {
      // If RPC doesn't exist, try direct update
      try {
        await _supabase
            .from('recipes')
            .update({'view_count': _supabase.rpc('coalesce(view_count, 0) + 1')})
            .eq('id', recipeId);
      } catch (_) {
        // Silently ignore view tracking errors - not critical
        print('⚠️ [RECIPE_SERVICE] Could not track view: $e');
      }
    }
  }

  /// Create new recipe
  Future<Recipe> createRecipe(Recipe recipe) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ [RECIPE_SERVICE] User not authenticated');
        throw Exception('User not authenticated');
      }

      print('📝 [RECIPE_SERVICE] Creating recipe: ${recipe.name}');
      print('👤 [RECIPE_SERVICE] Author: ${user.email} (${user.id})');

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
      List<String> labels = recipe.labels;
      if (labels.isEmpty) {
        labels = _autoCategorizeRecipe(
          name: recipe.name,
          description: recipe.description,
          ingredients: ingredientMaps,
          prepTime: recipe.prepTimeMinutes,
          cookTime: recipe.cookTimeMinutes,
        );
      }

      final recipeData = {
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
        'labels': labels, // Include auto-generated labels for filtering
        'view_count': 0, // Initialize view count
      };
      
      print('📤 [RECIPE_SERVICE] Inserting recipe into database...');
      
      final response = await _supabase
          .from('recipes')
          .insert(recipeData)
          .select()
          .single();

      print('✅ [RECIPE_SERVICE] Recipe created successfully!');
      print('🆔 [RECIPE_SERVICE] New recipe ID: ${response['id']}');
      print('📛 [RECIPE_SERVICE] Recipe name: ${response['name']}');

      final createdRecipe = Recipe.fromJson(response);
      
      print('✅ [RECIPE_SERVICE] Recipe object created: ${createdRecipe.id}');
      
      return createdRecipe;
    } catch (e, stackTrace) {
      print('❌ [RECIPE_SERVICE] Failed to create recipe: $e');
      print('📚 [RECIPE_SERVICE] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete recipe (only by author)
  Future<void> deleteRecipe(String recipeId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ [RECIPE_SERVICE] User not authenticated');
        throw Exception('User not authenticated');
      }

      print('🗑️ [RECIPE_SERVICE] Deleting recipe: $recipeId');
      print('👤 [RECIPE_SERVICE] User: ${user.id}');

      // First verify the user is the author
      final recipe = await _supabase
          .from('recipes')
          .select('author_id')
          .eq('id', recipeId)
          .single();

      if (recipe['author_id'] != user.id) {
        print('❌ [RECIPE_SERVICE] User is not the author');
        throw Exception('You can only delete your own recipes');
      }

      // Delete associated ratings first (foreign key constraint)
      await _supabase
          .from('recipe_ratings')
          .delete()
          .eq('recipe_id', recipeId);

      // Delete associated saves
      await _supabase
          .from('saved_recipes')
          .delete()
          .eq('recipe_id', recipeId);

      // Delete the recipe
      await _supabase
          .from('recipes')
          .delete()
          .eq('id', recipeId);

      print('✅ [RECIPE_SERVICE] Recipe deleted successfully');
    } catch (e, stackTrace) {
      print('❌ [RECIPE_SERVICE] Failed to delete recipe: $e');
      print('📚 [RECIPE_SERVICE] Stack trace: $stackTrace');
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
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ [RECIPE_SERVICE] User not authenticated');
        throw Exception('User not authenticated');
      }

      print('📝 [RECIPE_SERVICE] Updating recipe: $recipeId');
      print('👤 [RECIPE_SERVICE] User: ${user.id}');

      // First verify the user is the author
      final recipe = await _supabase
          .from('recipes')
          .select('author_id')
          .eq('id', recipeId)
          .single();

      if (recipe['author_id'] != user.id) {
        print('❌ [RECIPE_SERVICE] User is not the author');
        throw Exception('You can only edit your own recipes');
      }

      // Build update data
      final updateData = <String, dynamic>{};
      
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (prepTimeMinutes != null) updateData['prep_time_minutes'] = prepTimeMinutes;
      if (cookTimeMinutes != null) updateData['cook_time_minutes'] = cookTimeMinutes;
      if (defaultServings != null) updateData['default_servings'] = defaultServings;
      if (ingredients != null) {
        updateData['ingredients'] = ingredients.map((i) => i.toJson()).toList();
      }
      if (instructions != null) updateData['instructions'] = instructions;

      // Auto-categorize if name or ingredients changed
      if (name != null || ingredients != null) {
        final currentRecipe = await getRecipeById(recipeId);
        final labels = _autoCategorizeRecipe(
          name: name ?? currentRecipe.name,
          description: description ?? currentRecipe.description,
          ingredients: ingredients?.map((i) => i.toJson()).toList() ?? 
                       currentRecipe.ingredients.map((i) => i.toJson()).toList(),
          prepTime: prepTimeMinutes ?? currentRecipe.prepTimeMinutes,
          cookTime: cookTimeMinutes ?? currentRecipe.cookTimeMinutes,
        );
        updateData['labels'] = labels;
      }

      // Update the recipe
      await _supabase
          .from('recipes')
          .update(updateData)
          .eq('id', recipeId);

      print('✅ [RECIPE_SERVICE] Recipe updated successfully');
    } catch (e, stackTrace) {
      print('❌ [RECIPE_SERVICE] Failed to update recipe: $e');
      print('📚 [RECIPE_SERVICE] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Rate recipe (1-5 stars)
  Future<void> rateRecipe(String recipeId, int rating) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      print('⭐ [RECIPE_SERVICE] rateRecipe called:');
      print('   - Recipe ID: $recipeId');
      print('   - User ID: $userId');
      print('   - Rating: $rating');
      
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Check if this is a new rating (not an update)
      final existingRating = await _supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', recipeId)
          .eq('user_id', userId)
          .maybeSingle();

      final isNewRating = existingRating == null;

      // Upsert rating (insert or update if exists)
      // Must specify onConflict for proper upsert behavior
      await _supabase.from('recipe_ratings').upsert(
        {
          'recipe_id': recipeId,
          'user_id': userId,
          'rating': rating,
        },
        onConflict: 'recipe_id,user_id',
      );

      // Verify the rating was saved
      final verifyRating = await _supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', recipeId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (verifyRating != null) {
        print('✅ [RECIPE_SERVICE] Rating VERIFIED in database: ${verifyRating['rating']} stars');
      } else {
        print('❌ [RECIPE_SERVICE] Rating NOT FOUND after save! Recipe ID: $recipeId, User ID: $userId');
      }

      print('✅ [RECIPE_SERVICE] Rating ${isNewRating ? 'added' : 'updated'}: $rating stars for recipe $recipeId');

      // Send push notification to recipe author only for new ratings
      if (isNewRating) {
        try {
          // Get recipe details and author
          final recipeResponse = await _supabase
              .from('recipes')
              .select('name, author_id')
              .eq('id', recipeId)
              .maybeSingle();

          if (recipeResponse != null) {
            final recipeName = recipeResponse['name'] as String;
            final authorId = recipeResponse['author_id'] as String?;
            final user = _supabase.auth.currentUser;
            final raterName = user?.userMetadata?['display_name'] as String? ?? 'Someone';

            // Send PUSH notification to recipe author (not to self!)
            if (authorId != null && authorId != userId) {
              final stars = '⭐' * rating;
              await PushNotificationService.instance.sendToUsers(
                userIds: [authorId],
                title: 'New Rating!',
                body: '$raterName rated "$recipeName" $stars ($rating/5)',
                data: {
                  'type': 'recipe_rating',
                  'recipe_id': recipeId,
                },
              );
              print('✅ [RECIPE_SERVICE] Push notification sent to author $authorId');
            }
          }
        } catch (e) {
          print('⚠️ [RECIPE_SERVICE] Failed to send rating notification: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Delete user's rating
  Future<void> deleteRating(String recipeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('recipe_ratings')
          .delete()
          .eq('recipe_id', recipeId)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get share link for recipe using Supabase redirect
  /// Uses Supabase project URL with a redirect function
  String getShareLink(String recipeId) {
    // Use Supabase Edge Function for redirect (quick solution)
    // Falls back to deep link if edge function not set up
    return 'https://rtwzzerhgieyxsijemsd.supabase.co/functions/v1/share?type=recipe&id=$recipeId';
  }

  /// Get deep link for recipe (direct app opening)
  String getDeepLink(String recipeId) {
    return 'shoply://recipe/$recipeId';
  }

  /// Get share text with recipe details
  String getShareText(Recipe recipe) {
    final deepLink = getDeepLink(recipe.id);
    return '🍳 Check out this recipe: ${recipe.name}\n\n'
           '⏱ Ready in ${recipe.totalTimeMinutes} min\n'
           '⭐ ${recipe.averageRating.toStringAsFixed(1)} rating\n\n'
           '📱 Open in Shoply:\n$deepLink\n\n'
           '💡 Don\'t have Shoply? Download it from the App Store!';
  }

  /// Upload recipe image
  Future<String> uploadRecipeImage(String filePath, String fileName) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final path = 'recipes/$userId/$fileName';
      final file = File(filePath);
      
      await _supabase.storage.from('recipe-images').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _supabase.storage.from('recipe-images').getPublicUrl(path);
      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// Search recipes - searches name, description, labels, author name, and ingredients
  Future<List<Recipe>> searchRecipes(String query) async {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) return [];
    
    print('🔍 [RECIPE_SERVICE] Searching for: "$query"');
    
    try {
      // Get all recipes first (more reliable than complex OR query)
      final allRecipes = await getRecipes();
      print('🔍 [RECIPE_SERVICE] Total recipes to search: ${allRecipes.length}');
      
      // Filter locally for comprehensive search
      final results = allRecipes.where((recipe) {
        // Search in name
        if (recipe.name.toLowerCase().contains(queryLower)) return true;
        
        // Search in description
        if (recipe.description.toLowerCase().contains(queryLower)) return true;
        
        // Search in author name
        if (recipe.authorName.toLowerCase().contains(queryLower)) return true;
        
        // Search in labels/categories
        if (recipe.labels.any((label) => label.toLowerCase().contains(queryLower))) return true;
        
        // Search in ingredients
        if (recipe.ingredients.any((ing) => ing.name.toLowerCase().contains(queryLower))) return true;
        
        return false;
      }).toList();
      
      // Sort by rating (highest first)
      results.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      
      print('✅ [RECIPE_SERVICE] Found ${results.length} recipes matching "$query"');
      return results;
    } catch (e) {
      print('⚠️ [RECIPE_SERVICE] Search failed: $e');
      return [];
    }
  }

  // Note: Sample recipes have been migrated to database via SQL migration
  // See database/migrations/insert_50_recipes.sql

  /// Get recipes filtered by labels (AND semantics)
  /// Returns only recipes that have ALL specified labels
  Future<List<Recipe>> getRecipesFiltered(List<String> filterTags) async {
    if (filterTags.isEmpty) {
      return getRecipes();
    }

    try {
      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_likes!left(user_id)
          ''')
          .contains('labels', filterTags) // PostgreSQL array @> operator (contains ALL)
          .order('created_at', ascending: false);

      final userId = _supabase.auth.currentUser?.id;
      
      // Fetch author display names
      final authorIds = <String>{};
      for (final json in response as List) {
        final authorId = json['author_id'] as String?;
        if (authorId != null) authorIds.add(authorId);
      }
      
      Map<String, Map<String, dynamic>> authorData = {};
      if (authorIds.isNotEmpty) {
        try {
          final usersResponse = await _supabase
              .from('users')
              .select('id, display_name, avatar_url')
              .inFilter('id', authorIds.toList());
          
          for (final user in usersResponse as List) {
            authorData[user['id'] as String] = user;
          }
        } catch (e) {
          print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
        }
      }
      
      final recipes = (response as List).map((json) {
        final likes = (json['recipe_likes'] as List?)?.length ?? 0;
        final isLiked = userId != null &&
            (json['recipe_likes'] as List?)
                ?.any((like) => like['user_id'] == userId) ==
            true;
        
        // Get author name from users table, fallback to stored author_name
        final authorId = json['author_id'] as String?;
        final userData = authorId != null ? authorData[authorId] : null;
        final authorName = userData?['display_name'] as String? ?? json['author_name'] as String? ?? 'Unknown';
        final authorAvatarUrl = userData?['avatar_url'] as String? ?? json['author_avatar_url'] as String?;

        return Recipe.fromJson({
          ...json,
          'author_name': authorName,
          'author_avatar_url': authorAvatarUrl,
          'likes': likes,
          'is_liked_by_user': isLiked,
        });
      }).toList();

      return recipes;
    } catch (e) {
      print('⚠️ [RECIPE_SERVICE] Filter failed: $e');
      return [];
    }
  }

  /// Get available filter options with counts
  /// Returns map of label -> count of recipes with that label
  Future<Map<String, int>> getAvailableFilters() async {
    try {
      // Count labels from all recipes in database
      final allRecipes = await getRecipes();
      final counts = <String, int>{};
      for (final recipe in allRecipes) {
        for (final label in recipe.labels) {
          counts[label] = (counts[label] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e) {
      print('⚠️ [RECIPE_SERVICE] Failed to get filter counts: $e');
      return {};
    }
  }

  // ========== COMMENT METHODS ==========

  /// Get all comments for a recipe
  Future<List<RecipeComment>> getComments(String recipeId) async {
    try {
      final response = await _supabase
          .from('recipe_comments')
          .select('''
            *,
            users!inner(display_name, profile_picture_url)
          ''')
          .eq('recipe_id', recipeId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RecipeComment.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to load comments: $e');
      return [];
    }
  }

  /// Add a comment to a recipe
  Future<RecipeComment?> addComment(String recipeId, String comment) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ [RECIPE_SERVICE] User not authenticated');
        return null;
      }

      final response = await _supabase
          .from('recipe_comments')
          .insert({
            'recipe_id': recipeId,
            'user_id': user.id,
            'comment': comment,
          })
          .select('''
            *,
            users!inner(display_name, profile_picture_url)
          ''')
          .single();

      final newComment = RecipeComment.fromJson(response);

      // Get recipe details for notification
      try {
        final recipeResponse = await _supabase
            .from('recipes')
            .select('name, author_id')
            .eq('id', recipeId)
            .single();

        final recipeName = recipeResponse['name'] as String;
        final authorId = recipeResponse['author_id'] as String;
        final commenterName = user.userMetadata?['display_name'] as String? ?? 'Someone';

        // Send PUSH notification to recipe author (not to self!)
        if (authorId != user.id) {
          final truncatedComment = comment.length > 50 ? '${comment.substring(0, 50)}...' : comment;
          await PushNotificationService.instance.sendToUsers(
            userIds: [authorId],
            title: 'New Comment!',
            body: '$commenterName on "$recipeName": $truncatedComment',
            data: {
              'type': 'recipe_comment',
              'recipe_id': recipeId,
            },
          );
          print('✅ [RECIPE_SERVICE] Push notification sent to author $authorId');
        }
      } catch (e) {
        print('⚠️ [RECIPE_SERVICE] Failed to send comment notification: $e');
      }

      print('✅ [RECIPE_SERVICE] Comment added successfully');
      return newComment;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to add comment: $e');
      return null;
    }
  }

  /// Update a comment
  Future<bool> updateComment(String commentId, String newComment) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('recipe_comments')
          .update({'comment': newComment})
          .eq('id', commentId)
          .eq('user_id', user.id); // Ensure user owns the comment

      print('✅ [RECIPE_SERVICE] Comment updated successfully');
      return true;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to update comment: $e');
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String commentId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('recipe_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id); // Ensure user owns the comment

      print('✅ [RECIPE_SERVICE] Comment deleted successfully');
      return true;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to delete comment: $e');
      return false;
    }
  }

  /// Get comment count for a recipe
  Future<int> getCommentCount(String recipeId) async {
    try {
      final response = await _supabase
          .from('recipe_comments')
          .select('id')
          .eq('recipe_id', recipeId);

      return (response as List).length;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get comment count: $e');
      return 0;
    }
  }

  // ========== SAVED RECIPES (BOOKMARKS) ==========

  /// Check if a recipe is saved by current user
  Future<bool> isRecipeSaved(String recipeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('saved_recipes')
          .select('id')
          .eq('user_id', userId)
          .eq('recipe_id', recipeId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to check saved status: $e');
      return false;
    }
  }

  /// Save a recipe (bookmark)
  Future<bool> saveRecipe(String recipeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      print('🔖 [RECIPE_SERVICE] saveRecipe called:');
      print('   - Recipe ID: $recipeId');
      print('   - User ID: $userId');
      
      if (userId == null) {
        print('❌ [RECIPE_SERVICE] Cannot save - user not logged in');
        return false;
      }

      // Use insert instead of upsert to see clearer errors
      await _supabase.from('saved_recipes').insert({
        'user_id': userId,
        'recipe_id': recipeId,
      });

      print('✅ [RECIPE_SERVICE] Recipe saved successfully: $recipeId');
      return true;
    } on PostgrestException catch (e) {
      // If already exists, that's fine
      if (e.code == '23505') {
        print('ℹ️ [RECIPE_SERVICE] Recipe already saved (duplicate): $recipeId');
        return true;
      }
      print('❌ [RECIPE_SERVICE] PostgrestException saving recipe:');
      print('   - Code: ${e.code}');
      print('   - Message: ${e.message}');
      print('   - Details: ${e.details}');
      print('   - Hint: ${e.hint}');
      return false;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to save recipe: $e');
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

      print('✅ [RECIPE_SERVICE] Recipe unsaved: $recipeId');
      return true;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to unsave recipe: $e');
      return false;
    }
  }

  /// Get all saved recipes for current user
  Future<List<Recipe>> getSavedRecipes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ [RECIPE_SERVICE] getSavedRecipes: No user logged in');
        return [];
      }

      print('📥 [RECIPE_SERVICE] Loading saved recipes for user: $userId');
      
      final response = await _supabase
          .from('saved_recipes')
          .select('recipe_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final savedRecipeIds = (response as List)
          .where((r) => r['recipe_id'] != null)
          .map((r) => r['recipe_id'] as String)
          .toList();

      print('📋 [RECIPE_SERVICE] Found ${savedRecipeIds.length} saved recipe IDs: $savedRecipeIds');

      if (savedRecipeIds.isEmpty) return [];

      // Get all recipes from database
      try {
        final recipesResponse = await _supabase
            .from('recipes')
            .select('''
              *,
              recipe_ratings!left(user_id, rating)
            ''')
            .inFilter('id', savedRecipeIds);

        // Fetch author display names
        final authorIds = <String>{};
        for (final json in recipesResponse as List) {
          final authorId = json['author_id'] as String?;
          if (authorId != null) authorIds.add(authorId);
        }
        
        Map<String, Map<String, dynamic>> authorData = {};
        if (authorIds.isNotEmpty) {
          try {
            final usersResponse = await _supabase
                .from('users')
                .select('id, display_name, avatar_url')
                .inFilter('id', authorIds.toList());
            
            for (final user in usersResponse as List) {
              authorData[user['id'] as String] = user;
            }
          } catch (e) {
            print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
          }
        }

        final recipes = (recipesResponse as List).map((json) {
          final ratings = (json['recipe_ratings'] as List?) ?? [];
          final ratingCount = ratings.length;
          final averageRating = ratingCount > 0
              ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
              : 0.0;
          
          // Get author name from users table, fallback to stored author_name
          final authorId = json['author_id'] as String?;
          final userData = authorId != null ? authorData[authorId] : null;
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

        // Sort by saved order
        recipes.sort((a, b) {
          final aIndex = savedRecipeIds.indexOf(a.id);
          final bIndex = savedRecipeIds.indexOf(b.id);
          return aIndex.compareTo(bIndex);
        });

        print('✅ [RECIPE_SERVICE] Returning ${recipes.length} total saved recipes');
        return recipes;
      } catch (e) {
        print('⚠️ [RECIPE_SERVICE] Error fetching recipes: $e');
        return [];
      }
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get saved recipes: $e');
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

      return (response as List)
          .map((r) => r['recipe_id'] as String)
          .toSet();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get saved recipe IDs: $e');
      return {};
    }
  }

  // ========== USER RECIPES ==========

  /// Get recipes created by current user
  Future<List<Recipe>> getMyRecipes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      print('👤 [RECIPE_SERVICE] getMyRecipes - Current user ID: $userId');
      
      if (userId == null) {
        print('⚠️ [RECIPE_SERVICE] getMyRecipes - No user logged in');
        return [];
      }

      final response = await _supabase
          .from('recipes')
          .select('''
            *,
            recipe_ratings!left(user_id, rating)
          ''')
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      
      print('📊 [RECIPE_SERVICE] getMyRecipes - Query returned ${(response as List).length} recipes');
      for (final r in response) {
        print('   📄 Recipe: ${r['name']} | author_id: ${r['author_id']} | match: ${r['author_id'] == userId}');
      }
      
      // Fetch author display names (user's own name)
      Map<String, Map<String, dynamic>> authorData = {};
      try {
        final usersResponse = await _supabase
            .from('users')
            .select('id, display_name, avatar_url')
            .eq('id', userId);
        
        for (final user in usersResponse as List) {
          authorData[user['id'] as String] = user;
        }
      } catch (e) {
        print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
      }

      return (response as List).map((json) {
        final ratings = (json['recipe_ratings'] as List?) ?? [];
        final ratingCount = ratings.length;
        final averageRating = ratingCount > 0
            ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
            : 0.0;
        
        // Get author name from users table, fallback to stored author_name
        final authorId = json['author_id'] as String?;
        final userData = authorId != null ? authorData[authorId] : null;
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
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get my recipes: $e');
      return [];
    }
  }

  /// Get recipes by a specific author
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
        print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
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
      print('❌ [RECIPE_SERVICE] Failed to get recipes by author: $e');
      return [];
    }
  }

  // ========== POPULAR / FEATURED ==========

  /// Get popular recipes (by rating count and recent activity)
  /// For "Popular This Week" - considers ratings from the last 7 days
  /// Falls back to all-time popularity if no recent ratings exist
  Future<List<Recipe>> getPopularRecipes({int limit = 10, bool thisWeekOnly = false}) async {
    try {
      if (thisWeekOnly) {
        // Get recipes with ratings from the last 7 days
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final weekAgoStr = weekAgo.toIso8601String();
        
        final response = await _supabase
            .from('recipe_ratings')
            .select('recipe_id, rating, created_at')
            .gte('created_at', weekAgoStr);
        
        if ((response as List).isNotEmpty) {
          // Count ratings per recipe from this week
          final weeklyRatings = <String, List<int>>{};
          for (final rating in response) {
            final recipeId = rating['recipe_id'] as String;
            final ratingValue = rating['rating'] as int;
            weeklyRatings.putIfAbsent(recipeId, () => []).add(ratingValue);
          }
          
          // Sort by weekly rating count, then by average
          final sortedRecipeIds = weeklyRatings.entries.toList()
            ..sort((a, b) {
              final countCompare = b.value.length.compareTo(a.value.length);
              if (countCompare != 0) return countCompare;
              final avgA = a.value.reduce((x, y) => x + y) / a.value.length;
              final avgB = b.value.reduce((x, y) => x + y) / b.value.length;
              return avgB.compareTo(avgA);
            });
          
          // Get full recipe data for top recipes
          final topIds = sortedRecipeIds.take(limit).map((e) => e.key).toList();
          if (topIds.isNotEmpty) {
            final recipesResponse = await _supabase
                .from('recipes')
                .select('*, recipe_ratings!left(user_id, rating)')
                .inFilter('id', topIds);
            
            // Fetch author display names
            final authorIds = <String>{};
            for (final json in recipesResponse as List) {
              final authorId = json['author_id'] as String?;
              if (authorId != null) authorIds.add(authorId);
            }
            
            Map<String, Map<String, dynamic>> authorData = {};
            if (authorIds.isNotEmpty) {
              try {
                final usersResponse = await _supabase
                    .from('users')
                    .select('id, display_name, avatar_url')
                    .inFilter('id', authorIds.toList());
                
                for (final user in usersResponse as List) {
                  authorData[user['id'] as String] = user;
                }
              } catch (e) {
                print('⚠️ [RECIPE_SERVICE] Could not fetch user data: $e');
              }
            }
            
            final recipes = (recipesResponse as List).map((json) {
              final ratings = (json['recipe_ratings'] as List?) ?? [];
              final ratingCount = ratings.length;
              final averageRating = ratingCount > 0
                  ? ratings.fold<double>(0, (sum, r) => sum + (r['rating'] as num).toDouble()) / ratingCount
                  : 0.0;
              
              // Get author name from users table, fallback to stored author_name
              final authorId = json['author_id'] as String?;
              final userData = authorId != null ? authorData[authorId] : null;
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
            
            // Sort by weekly popularity order
            recipes.sort((a, b) {
              final aIndex = topIds.indexOf(a.id);
              final bIndex = topIds.indexOf(b.id);
              return aIndex.compareTo(bIndex);
            });
            
            return recipes;
          }
        }
      }
      
      // Fallback to all-time popularity using combined score
      final allRecipes = await getRecipes();
      
      // Sort by combined popularity score: views + ratings + engagement
      allRecipes.sort((a, b) {
        // Calculate popularity score for each recipe
        // Formula: (viewCount * 0.1) + (averageRating * 20) + (ratingCount * 2)
        final scoreA = (a.viewCount * 0.1) + (a.averageRating * 20) + (a.ratingCount * 2);
        final scoreB = (b.viewCount * 0.1) + (b.averageRating * 20) + (b.ratingCount * 2);
        return scoreB.compareTo(scoreA);
      });

      // For small recipe counts, show max half of recipes (min 1)
      // This prevents showing ALL recipes in "Popular" section
      final effectiveLimit = allRecipes.length <= limit * 2
          ? (allRecipes.length / 2).ceil().clamp(1, limit)
          : limit;
      
      return allRecipes.take(effectiveLimit).toList();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get popular recipes: $e');
      return [];
    }
  }

  /// Get recently added recipes
  Future<List<Recipe>> getRecentRecipes({int limit = 10}) async {
    try {
      final allRecipes = await getRecipes();
      
      // Sort by creation date
      allRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // For small recipe counts, show max half of recipes (min 1)
      final effectiveLimit = allRecipes.length <= limit * 2
          ? (allRecipes.length / 2).ceil().clamp(1, limit)
          : limit;
      
      return allRecipes.take(effectiveLimit).toList();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get recent recipes: $e');
      return [];
    }
  }

  /// Get recipes by category/label
  Future<List<Recipe>> getRecipesByCategory(String category) async {
    try {
      print('🏷️ [RECIPE_SERVICE] getRecipesByCategory: "$category"');
      final allRecipes = await getRecipes();
      print('   - Total recipes: ${allRecipes.length}');
      
      final filtered = allRecipes.where((recipe) {
        final hasLabel = recipe.labels.any((label) => 
          label.toLowerCase() == category.toLowerCase() ||
          label.toLowerCase().contains(category.toLowerCase())
        );
        if (hasLabel) {
          print('   - Match: ${recipe.name} (labels: ${recipe.labels})');
        }
        return hasLabel;
      }).toList();
      
      print('   - Filtered: ${filtered.length} recipes');
      return filtered;
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get recipes by category: $e');
      return [];
    }
  }

  /// Get unique authors with recipe counts
  Future<List<Map<String, dynamic>>> getTopAuthors({int limit = 10}) async {
    try {
      final allRecipes = await getRecipes();
      
      // Group by author
      final authorMap = <String, Map<String, dynamic>>{};
      
      for (final recipe in allRecipes) {
        if (!authorMap.containsKey(recipe.authorId)) {
          authorMap[recipe.authorId] = {
            'authorId': recipe.authorId,
            'authorName': recipe.authorName,
            'authorAvatarUrl': recipe.authorAvatarUrl,
            'recipeCount': 0,
            'totalRating': 0.0,
            'ratedRecipes': 0,
            'totalViews': 0,
            'totalRatingCount': 0,
          };
        }
        
        authorMap[recipe.authorId]!['recipeCount'] = 
            (authorMap[recipe.authorId]!['recipeCount'] as int) + 1;
        authorMap[recipe.authorId]!['totalViews'] = 
            (authorMap[recipe.authorId]!['totalViews'] as int) + recipe.viewCount;
        authorMap[recipe.authorId]!['totalRatingCount'] = 
            (authorMap[recipe.authorId]!['totalRatingCount'] as int) + recipe.ratingCount;
        
        if (recipe.ratingCount > 0) {
          authorMap[recipe.authorId]!['totalRating'] = 
              (authorMap[recipe.authorId]!['totalRating'] as double) + recipe.averageRating;
          authorMap[recipe.authorId]!['ratedRecipes'] = 
              (authorMap[recipe.authorId]!['ratedRecipes'] as int) + 1;
        }
      }

      // Calculate average rating and popularity score for each author
      final authors = authorMap.values.map((author) {
        final ratedRecipes = author['ratedRecipes'] as int;
        author['averageRating'] = ratedRecipes > 0
            ? (author['totalRating'] as double) / ratedRecipes
            : 0.0;
        
        // Calculate author score: recipes + views + ratings
        final recipeCount = author['recipeCount'] as int;
        final totalViews = author['totalViews'] as int;
        final totalRatingCount = author['totalRatingCount'] as int;
        final avgRating = author['averageRating'] as double;
        
        // Score formula: (recipes * 10) + (views * 0.1) + (ratings * 2) + (avgRating * 5)
        author['score'] = (recipeCount * 10) + (totalViews * 0.1) + (totalRatingCount * 2) + (avgRating * 5);
        
        return author;
      }).toList();

      // Sort by combined score (popularity + quality)
      authors.sort((a, b) => 
          (b['score'] as double).compareTo(a['score'] as double));

      return authors.take(limit).toList();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to get top authors: $e');
      return [];
    }
  }

  /// Search users by name
  Future<List<Map<String, dynamic>>> searchAuthors(String query) async {
    try {
      final allRecipes = await getRecipes();
      
      // Get unique authors matching query
      final authorMap = <String, Map<String, dynamic>>{};
      
      for (final recipe in allRecipes) {
        if (recipe.authorName.toLowerCase().contains(query.toLowerCase())) {
          if (!authorMap.containsKey(recipe.authorId)) {
            authorMap[recipe.authorId] = {
              'authorId': recipe.authorId,
              'authorName': recipe.authorName,
              'authorAvatarUrl': recipe.authorAvatarUrl,
              'recipeCount': 0,
            };
          }
          authorMap[recipe.authorId]!['recipeCount'] = 
              (authorMap[recipe.authorId]!['recipeCount'] as int) + 1;
        }
      }

      return authorMap.values.toList();
    } catch (e) {
      print('❌ [RECIPE_SERVICE] Failed to search authors: $e');
      return [];
    }
  }
}
