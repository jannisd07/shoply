import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/navigation_service.dart';

/// Handle Firebase Cloud Messaging background messages
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  try {
    // Don't do heavy processing here - just log
    debugPrint('🔔 [FCM] Background message received (${message.data['type']})');
  } catch (e) {
    debugPrint('❌ [FCM] Background message error: $e');
  }
}

class FCMService {
  static FCMService? _instance;
  static FCMService get instance {
    _instance ??= FCMService._();
    return _instance!;
  }

  FCMService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    try {
      debugPrint('🔵 [FCM] Initializing...');

      // Request permission
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [FCM] User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ [FCM] User granted provisional permission');
      } else {
        debugPrint('❌ [FCM] User declined permission');
        return;
      }

      // Fetch the token in the background: on iOS it can take several
      // seconds until the APNs token exists, and app start must not wait.
      unawaited(_getTokenWithRetry());

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _saveTokenToDatabase(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      debugPrint('✅ [FCM] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [FCM] Initialization failed: $e');
    }
  }

  /// Get the FCM token and save it. On iOS the APNs token must exist first,
  /// so retry for up to ~20 s.
  Future<void> _getTokenWithRetry() async {
    const maxRetries = 10;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (Platform.isIOS && await _fcm.getAPNSToken() == null) {
          await Future.delayed(retryDelay);
          continue;
        }

        _fcmToken = await _fcm.getToken();
        if (_fcmToken != null) {
          debugPrint('✅ [FCM] Token received');
          await _saveTokenToDatabase(_fcmToken!);
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [FCM] Token attempt $attempt failed: $e');
      }
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    // Usually means push is misconfigured (APNs key in Firebase,
    // entitlements or provisioning profile).
    debugPrint('❌ [FCM] Failed to get token after $maxRetries attempts');
  }

  /// Save FCM token to Supabase. Stored in the single `users.fcm_token`
  /// column, so only the most recently used device receives pushes.
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ [FCM] No user logged in, skipping token save');
        return;
      }

      // Respect the master notification switch: don't resurrect the token
      // (e.g. on token refresh or re-login) while notifications are off.
      if (!await NotificationPreferencesService.instance.isMasterEnabled()) {
        debugPrint('🔕 [FCM] Notifications disabled — not saving token');
        return;
      }

      await SupabaseService.instance.client
          .from('users')
          .update({
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('✅ [FCM] Token saved');
    } catch (e) {
      debugPrint('❌ [FCM] Failed to save token: $e');
    }
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM] Foreground message received (${message.data['type']})');

    if (message.notification != null) {
      // Show local notification when app is in foreground.
      // showNotification enforces the user's notification preferences.
      NotificationService.instance.showNotification(
        id: message.messageId.hashCode,
        title: message.notification!.title ?? 'Avo',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
        category: _categoryForType(message.data['type'] as String?),
      );
    }
  }

  /// Map a push payload `type` to the user's settings toggle it belongs to.
  /// Unknown types fall back to the master switch only.
  NotificationCategory? _categoryForType(String? type) {
    switch (type) {
      case 'list_activity':
      case 'category_change':
      case 'list_update':
        return NotificationCategory.listActivity;
      case 'list_invitation':
        return NotificationCategory.listInvitations;
      case 'shopping_complete':
        return NotificationCategory.shoppingCompleted;
      case 'recipe_rating':
      case 'recipe_like':
        return NotificationCategory.recipeLikes;
      case 'recipe_comment':
        return NotificationCategory.recipeComments;
      case 'new_recipe':
      case 'recipe_of_the_day':
        return NotificationCategory.newRecipes;
      default:
        return null;
    }
  }

  /// Handle notification tap - navigate to relevant screen
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 [FCM] Notification tapped (${message.data['type']})');

    NavigationService.instance.handleNotificationData(message.data);
  }

  /// Get current FCM token
  String? get token => _fcmToken;

  /// Check if FCM is available
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Save FCM token to database for current user
  /// Call this after user logs in to ensure token is saved
  Future<void> saveTokenForCurrentUser() async {
    if (_fcmToken == null) {
      // Try to get token if we don't have one
      try {
        if (Platform.isIOS) {
          final apnsToken = await _fcm.getAPNSToken();
          if (apnsToken != null) {
            _fcmToken = await _fcm.getToken();
          }
        } else {
          _fcmToken = await _fcm.getToken();
        }
      } catch (e) {
        debugPrint('❌ [FCM] Failed to get token: $e');
      }
    }

    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!);
    } else {
      debugPrint('⚠️ [FCM] Still no FCM token available');
    }
  }

  /// Remove the stored FCM token for the current user so remote pushes stop
  /// being delivered (used when the master notification switch is turned off).
  Future<void> removeTokenForCurrentUser() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.instance.client.from('users').update({
        'fcm_token': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('🔕 [FCM] Token removed from database');
    } catch (e) {
      debugPrint('❌ [FCM] Failed to remove token: $e');
    }
  }
}
