import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Tracks list activities (item added, category reordered, ...).
///
/// Activities are stored in this device's SharedPreferences only (last 100
/// per list), so a shared list shows just this user's own actions from this
/// phone. Showing co-members' activity needs a server-side table.
class ListActivityService {
  static final ListActivityService _instance = ListActivityService._internal();
  factory ListActivityService() => _instance;
  ListActivityService._internal();

  static const int _maxActivitiesPerList = 100;
  static const String _activitiesPrefix = 'list_activities_';

  String? _cachedNameUserId;
  String? _cachedUserName;

  /// The current user's display name, fetched once per signed-in user.
  Future<String> _currentUserName(String userId) async {
    if (_cachedNameUserId == userId && _cachedUserName != null) {
      return _cachedUserName!;
    }
    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('display_name')
          .eq('id', userId)
          .single();
      final name = response['display_name'] as String?;
      if (name != null) {
        _cachedNameUserId = userId;
        _cachedUserName = name;
      }
      return name ?? 'Someone';
    } catch (e) {
      debugPrint('⚠️ [LIST_ACTIVITY] Failed to get user name: $e');
      return 'Someone';
    }
  }

  /// Log a new activity for a list
  Future<ListActivity> logActivity({
    required String listId,
    required ListActivityType type,
    Map<String, dynamic>? metadata,
  }) async {
    final user = SupabaseService.instance.currentUser;
    final userId = user?.id ?? 'unknown';
    final userName =
        user != null ? await _currentUserName(user.id) : 'Someone';

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

      final userName = await _currentUserName(userId);

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

      // One query for all members' tokens, then send in parallel.
      final memberIds =
          membersResponse.map((m) => m['user_id'] as String).toList();
      final tokenRows = await SupabaseService.instance
          .from('users')
          .select('id, fcm_token')
          .inFilter('id', memberIds);

      await Future.wait(tokenRows.map((row) async {
        final fcmToken = row['fcm_token'] as String?;
        if (fcmToken == null || fcmToken.isEmpty) return;
        try {
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
        } catch (e) {
          debugPrint('❌ [LIST_ACTIVITY] Failed to notify member ${row['id']}: $e');
        }
      }));
    } catch (e) {
      debugPrint('❌ [LIST_ACTIVITY] Failed to send category notifications: $e');
    }
  }
}
