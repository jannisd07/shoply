import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Sends push notifications to other users via the `send-push-notification`
/// Edge Function, using the FCM tokens stored in `users.fcm_token`.
class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  PushNotificationService._();

  final _supabase = SupabaseService.instance.client;

  /// Send push notification to specific user(s). Never throws.
  Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;
    try {
      final users = await _supabase
          .from('users')
          .select('id, fcm_token')
          .inFilter('id', userIds);

      if (users.isEmpty) {
        debugPrint('⚠️ [PUSH] No users found for IDs: $userIds');
        return;
      }

      final sends = <Future<bool>>[];
      var skippedCount = 0;
      for (final user in users) {
        final token = user['fcm_token'] as String?;
        if (token == null || token.isEmpty) {
          skippedCount++;
          continue;
        }
        sends.add(_sendToToken(
          token: token,
          title: title,
          body: body,
          data: data,
          userId: user['id'] as String,
        ));
      }

      final results = await Future.wait(sends);
      final sentCount = results.where((ok) => ok).length;
      debugPrint(
          '✅ [PUSH] Sent: $sentCount, Skipped (no token): $skippedCount');
    } catch (e) {
      debugPrint('❌ [PUSH] Failed to send push notifications: $e');
    }
  }

  /// Send to one FCM token via the Edge Function (FCM can't be called from
  /// the client directly). Returns true on success.
  Future<bool> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? userId, // Optional: to clean up invalid tokens
  }) async {
    try {
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

      if (response.status == 200) return true;

      if (response.status == 410) {
        // Token is invalid/unregistered - clean it up
        debugPrint('⚠️ [PUSH] Token invalid (410), cleaning up...');
        if (userId != null) await _cleanupInvalidToken(userId);
      } else {
        debugPrint(
            '⚠️ [PUSH] Failed to send: ${response.status} ${response.data}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ [PUSH] Error sending to token: $e');
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

  /// Sends a push to every member of [listId] except [excludeUserId].
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
}
