/// Push and local notification service for Shoply
///
/// **AI: Critical Constraints**:
/// - ⚠️ Platform: iOS/Android only (check Platform.isIOS before using)
/// - ⚠️ Permissions: Must call requestPermissions() before showing notifications
/// - ⚠️ Initialization: Must call initialize() in main.dart before use
///
/// **AI: Usage Template**:
/// ```dart
/// // In main.dart
/// await NotificationService.instance.initialize();
/// await NotificationService.instance.requestPermissions();
///
/// // Show notification
/// await NotificationService.instance.notifyListUpdate(
///   listName: 'Groceries',
///   action: 'added "Milk"',
///   listId: 'list-123',
/// );
/// ```
///
/// **AI: Common Mistakes**:
/// - ❌ Don't forget to initialize in main.dart
/// - ❌ Don't skip permission request on iOS
/// - ❌ Don't show notifications without checking if initialized

import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/navigation_service.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize the notification service
  /// Call this in main.dart before runApp()
  Future<void> initialize() async {
    debugPrint('🔵 [NOTIFICATIONS] initialize() called');
    debugPrint('🔵 [NOTIFICATIONS] - Current _initialized: $_initialized');
    debugPrint('🔵 [NOTIFICATIONS] - Platform.isIOS: ${Platform.isIOS}');
    debugPrint('🔵 [NOTIFICATIONS] - Platform.isAndroid: ${Platform.isAndroid}');
    
    if (_initialized) {
      debugPrint('⚠️ [NOTIFICATIONS] Already initialized');
      return;
    }

    try {
      debugPrint('🔵 [NOTIFICATIONS] Setting up initialization settings...');
      
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettings = InitializationSettings(
        iOS: initializationSettingsIOS,
        android: initializationSettingsAndroid,
      );

      debugPrint('🔵 [NOTIFICATIONS] Calling _notifications.initialize()...');
      final bool? initialized = await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = initialized ?? false;
      debugPrint('✅ [NOTIFICATIONS] Initialized successfully: $_initialized');
      debugPrint('✅ [NOTIFICATIONS] Result from plugin: $initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATIONS] Initialization failed: $e');
      debugPrint('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
      _initialized = false;
    }
  }

  /// Handle notification tap
  /// Parse payload and navigate to relevant screen
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 [NOTIFICATIONS] Tapped: ${response.payload}');

    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!);
      final type = data['type'] as String?;
      final listId = data['listId'] as String?;
      final listName = data['listName'] as String?;
      final recipeId = data['recipeId'] as String?;

      debugPrint('🔔 [NOTIFICATIONS] Type: $type, Data: $data');

      // Navigate based on notification type
      switch (type) {
        case 'list_activity':
        case 'category_change':
          // Navigate to list activities screen for activity notifications
          if (listId != null) {
            NavigationService.instance.navigateToListActivities(listId, listName: listName);
          }
          break;
        case 'list_update':
        case 'list_invitation':
          // Navigate to list detail screen
          if (listId != null) {
            NavigationService.instance.navigateToList(listId, listName: listName);
          }
          break;
        case 'recipe_like':
        case 'recipe_comment':
          // Navigate to recipe detail screen
          if (recipeId != null) {
            NavigationService.instance.navigateToRecipe(recipeId);
          }
          break;
        default:
          debugPrint('⚠️ [NOTIFICATIONS] Unknown notification type: $type');
          // Default: navigate to list if listId is available
          if (listId != null) {
            NavigationService.instance.navigateToList(listId, listName: listName);
          }
      }
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Failed to parse payload: $e');
    }
  }

  /// Request notification permissions (iOS and Android 13+)
  /// Returns true if granted, false if denied, null if not determined
  Future<bool?> requestPermissions() async {
    debugPrint('🔵 [NOTIFICATIONS] requestPermissions() called');
    debugPrint('🔵 [NOTIFICATIONS] - Platform.isIOS: ${Platform.isIOS}');
    debugPrint('🔵 [NOTIFICATIONS] - Platform.isAndroid: ${Platform.isAndroid}');

    try {
      if (Platform.isIOS) {
        debugPrint('🔵 [NOTIFICATIONS] Requesting iOS permissions...');
        final bool? granted = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        debugPrint('✅ [NOTIFICATIONS] iOS permissions granted: $granted');
        return granted;
      } else if (Platform.isAndroid) {
        debugPrint('🔵 [NOTIFICATIONS] Requesting Android permissions...');
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final bool? granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('✅ [NOTIFICATIONS] Android permission granted: $granted');
          await androidPlugin.requestExactAlarmsPermission();
          return granted ?? true;
        }
        debugPrint('✅ [NOTIFICATIONS] Android < 13 - no permission needed');
        return true;
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATIONS] Permission request failed: $e');
      debugPrint('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Show notification for list update
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyListUpdate(
  ///   listName: 'Groceries',
  ///   itemName: 'Milk',
  ///   updatedBy: 'John',
  ///   listId: 'abc123',
  /// );
  /// ```
  Future<void> notifyListUpdate({
    required String listName,
    required String itemName,
    required String updatedBy,
    required String listId,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔵 [NOTIFICATIONS] notifyListUpdate() CALLED');
    print('🔵 [NOTIFICATIONS] - List: $listName');
    print('🔵 [NOTIFICATIONS] - Item: $itemName');
    print('🔵 [NOTIFICATIONS] - Updated by: $updatedBy');
    print('🔵 [NOTIFICATIONS] - List ID: $listId');
    print('🔵 [NOTIFICATIONS] - Initialized: $_initialized');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (!_initialized) {
      print('❌ [NOTIFICATIONS] NOT INITIALIZED - CANNOT SHOW NOTIFICATION');
      return;
    }

    print('🔔 [NOTIFICATIONS] Calling showNotification()...');
    await showNotification(
      id: listId.hashCode,
      title: '$listName',
      body: '$updatedBy added "$itemName"',
      payload: jsonEncode({
        'type': 'list_activity',
        'listId': listId,
        'listName': listName,
      }),
    );
    print('✅ [NOTIFICATIONS] _showNotification() completed');
  }

  /// Show notification for recipe rating
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyRecipeRating(
  ///   recipeName: 'Chocolate Cake',
  ///   rating: 5,
  ///   rater: 'John Doe',
  ///   recipeId: 'recipe-456',
  /// );
  /// ```
  Future<void> notifyRecipeRating({
    required String recipeName,
    required int rating,
    required String rater,
    required String recipeId,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ [NOTIFICATIONS] Not initialized - skipping recipe rating');
      return;
    }

    final stars = '⭐' * rating;
    await showNotification(
      id: recipeId.hashCode,
      title: 'New Rating!',
      body: '$rater rated "$recipeName" $stars ($rating/5)',
      payload: jsonEncode({
        'type': 'recipe_rating',
        'recipeId': recipeId,
      }),
    );
  }

  /// Show notification for recipe comment
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyRecipeComment(
  ///   recipeName: 'Chocolate Cake',
  ///   commenter: 'Jane Smith',
  ///   comment: 'Looks delicious!',
  ///   recipeId: 'recipe-456',
  /// );
  /// ```
  Future<void> notifyRecipeComment({
    required String recipeName,
    required String commenter,
    required String comment,
    required String recipeId,
  }) async {
    if (!_initialized) {
      debugPrint(
          '⚠️ [NOTIFICATIONS] Not initialized - skipping recipe comment');
      return;
    }

    // Truncate comment if too long
    final truncatedComment =
        comment.length > 50 ? '${comment.substring(0, 50)}...' : comment;

    await showNotification(
      id: recipeId.hashCode + 1, // +1 to avoid collision with like notification
      title: 'New Comment',
      body: '$commenter on "$recipeName": $truncatedComment',
      payload: jsonEncode({
        'type': 'recipe_comment',
        'recipeId': recipeId,
      }),
    );
  }

  /// Show notification for list invitation
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyListInvitation(
  ///   listName: 'Weekly Groceries',
  ///   inviter: 'Mom',
  ///   listId: 'list-789',
  /// );
  /// ```
  Future<void> notifyListInvitation({
    required String listName,
    required String inviter,
    required String listId,
  }) async {
    if (!_initialized) {
      debugPrint(
          '⚠️ [NOTIFICATIONS] Not initialized - skipping list invitation');
      return;
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'List Invitation',
      body: '$inviter invited you to join "$listName"',
      payload: jsonEncode({
        'type': 'list_invitation',
        'listId': listId,
      }),
    );
  }

  /// Show notification for shopping completion
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyShoppingComplete(
  ///   listName: 'Groceries',
  ///   completedBy: 'Dad',
  ///   listId: 'list-123',
  /// );
  /// ```
  Future<void> notifyShoppingComplete({
    required String listName,
    required String completedBy,
    required String listId,
  }) async {
    if (!_initialized) {
      debugPrint(
          '⚠️ [NOTIFICATIONS] Not initialized - skipping shopping complete');
      return;
    }

    await showNotification(
      id: listId.hashCode + 100,
      title: 'Shopping Complete!',
      body: '$completedBy completed shopping for "$listName"',
      payload: jsonEncode({
        'type': 'shopping_complete',
        'listId': listId,
      }),
    );
  }

  /// Show notification for item deletion
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyItemDeleted(
  ///   listName: 'Groceries',
  ///   itemName: 'Milk',
  ///   deletedBy: 'John',
  ///   listId: 'list-123',
  /// );
  /// ```
  Future<void> notifyItemDeleted({
    required String listName,
    required String itemName,
    required String deletedBy,
    required String listId,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ [NOTIFICATIONS] Not initialized - skipping item deletion');
      return;
    }

    await showNotification(
      id: listId.hashCode + itemName.hashCode,
      title: '$listName',
      body: '$deletedBy removed "$itemName"',
      payload: jsonEncode({
        'type': 'list_activity',
        'listId': listId,
        'listName': listName,
      }),
    );
  }

  /// Show notification for item checked/unchecked
  ///
  /// Example:
  /// ```dart
  /// await NotificationService.instance.notifyItemToggled(
  ///   listName: 'Groceries',
  ///   itemName: 'Milk',
  ///   isChecked: true,
  ///   toggledBy: 'Jane',
  ///   listId: 'list-123',
  /// );
  /// ```
  Future<void> notifyItemToggled({
    required String listName,
    required String itemName,
    required bool isChecked,
    required String toggledBy,
    required String listId,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ [NOTIFICATIONS] Not initialized - skipping item toggle');
      return;
    }

    final action = isChecked ? 'checked off' : 'unchecked';

    await showNotification(
      id: listId.hashCode + itemName.hashCode + 1,
      title: '$listName',
      body: '$toggledBy $action "$itemName"',
      payload: jsonEncode({
        'type': 'list_activity',
        'listId': listId,
        'listName': listName,
      }),
    );
  }

  /// Generic method to show a notification
  ///
  /// Can be used by FCMService or other services
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔔 [NOTIFICATIONS] _showNotification() ENTRY');
    print('🔔 [NOTIFICATIONS] - ID: $id');
    print('🔔 [NOTIFICATIONS] - Title: $title');
    print('🔔 [NOTIFICATIONS] - Body: $body');
    print('🔔 [NOTIFICATIONS] - Payload: $payload');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    const androidDetails = AndroidNotificationDetails(
      'shoply_channel',
      'Shoply Notifications',
      channelDescription: 'Notifications for lists, recipes, and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      print('🔔 [NOTIFICATIONS] Calling _notifications.show()...');
      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      print('✅ [NOTIFICATIONS] Successfully showed notification!');
      print('✅ [NOTIFICATIONS] - Title: $title');
      print('✅ [NOTIFICATIONS] - Body: $body');
    } catch (e, stackTrace) {
      print('❌ [NOTIFICATIONS] Failed to show notification: $e');
      print('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
    }
  }

  /// Clear all notifications
  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('🔔 [NOTIFICATIONS] Cleared all notifications');
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Failed to clear: $e');
    }
  }

  /// Cancel a specific notification by ID
  Future<void> cancel(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('🔔 [NOTIFICATIONS] Cancelled notification: $id');
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Failed to cancel: $e');
    }
  }
}
