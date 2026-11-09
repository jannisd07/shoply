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
    debugPrint(
      '🔔 [FCM] Background message received (${message.data['type']})',
    );
  } catch (e) {
    debugPrint('❌ [FCM] Background message error: $e');
  }
}

/// The own row's `users.fcm_token`.
abstract interface class FcmTokenStore {
  /// The stored token, or null when none is stored or the row is missing.
  Future<String?> read(String userId);

  /// Writes [token]; whether a row was updated. An update that RLS or a
  /// missing row lets match nothing returns no error, so this is the only
  /// sign that the write landed.
  Future<bool> write(String userId, String token);

  /// Clears the column only while it still holds [token]; a newer token
  /// from another device stays.
  Future<void> clear(String userId, String token);
}

class SupabaseFcmTokenStore implements FcmTokenStore {
  const SupabaseFcmTokenStore();

  @override
  Future<String?> read(String userId) async {
    final row = await SupabaseService.instance.client
        .from('users')
        .select('fcm_token')
        .eq('id', userId)
        .maybeSingle();
    return row?['fcm_token'] as String?;
  }

  @override
  Future<bool> write(String userId, String token) async {
    final rows = await SupabaseService.instance.client
        .from('users')
        .update({
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select('id');
    return rows.isNotEmpty;
  }

  @override
  Future<void> clear(String userId, String token) async {
    await SupabaseService.instance.client
        .from('users')
        .update({
          'fcm_token': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .eq('fcm_token', token);
  }
}

/// Keeps `users.fcm_token` on this device's token with as few writes as
/// possible. The column holds one token per account, and other devices
/// overwrite it (or clear it through the master switch), so every save
/// compares with the server value instead of a local memory: one read, and
/// a write only when the value differs. Saves of the same token at the same
/// time (token refresh and the first fetch) share one round trip.
class FcmTokenSync {
  FcmTokenSync([this._store = const SupabaseFcmTokenStore()]);

  final FcmTokenStore _store;
  final Map<String, Future<bool>> _inFlight = {};

  /// Whether the server holds [token] for [userId] afterwards.
  Future<bool> save(String userId, String token) {
    final key = '$userId|$token';
    // A block body: `=> _inFlight.remove(key)` would return this very
    // future to whenComplete, which then waits on itself.
    return _inFlight[key] ??= _save(userId, token).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<bool> _save(String userId, String token) async {
    if (await _store.read(userId) == token) {
      debugPrint('🔵 [FCM] Token unchanged, no write');
      return true;
    }
    final written = await _store.write(userId, token);
    debugPrint(
      written
          ? '✅ [FCM] Token saved'
          : '⚠️ [FCM] Token write matched no row, retried on the next save',
    );
    return written;
  }

  /// Takes [token] off [userId]'s row unless another device replaced it.
  Future<void> release(String userId, String token) =>
      _store.clear(userId, token);
}

class FCMService {
  static FCMService? _instance;
  static FCMService get instance {
    _instance ??= FCMService._();
    return _instance!;
  }

  FCMService._();

  /// Only touched after Firebase is configured ([initialize] runs then).
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FcmTokenSync _tokens = FcmTokenSync();
  String? _fcmToken;
  bool _started = false;

  /// Push listeners and the notification the app was opened with. Never
  /// asks for permission: the token is fetched only when notifications are
  /// already allowed, otherwise after [onPermissionGranted]. Call once
  /// Firebase is configured; later calls do nothing.
  Future<void> initialize() async {
    if (_started) return;
    try {
      debugPrint('🔵 [FCM] Initializing...');

      _fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _saveTokenToDatabase(token);
      });
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      _started = true;

      // Opened from a terminated state via a push.
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      if (await _isAllowed()) {
        // On iOS the APNs token can take seconds; start must not wait.
        unawaited(_getTokenWithRetry());
      } else {
        debugPrint('🔵 [FCM] Notifications not allowed yet, no token');
      }
      debugPrint('✅ [FCM] Initialized');
    } catch (e) {
      debugPrint('❌ [FCM] Initialization failed: $e');
    }
  }

  /// Called by `NotificationPermissionService` right after the user allowed
  /// notifications: fetches and saves the token without waiting for the
  /// next start.
  Future<void> onPermissionGranted() async {
    if (!_started) return;
    unawaited(_getTokenWithRetry());
  }

  /// Reads the current permission state; never shows the prompt.
  Future<bool> _isAllowed() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
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

  /// Save FCM token to Supabase. `users.fcm_token` holds one token per
  /// account, so pushes go to the device that saved last; every save
  /// re-checks the server value, so this device takes the column back on
  /// its next start or sign-in. Writes only when the stored value differs.
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

      await _tokens.save(userId, token);
    } catch (e) {
      debugPrint('❌ [FCM] Failed to save token: $e');
    }
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '🔔 [FCM] Foreground message received (${message.data['type']})',
    );

    if (message.notification != null) {
      // Show local notification when app is in foreground.
      // showNotification enforces the user's notification preferences.
      NotificationService.instance.showNotification(
        id: message.messageId.hashCode,
        title: message.notification!.title ?? 'Avo',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
        category: notificationCategoryForPushType(
          message.data['type'] as String?,
        ),
      );
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

  /// Save FCM token to database for current user (after sign-in, when the
  /// master switch goes on). Does nothing before [initialize] or while
  /// notifications are not allowed.
  Future<void> saveTokenForCurrentUser() async {
    if (!_started) return;
    try {
      if (!await _isAllowed()) return;
      if (_fcmToken == null &&
          (!Platform.isIOS || await _fcm.getAPNSToken() != null)) {
        _fcmToken = await _fcm.getToken();
      }
    } catch (e) {
      debugPrint('❌ [FCM] Failed to get token: $e');
    }

    if (_fcmToken != null) {
      await _saveTokenToDatabase(_fcmToken!);
    } else {
      debugPrint('⚠️ [FCM] Still no FCM token available');
    }
  }

  /// Takes this device's token off the signed-in account, so its pushes
  /// (list activity with names and items) stop reaching this device. Call
  /// while the session is still valid, right before signing out; after
  /// sign-out RLS no longer lets the app touch the row. A newer token from
  /// another device stays.
  Future<void> releaseDeviceToken() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null || !_started) return;
      final token = _fcmToken ?? await _fcm.getToken();
      if (token == null) return;
      await _tokens.release(userId, token);
      debugPrint('🔕 [FCM] Device token released');
    } catch (e) {
      debugPrint('⚠️ [FCM] Failed to release device token: $e');
    }
  }

  /// Remove the stored FCM token for the current user so remote pushes stop
  /// being delivered (used when the master notification switch is turned off).
  Future<void> removeTokenForCurrentUser() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.instance.client
          .from('users')
          .update({
            'fcm_token': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('🔕 [FCM] Token removed from database');
    } catch (e) {
      debugPrint('❌ [FCM] Failed to remove token: $e');
    }
  }
}

/// The settings toggle a push payload `type` belongs to; null (only the
/// master switch) for unknown types. The Wochenplan reminder is local and
/// passes [NotificationCategory.planReminder] itself.
NotificationCategory? notificationCategoryForPushType(String? type) {
  switch (type) {
    case 'list_activity':
    case 'category_change':
    case 'list_update':
      return NotificationCategory.listActivity;
    case 'list_invitation':
      return NotificationCategory.listInvitations;
    case 'shopping_started':
      return NotificationCategory.shoppingStarted;
    case 'shopping_complete':
      return NotificationCategory.shoppingCompleted;
    case 'expense_split':
    case 'split_reminder':
      return NotificationCategory.costSplitOpen;
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
