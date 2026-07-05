/// Local notification service for Avo
///
/// **AI: Critical Constraints**:
/// - ⚠️ Platform: iOS/Android only (check Platform.isIOS before using)
/// - ⚠️ Permissions: Must call requestPermissions() before showing notifications
/// - ⚠️ Initialization: Must call initialize() in main.dart before use
/// - ⚠️ Preferences: every show/schedule call is gated by
///   [NotificationPreferencesService] (master switch + optional category).
///   Pass the most specific [NotificationCategory] you can so user toggles
///   are honored.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shoply/data/services/navigation_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';

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

    if (_initialized) {
      debugPrint('⚠️ [NOTIFICATIONS] Already initialized');
      return;
    }

    try {
      // Timezone db for zonedSchedule (scheduled reminders).
      tzdata.initializeTimeZones();

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

      final bool? initialized = await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = initialized ?? false;
      debugPrint('✅ [NOTIFICATIONS] Initialized successfully: $_initialized');
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
        case 'avo_restock':
          // Opening the app is enough — the home screen shows the
          // restock card with add/dismiss actions.
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

    try {
      if (Platform.isIOS) {
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
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final bool? granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('✅ [NOTIFICATIONS] Android permission granted: $granted');
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

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'shoply_channel',
      'Avo Notifications',
      channelDescription: 'Notifications for lists, recipes, and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Show a notification immediately.
  ///
  /// [category] enables the user's per-category settings toggle; the master
  /// switch (`users.notification_enabled`) is always enforced.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationCategory? category,
  }) async {
    if (!_initialized) {
      debugPrint('❌ [NOTIFICATIONS] Not initialized - cannot show');
      return;
    }

    if (!await NotificationPreferencesService.instance.shouldShow(category)) {
      debugPrint(
          '🔕 [NOTIFICATIONS] Suppressed by preferences (${category?.name ?? 'master'}): $title');
      return;
    }

    try {
      await _notifications.show(
        id,
        title,
        body,
        _notificationDetails,
        payload: payload,
      );
      debugPrint('✅ [NOTIFICATIONS] Showed: $title — $body');
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATIONS] Failed to show notification: $e');
      debugPrint('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
    }
  }

  /// Schedule a one-shot notification for a future point in time.
  ///
  /// Preferences are checked at scheduling time; callers that re-arm on a
  /// trigger (e.g. Avo's restock reminder) should cancel their id first so
  /// a disabled toggle also clears anything already scheduled.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? payload,
    NotificationCategory? category,
  }) async {
    if (!_initialized) {
      debugPrint('❌ [NOTIFICATIONS] Not initialized - cannot schedule');
      return;
    }

    if (!await NotificationPreferencesService.instance.shouldShow(category)) {
      debugPrint(
          '🔕 [NOTIFICATIONS] Schedule suppressed by preferences (${category?.name ?? 'master'}): $title');
      return;
    }

    if (!scheduledFor.isAfter(DateTime.now())) {
      debugPrint('⚠️ [NOTIFICATIONS] Schedule time is in the past, skipping');
      return;
    }

    try {
      // tz.local defaults to UTC when no explicit location is set, but
      // TZDateTime.from converts the absolute instant — the notification
      // still fires at the intended local wall-clock moment.
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledFor, tz.local),
        _notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('⏰ [NOTIFICATIONS] Scheduled #$id for $scheduledFor: $title');
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATIONS] Failed to schedule: $e');
      debugPrint('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
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
