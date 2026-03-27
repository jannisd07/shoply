import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/recipe_variation.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Service for managing recipe variations (user-submitted modifications)
class RecipeVariationsService {
  static final RecipeVariationsService instance = RecipeVariationsService._();
  RecipeVariationsService._();
  
  final _supabase = SupabaseService.instance.client;

  /// Get all variations for a recipe
  Future<List<RecipeVariation>> getVariations(String recipeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      final response = await _supabase
          .from('recipe_variations')
          .select('''
            *,
            profiles:user_id (display_name, avatar_url)
          ''')
          .eq('original_recipe_id', recipeId)
          .order('upvotes', ascending: false);

      final variations = <RecipeVariation>[];
      for (final json in response as List) {
        // Get user vote if logged in
        bool? userVoted;
        if (userId != null) {
          final voteResponse = await _supabase
              .from('recipe_variation_votes')
              .select('vote')
              .eq('variation_id', json['id'])
              .eq('user_id', userId)
              .maybeSingle();
          
          if (voteResponse != null) {
            userVoted = voteResponse['vote'] == 1;
          }
        }

        final profile = json['profiles'] as Map<String, dynamic>?;
        variations.add(RecipeVariation(
          id: json['id'] as String,
          originalRecipeId: json['original_recipe_id'] as String,
          userId: json['user_id'] as String,
          userName: profile?['display_name'] as String? ?? 'Anonymous',
          userAvatarUrl: profile?['avatar_url'] as String?,
          title: json['title'] as String,
          description: json['description'] as String?,
          changes: json['changes'] != null
              ? (json['changes'] as List).map((c) => VariationChange.fromJson(c)).toList()
              : [],
          upvotes: json['upvotes'] as int? ?? 0,
          userVoted: userVoted,
          createdAt: DateTime.parse(json['created_at'] as String),
        ));
      }

      return variations;
    } catch (e) {
      debugPrint('❌ [VARIATIONS] Error fetching variations: $e');
      return [];
    }
  }

  /// Create a new recipe variation
  Future<RecipeVariation?> createVariation({
    required String originalRecipeId,
    required String title,
    String? description,
    required List<VariationChange> changes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Must be logged in to create variations');
      }

      final response = await _supabase.from('recipe_variations').insert({
        'original_recipe_id': originalRecipeId,
        'user_id': userId,
        'title': title,
        'description': description,
        'changes': changes.map((c) => c.toJson()).toList(),
      }).select().single();

      debugPrint('✅ [VARIATIONS] Created variation: ${response['id']}');
      
      return RecipeVariation(
        id: response['id'] as String,
        originalRecipeId: originalRecipeId,
        userId: userId,
        userName: 'You',
        title: title,
        description: description,
        changes: changes,
        upvotes: 0,
        userVoted: null,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ [VARIATIONS] Error creating variation: $e');
      return null;
    }
  }

  /// Vote on a variation
  Future<int> vote(String variationId, bool upvote) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      // Upsert vote
      await _supabase.from('recipe_variation_votes').upsert({
        'variation_id': variationId,
        'user_id': userId,
        'vote': upvote ? 1 : -1,
      });

      // Get updated vote count
      final response = await _supabase
          .from('recipe_variation_votes')
          .select('vote')
          .eq('variation_id', variationId);

      final totalVotes = (response as List).fold<int>(
        0, (sum, v) => sum + (v['vote'] as int)
      );

      // Update variation upvotes
      await _supabase
          .from('recipe_variations')
          .update({'upvotes': totalVotes})
          .eq('id', variationId);

      return totalVotes;
    } catch (e) {
      debugPrint('❌ [VARIATIONS] Error voting: $e');
      return 0;
    }
  }

  /// Remove vote from a variation
  Future<int> removeVote(String variationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      await _supabase
          .from('recipe_variation_votes')
          .delete()
          .eq('variation_id', variationId)
          .eq('user_id', userId);

      // Get updated count
      final response = await _supabase
          .from('recipe_variation_votes')
          .select('vote')
          .eq('variation_id', variationId);

      final totalVotes = (response as List).fold<int>(
        0, (sum, v) => sum + (v['vote'] as int)
      );

      await _supabase
          .from('recipe_variations')
          .update({'upvotes': totalVotes})
          .eq('id', variationId);

      return totalVotes;
    } catch (e) {
      debugPrint('❌ [VARIATIONS] Error removing vote: $e');
      return 0;
    }
  }

  /// Delete a variation (only creator can delete)
  Future<bool> deleteVariation(String variationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('recipe_variations')
          .delete()
          .eq('id', variationId)
          .eq('user_id', userId);

      debugPrint('✅ [VARIATIONS] Deleted variation: $variationId');
      return true;
    } catch (e) {
      debugPrint('❌ [VARIATIONS] Error deleting variation: $e');
      return false;
    }
  }
}
