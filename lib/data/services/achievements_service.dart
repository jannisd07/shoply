import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/user_achievement.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Service for managing user achievements and badges
class AchievementsService {
  static final AchievementsService instance = AchievementsService._();
  AchievementsService._();
  
  final _supabase = SupabaseService.instance.client;

  /// Get all achievement definitions
  Future<List<AchievementDefinition>> getAllAchievements() async {
    try {
      final response = await _supabase
          .from('achievement_definitions')
          .select()
          .order('sort_order');
      
      return (response as List)
          .map((json) => AchievementDefinition.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [ACHIEVEMENTS] Error fetching definitions: $e');
      return _getDefaultAchievements();
    }
  }

  /// Get user's unlocked achievements
  Future<List<UserAchievement>> getUserAchievements([String? userId]) async {
    try {
      final uid = userId ?? _supabase.auth.currentUser?.id;
      if (uid == null) return [];

      final response = await _supabase
          .from('user_achievements')
          .select('*, achievement_definitions(*)')
          .eq('user_id', uid)
          .order('unlocked_at', ascending: false);

      return (response as List).map((json) {
        final defJson = json['achievement_definitions'] as Map<String, dynamic>?;
        final definition = defJson != null 
            ? AchievementDefinition.fromJson(defJson) 
            : null;
        return UserAchievement.fromJson(json, definition: definition);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ [ACHIEVEMENTS] Error fetching user achievements: $e');
      return [];
    }
  }

  /// Get user statistics
  Future<UserStats?> getUserStats([String? userId]) async {
    try {
      final uid = userId ?? _supabase.auth.currentUser?.id;
      if (uid == null) return null;

      final response = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) {
        return UserStats.fromJson(response);
      }
      
      // Initialize stats if not exists
      return UserStats(userId: uid);
    } catch (e) {
      debugPrint('⚠️ [ACHIEVEMENTS] Error fetching user stats: $e');
      return null;
    }
  }

  /// Increment a stat and check for new achievements
  Future<List<AchievementDefinition>> incrementStat(String statType, {int amount = 1}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get current stats
      final stats = await getUserStats();
      final currentValue = stats?.getValueForType(statType) ?? 0;
      final newValue = currentValue + amount;

      // Update stats
      await _supabase.from('user_stats').upsert({
        'user_id': userId,
        statType: newValue,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Check for new achievements
      return await _checkAndUnlockAchievements(statType, newValue);
    } catch (e) {
      debugPrint('❌ [ACHIEVEMENTS] Error incrementing stat: $e');
      return [];
    }
  }

  /// Check and unlock achievements based on stat
  Future<List<AchievementDefinition>> _checkAndUnlockAchievements(String statType, int value) async {
    final newlyUnlocked = <AchievementDefinition>[];
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get all achievements for this stat type
      final achievements = await getAllAchievements();
      final relevantAchievements = achievements.where(
        (a) => a.requirementType == statType && a.requirementValue <= value
      ).toList();

      // Get already unlocked
      final userAchievements = await getUserAchievements();
      final unlockedIds = userAchievements.map((a) => a.achievementId).toSet();

      // Unlock new achievements
      for (final achievement in relevantAchievements) {
        if (!unlockedIds.contains(achievement.id)) {
          await _supabase.from('user_achievements').insert({
            'user_id': userId,
            'achievement_id': achievement.id,
          });
          newlyUnlocked.add(achievement);
          debugPrint('🏆 [ACHIEVEMENTS] Unlocked: ${achievement.name}');
        }
      }

      // Update total points if new achievements
      if (newlyUnlocked.isNotEmpty) {
        final totalPoints = newlyUnlocked.fold<int>(0, (sum, a) => sum + a.points);
        await _supabase.rpc('increment_user_points', params: {
          'user_id_param': userId,
          'points_to_add': totalPoints,
        }).catchError((_) => null);
      }
    } catch (e) {
      debugPrint('❌ [ACHIEVEMENTS] Error checking achievements: $e');
    }

    return newlyUnlocked;
  }

  /// Track recipe cooked
  Future<List<AchievementDefinition>> trackRecipeCooked() async {
    return incrementStat('recipes_cooked');
  }

  /// Track recipe saved
  Future<List<AchievementDefinition>> trackRecipeSaved() async {
    return incrementStat('recipes_saved');
  }

  /// Track recipe created
  Future<List<AchievementDefinition>> trackRecipeCreated() async {
    return incrementStat('recipes_created');
  }

  /// Track recipe rated
  Future<List<AchievementDefinition>> trackRecipeRated() async {
    return incrementStat('recipes_rated');
  }

  /// Get progress for an achievement
  double getProgress(AchievementDefinition achievement, UserStats? stats) {
    if (stats == null) return 0;
    final current = stats.getValueForType(achievement.requirementType);
    return (current / achievement.requirementValue).clamp(0.0, 1.0);
  }

  /// Default achievements when database not available
  List<AchievementDefinition> _getDefaultAchievements() {
    return const [
      // Cooking
      AchievementDefinition(id: 'first_cook', name: 'First Steps', description: 'Mark your first recipe as cooked', icon: '👨‍🍳', category: 'cooking', requirementType: 'recipes_cooked', requirementValue: 1, points: 10, sortOrder: 1),
      AchievementDefinition(id: 'cook_10', name: 'Home Chef', description: 'Cook 10 recipes', icon: '🍳', category: 'cooking', requirementType: 'recipes_cooked', requirementValue: 10, points: 25, sortOrder: 2),
      AchievementDefinition(id: 'cook_50', name: 'Kitchen Master', description: 'Cook 50 recipes', icon: '👩‍🍳', category: 'cooking', requirementType: 'recipes_cooked', requirementValue: 50, points: 50, sortOrder: 3),
      // Saving
      AchievementDefinition(id: 'first_save', name: 'Bookmark Beginner', description: 'Save your first recipe', icon: '🔖', category: 'saving', requirementType: 'recipes_saved', requirementValue: 1, points: 10, sortOrder: 4),
      AchievementDefinition(id: 'save_10', name: 'Recipe Collector', description: 'Save 10 recipes', icon: '📚', category: 'saving', requirementType: 'recipes_saved', requirementValue: 10, points: 25, sortOrder: 5),
      AchievementDefinition(id: 'save_50', name: 'Recipe Hoarder', description: 'Save 50 recipes', icon: '📖', category: 'saving', requirementType: 'recipes_saved', requirementValue: 50, points: 50, sortOrder: 6),
      // Creating
      AchievementDefinition(id: 'first_create', name: 'Recipe Author', description: 'Create your first recipe', icon: '✍️', category: 'creating', requirementType: 'recipes_created', requirementValue: 1, points: 20, sortOrder: 7),
      AchievementDefinition(id: 'create_5', name: 'Recipe Writer', description: 'Create 5 recipes', icon: '📝', category: 'creating', requirementType: 'recipes_created', requirementValue: 5, points: 50, sortOrder: 8),
      // Rating
      AchievementDefinition(id: 'first_rate', name: 'Critic', description: 'Rate your first recipe', icon: '⭐', category: 'rating', requirementType: 'recipes_rated', requirementValue: 1, points: 10, sortOrder: 9),
      AchievementDefinition(id: 'rate_20', name: 'Food Critic', description: 'Rate 20 recipes', icon: '🎯', category: 'rating', requirementType: 'recipes_rated', requirementValue: 20, points: 30, sortOrder: 10),
    ];
  }
}
