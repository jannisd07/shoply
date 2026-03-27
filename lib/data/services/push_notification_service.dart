import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Service for sending push notifications to other users via FCM
/// This requires Firebase Cloud Messaging and FCM tokens stored in the database
class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  PushNotificationService._();

  final _supabase = SupabaseService.instance.client;

  /// Send push notification to specific user(s)
  Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get FCM tokens for these users
      final tokensResponse = await _supabase
          .from('users')
          .select('id, fcm_token')
          .inFilter('id', userIds);

      final users = tokensResponse as List;
      if (users.isEmpty) {
        debugPrint('⚠️ [PUSH] No users found for IDs: $userIds');
        return;
      }

      int sentCount = 0;
      int skippedCount = 0;
      
      // Send to each token
      for (final user in users) {
        final userId = user['id'] as String;
        final token = user['fcm_token'] as String?;
        
        if (token == null || token.isEmpty) {
          debugPrint('⚠️ [PUSH] User $userId has no FCM token');
          skippedCount++;
          continue;
        }
        
        final success = await _sendToToken(
          token: token,
          title: title,
          body: body,
          data: data,
          userId: userId,
        );
        
        if (success) sentCount++;
      }

      debugPrint('✅ [PUSH] Sent: $sentCount, Skipped (no token): $skippedCount');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send push notifications: $e');
    }
  }

  /// Send notification to all list members except one
  Future<void> sendToListMembers({
    required String listId,
    required String excludeUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all list members except the excluded user
      final membersResponse = await _supabase
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', excludeUserId);

      final members = membersResponse as List;
      if (members.isEmpty) {
        debugPrint('⚠️ [PUSH] No other members in list $listId');
        return;
      }

      final userIds = members
          .map((m) => m['user_id'] as String)
          .toList();

      await sendToUsers(
        userIds: userIds,
        title: title,
        body: body,
        data: data,
      );

      debugPrint('✅ [PUSH] Sent to ${userIds.length} list members');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send to list members: $e');
    }
  }

  /// Send notification to recipe author
  Future<void> sendToRecipeAuthor({
    required String recipeId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get recipe author
      final recipeResponse = await _supabase
          .from('recipes')
          .select('author_id')
          .eq('id', recipeId)
          .single();

      final authorId = recipeResponse['author_id'] as String;

      await sendToUsers(
        userIds: [authorId],
        title: title,
        body: body,
        data: data,
      );

      debugPrint('✅ [PUSH] Sent to recipe author');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send to recipe author: $e');
    }
  }

  /// Low-level method to send to FCM token
  /// NOTE: This requires a Cloud Function or backend to work properly
  /// Firebase doesn't allow direct FCM API calls from client due to security
  Future<bool> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? userId, // Optional: to clean up invalid tokens
  }) async {
    try {
      // Call Supabase Edge Function to send push notification
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
        },
      );

      // Always print full debug info from Edge Function
      final responseData = response.data;
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 [PUSH] Response status: ${response.status}');
      if (responseData is Map && responseData['debug'] != null) {
        debugPrint('📋 [PUSH] Debug log from Edge Function:');
        for (final line in (responseData['debug'] as List)) {
          debugPrint('   $line');
        }
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (response.status == 200) {
        debugPrint('✅ [PUSH] Sent to token: ${token.substring(0, 20)}...');
        return true;
      } else if (response.status == 410) {
        // Token is invalid/unregistered - clean it up
        debugPrint('⚠️ [PUSH] Token invalid (410), cleaning up...');
        if (userId != null) {
          await _cleanupInvalidToken(userId);
        }
        return false;
      } else {
        debugPrint('⚠️ [PUSH] Failed to send: ${response.status}');
        debugPrint('⚠️ [PUSH] Full response: $responseData');
        return false;
      }
    } catch (e, stack) {
      debugPrint('❌ [PUSH] Error sending to token: $e');
      debugPrint('❌ [PUSH] Stack: $stack');
      return false;
    }
  }

  /// Remove invalid FCM token from database
  Future<void> _cleanupInvalidToken(String userId) async {
    try {
      await _supabase
          .from('users')
          .update({'fcm_token': null})
          .eq('id', userId);
      debugPrint('🧹 [PUSH] Cleaned up invalid token for user $userId');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to cleanup token: $e');
    }
  }

  /// Send Recipe of the Day notification to all users
  /// This should be called from a scheduled job (Supabase Edge Function)
  Future<void> sendRecipeOfTheDay({
    required String recipeId,
    required String recipeName,
    String? recipeImageUrl,
  }) async {
    try {
      // Get all users who have notifications enabled
      final usersResponse = await _supabase
          .from('users')
          .select('id, fcm_token')
          .not('fcm_token', 'is', null);

      if (usersResponse == null || (usersResponse as List).isEmpty) {
        debugPrint('⚠️ [PUSH] No users with FCM tokens for ROTD');
        return;
      }

      // Send to all users
      for (final user in usersResponse) {
        final token = user['fcm_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _sendToToken(
            token: token,
            title: '🍳 Recipe of the Day',
            body: 'Try today\'s featured recipe: $recipeName',
            data: {
              'type': 'recipe_of_the_day',
              'recipe_id': recipeId,
              'image_url': recipeImageUrl,
            },
          );
        }
      }

      // Mark notification as sent
      await _supabase
          .from('recipe_of_the_day')
          .update({'notification_sent': true})
          .eq('recipe_id', recipeId)
          .eq('featured_date', DateTime.now().toIso8601String().split('T')[0]);

      debugPrint('✅ [PUSH] Sent ROTD notifications to ${usersResponse.length} users');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send ROTD notifications: $e');
    }
  }

  /// Send notification to creator's followers when they post a new recipe
  Future<void> sendNewRecipeToFollowers({
    required String creatorId,
    required String creatorName,
    required String recipeId,
    required String recipeName,
  }) async {
    try {
      // Get all followers
      final followersResponse = await _supabase
          .from('creator_follows')
          .select('follower_id')
          .eq('creator_id', creatorId);

      if (followersResponse == null || (followersResponse as List).isEmpty) {
        debugPrint('⚠️ [PUSH] Creator has no followers');
        return;
      }

      final followerIds = (followersResponse)
          .map((f) => f['follower_id'] as String)
          .toList();

      await sendToUsers(
        userIds: followerIds,
        title: '👨‍🍳 $creatorName posted a new recipe!',
        body: recipeName,
        data: {
          'type': 'new_recipe',
          'recipe_id': recipeId,
          'creator_id': creatorId,
        },
      );

      debugPrint('✅ [PUSH] Sent new recipe notification to ${followerIds.length} followers');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to notify followers: $e');
    }
  }

  /// Send achievement unlocked notification
  Future<void> sendAchievementUnlocked({
    required String userId,
    required String achievementName,
    required String achievementIcon,
    required int points,
  }) async {
    try {
      await sendToUsers(
        userIds: [userId],
        title: '$achievementIcon Achievement Unlocked!',
        body: '$achievementName (+$points points)',
        data: {
          'type': 'achievement',
          'achievement_name': achievementName,
          'points': points,
        },
      );

      debugPrint('✅ [PUSH] Sent achievement notification');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send achievement notification: $e');
    }
  }
}
