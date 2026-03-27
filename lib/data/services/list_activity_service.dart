import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Service for tracking and storing list activities.
/// 
/// Activities are stored locally per list and synced when possible.
/// This provides a history of all changes made to a shopping list.
/// 
/// **AI: Usage Template**:
/// ```dart
/// final service = ListActivityService();
/// 
/// // Log an activity
/// await service.logActivity(
///   listId: 'list-123',
///   type: ListActivityType.itemAdded,
///   metadata: {'itemName': 'Milk'},
/// );
/// 
/// // Get activities for a list
/// final activities = await service.getActivities('list-123');
/// ```
class ListActivityService {
  static final ListActivityService _instance = ListActivityService._internal();
  factory ListActivityService() => _instance;
  ListActivityService._internal();

  static const int _maxActivitiesPerList = 100;
  static const String _activitiesPrefix = 'list_activities_';

  /// Log a new activity for a list
  Future<ListActivity> logActivity({
    required String listId,
    required ListActivityType type,
    Map<String, dynamic>? metadata,
  }) async {
    final user = SupabaseService.instance.currentUser;
    final userId = user?.id ?? 'unknown';
    
    // Get user display name
    String userName = 'Someone';
    if (user != null) {
      try {
        final response = await SupabaseService.instance
            .from('users')
            .select('display_name')
            .eq('id', userId)
            .single();
        userName = response['display_name'] as String? ?? 'Someone';
      } catch (e) {
        debugPrint('⚠️ [LIST_ACTIVITY] Failed to get user name: $e');
      }
    }

    final activity = ListActivity(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.name}',
      listId: listId,
      type: type,
      userId: userId,
      userName: userName,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // Save locally
    await _saveActivity(activity);

    debugPrint('📝 [LIST_ACTIVITY] Logged: ${type.name} for list $listId');
    
    return activity;
  }

  /// Get all activities for a list (most recent first)
  Future<List<ListActivity>> getActivities(String listId, {int? limit}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_activitiesPrefix$listId';
    final json = prefs.getString(key);
    
    if (json == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(json);
      var activities = list
          .map((e) => ListActivity.fromJson(e as Map<String, dynamic>))
          .toList();
      
      // Sort by timestamp descending (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      if (limit != null && activities.length > limit) {
        activities = activities.take(limit).toList();
      }
      
      return activities;
    } catch (e) {
      debugPrint('❌ [LIST_ACTIVITY] Failed to parse activities: $e');
      return [];
    }
  }

  /// Clear all activities for a list
  Future<void> clearActivities(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_activitiesPrefix$listId');
  }

  /// Save an activity to local storage
  Future<void> _saveActivity(ListActivity activity) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_activitiesPrefix${activity.listId}';
    
    // Get existing activities
    List<Map<String, dynamic>> activities = [];
    final existing = prefs.getString(key);
    if (existing != null) {
      try {
        activities = List<Map<String, dynamic>>.from(jsonDecode(existing));
      } catch (_) {}
    }
    
    // Add new activity at the beginning
    activities.insert(0, activity.toJson());
    
    // Limit the number of activities stored
    if (activities.length > _maxActivitiesPerList) {
      activities = activities.take(_maxActivitiesPerList).toList();
    }
    
    await prefs.setString(key, jsonEncode(activities));
  }

  /// Send push notification for category changes to list members
  Future<void> notifyCategoryChange({
    required String listId,
    required String listName,
    required ListActivityType type,
    String? categoryName,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;

      // Get user display name
      final userResponse = await SupabaseService.instance
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .single();
      
      final userName = userResponse['display_name'] as String? ?? 'Someone';

      // Get all list members except current user
      final membersResponse = await SupabaseService.instance
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', userId);

      if ((membersResponse as List).isEmpty) {
        debugPrint('⚠️ [LIST_ACTIVITY] No other members to notify');
        return;
      }

      // Build notification message
      String title = listName;
      String body;
      
      switch (type) {
        case ListActivityType.categoryAdded:
          body = '$userName added category "$categoryName"';
          break;
        case ListActivityType.categoryRemoved:
          body = '$userName removed category "$categoryName"';
          break;
        case ListActivityType.categoryReordered:
          body = '$userName reordered categories';
          break;
        default:
          return; // Only handle category-related notifications
      }

      // Send push notifications to each member
      for (final member in membersResponse) {
        final memberId = member['user_id'] as String;
        
        try {
          final memberData = await SupabaseService.instance
              .from('users')
              .select('fcm_token')
              .eq('id', memberId)
              .single();
          
          final fcmToken = memberData['fcm_token'] as String?;
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await SupabaseService.instance.client.functions.invoke(
              'send-push-notification',
              body: {
                'token': fcmToken,
                'notification': {
                  'title': title,
                  'body': body,
                },
                'data': {
                  'type': 'list_activity',
                  'listId': listId,
                  'listName': listName,
                  'activityType': type.name,
                },
              },
            );
            debugPrint('✅ [LIST_ACTIVITY] Sent notification to member $memberId');
          }
        } catch (e) {
          debugPrint('❌ [LIST_ACTIVITY] Failed to notify member $memberId: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ [LIST_ACTIVITY] Failed to send category notifications: $e');
    }
  }
}
