import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/navigation_service.dart';
import 'dart:io';

/// Handle Firebase Cloud Messaging background messages
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  try {
    debugPrint('🔔 [FCM] Background message received');
    debugPrint('🔔 [FCM] Title: ${message.notification?.title}');
    debugPrint('🔔 [FCM] Body: ${message.notification?.body}');
    // Don't do heavy processing here - just log
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

      // Delete old token and get a fresh one to fix SENDER_ID_MISMATCH
      debugPrint('🔄 [FCM] Deleting old token to get fresh one...');
      try {
        await _fcm.deleteToken();
        debugPrint('✅ [FCM] Old token deleted');
      } catch (e) {
        debugPrint('⚠️ [FCM] Could not delete old token: $e');
      }
      
      // On iOS, wait for APNs token before getting FCM token
      if (Platform.isIOS) {
        await _getTokenWithRetry();
      } else {
        _fcmToken = await _fcm.getToken();
        debugPrint('📱 [FCM] Token: $_fcmToken');
        if (_fcmToken != null) {
          await _saveTokenToDatabase(_fcmToken!);
        }
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

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
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] Initialization failed: $e');
      debugPrint('❌ [FCM] Stack trace: $stackTrace');
    }
  }

  /// Get FCM token with retry for iOS (waits for APNs token)
  Future<void> _getTokenWithRetry() async {
    const maxRetries = 10;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 [FCM] Attempt $attempt/$maxRetries to get token...');
        
        // Check if APNs token is available
        final apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⏳ [FCM] APNs token not ready yet, waiting...');
          await Future.delayed(retryDelay);
          continue;
        }
        
        debugPrint('✅ [FCM] APNs token received!');
        _fcmToken = await _fcm.getToken();
        debugPrint('📱 [FCM] FCM Token: ${_fcmToken?.substring(0, 50)}...');
        
        if (_fcmToken != null) {
          await _saveTokenToDatabase(_fcmToken!);
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [FCM] Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    
    debugPrint('❌ [FCM] Failed to get token after $maxRetries attempts');
    debugPrint('❌ [FCM] This usually means Push Notifications are not properly configured');
    debugPrint('❌ [FCM] Check: 1) APNs key in Firebase, 2) Entitlements, 3) Provisioning Profile');
  }

  /// Save FCM token to Supabase
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ [FCM] No user logged in, skipping token save');
        return;
      }

      debugPrint('🔥🔥🔥 [FCM] SAVING TOKEN TO DATABASE');
      debugPrint('🔥 User ID: $userId');
      debugPrint('🔥 Token (first 50 chars): ${token.substring(0, 50)}...');

      await SupabaseService.instance.client
          .from('users')
          .update({
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('✅✅✅ [FCM] TOKEN SUCCESSFULLY SAVED TO DATABASE!');
      debugPrint('✅ User $userId now has FCM token in database');
    } catch (e) {
      debugPrint('❌❌❌ [FCM] FAILED TO SAVE TOKEN: $e');
    }
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [FCM] Foreground message received');
    debugPrint('🔔 [FCM] - Title: ${message.notification?.title}');
    debugPrint('🔔 [FCM] - Body: ${message.notification?.body}');
    debugPrint('🔔 [FCM] - Data: ${message.data}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (message.notification != null) {
      // Show local notification when app is in foreground
      NotificationService.instance.showNotification(
        id: message.messageId.hashCode,
        title: message.notification!.title ?? 'Shoply',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap - navigate to relevant screen
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔔 [FCM] Notification tapped!');
    debugPrint('🔔 [FCM] - Data: ${message.data}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final type = message.data['type'] as String?;
    final listId = message.data['listId'] as String?;
    final listName = message.data['listName'] as String?;
    final recipeId = message.data['recipeId'] as String?;

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
      case 'recipe_rating':
      case 'recipe_comment':
        // Navigate to recipe detail screen
        if (recipeId != null) {
          NavigationService.instance.navigateToRecipe(recipeId);
        }
        break;
      default:
        debugPrint('⚠️ [FCM] Unknown notification type: $type');
        // Default: navigate to list if listId is available
        if (listId != null) {
          NavigationService.instance.navigateToList(listId, listName: listName);
        }
    }
  }

  /// Get current FCM token
  String? get token => _fcmToken;

  /// Check if FCM is available
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Save FCM token to database for current user
  /// Call this after user logs in to ensure token is saved
  Future<void> saveTokenForCurrentUser() async {
    debugPrint('🔵 [FCM] saveTokenForCurrentUser() called');
    
    if (_fcmToken == null) {
      debugPrint('⚠️ [FCM] No FCM token available - trying to get one');
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
}
