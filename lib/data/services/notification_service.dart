/// Local notification service for Avo
///
/// **AI: Critical Constraints**:
/// - ⚠️ Platform: iOS/Android only (check Platform.isIOS before using)
/// - ⚠️ Permissions: [initialize] never asks. The prompt comes only from
///   `NotificationPermissionService.requestIfUseful`, at a moment where a
///   notification helps (first shared list, a reminder switched on).
/// - ⚠️ Initialization: the start-up scheduler in main.dart calls
///   [initialize] right after the first frame; show/schedule calls before
///   that are dropped.
/// - ⚠️ Preferences: every show/schedule call is gated by
///   [NotificationPreferencesService] (master switch + optional category).
///   Pass the most specific [NotificationCategory] you can so user toggles
///   are honored.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/localization/app_translations.dart';
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
  Future<void>? _initializing;
  bool _timeZonesLoaded = false;

  /// iOS init settings. They request nothing: an Avo start never shows the
  /// notification prompt (Kap. 20 §2.2 "nie beim Start").
  static const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  /// Sets up the plugin without a permission prompt and routes the
  /// notification the app was opened with. Safe to call more than once.
  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      const settings = InitializationSettings(
        iOS: darwinSettings,
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      final bool? initialized = await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = initialized ?? false;
      debugPrint('✅ [NOTIFICATIONS] Initialized: $_initialized');
      if (_initialized) await _routeLaunchNotification();
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATIONS] Initialization failed: $e');
      debugPrint('❌ [NOTIFICATIONS] Stack trace: $stackTrace');
      _initialized = false;
    }
  }

  /// A tap that arrives before [initialize] (cold start from a reminder)
  /// is kept by the plugin as launch details instead of a callback.
  Future<void> _routeLaunchNotification() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      _route(details.notificationResponse?.payload);
    } catch (e) {
      debugPrint('⚠️ [NOTIFICATIONS] Launch notification check failed: $e');
    }
  }

  /// The timezone database (326 KB) is parsed on the first scheduled
  /// reminder, not at start.
  void _ensureTimeZones() {
    if (_timeZonesLoaded) return;
    tzdata.initializeTimeZones();
    _timeZonesLoaded = true;
  }

  void _onNotificationTapped(NotificationResponse response) =>
      _route(response.payload);

  void _route(String? payload) {
    final data = payloadData(payload);
    if (data == null) return;
    debugPrint('🔔 [NOTIFICATIONS] Opened from notification (${data['type']})');
    NavigationService.instance.handleNotificationData(data);
  }

  /// The JSON object a notification carries, or null for an empty,
  /// broken or non-object payload.
  @visibleForTesting
  static Map<String, dynamic>? payloadData(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Failed to parse payload: $e');
      return null;
    }
  }

  /// Whether notifications are currently allowed. Never prompts.
  Future<bool> hasPermission() async {
    try {
      if (Platform.isIOS) {
        final options = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      if (Platform.isAndroid) {
        return await _notifications
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      }
    } catch (e) {
      debugPrint('⚠️ [NOTIFICATIONS] Permission check failed: $e');
    }
    return false;
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
      _ensureTimeZones();
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

  // ------------------------------------------------------ Pro trial (A9b-1)

  /// The one id of the trial reminder: a new trial replaces the old one.
  static const int proTrialReminderId = 700010;

  /// How long before the trial ends the reminder comes (day 12 of 14).
  static const Duration proTrialReminderLead = Duration(days: 2);

  /// When the reminder for a trial ending at [trialEndsAt] fires; null when
  /// that moment is not after [now].
  @visibleForTesting
  static DateTime? proTrialReminderTime(DateTime trialEndsAt, DateTime now) {
    final at = trialEndsAt.subtract(proTrialReminderLead);
    return at.isAfter(now) ? at : null;
  }

  /// The reminder's sentence in [language], with Avo Pro's yearly price as
  /// the App Store gave it to the caller.
  @visibleForTesting
  static String proTrialReminderBody(String language, String yearlyPrice) =>
      AppTranslations.get(
        'notif_pro_trial_ends',
        language,
        params: {'pro': AppBrand.proName, 'price': yearlyPrice},
      );

  /// What a tap on the reminder carries: the paywall (`shoply://pro`).
  static const String proTrialReminderPayload =
      '{"type":"pro_trial_reminder","link":"shoply://pro"}';

  /// Replaces the permission check in tests.
  @visibleForTesting
  Future<bool> Function()? debugHasPermission;

  /// Replaces the plugin's scheduling in tests (id, title, body, time).
  @visibleForTesting
  Future<void> Function(int id, String title, String body, DateTime at)?
      debugSchedule;

  /// Plans "Deine Avo Pro-Testphase endet übermorgen. Danach {price} pro
  /// Jahr." for two days before [trialEndsAt] (Teil A calls it after a
  /// purchase with a trial; B knows no prices, so A passes [yearlyPrice]).
  /// A tap opens the paywall.
  ///
  /// Returns `false` and plans nothing when notifications are not allowed
  /// (A then shows the hint in the app), when they are switched off in the
  /// app, or when that day has passed; `true` once it is planned.
  Future<bool> scheduleProTrialReminder(
    DateTime trialEndsAt, {
    required String yearlyPrice,
  }) async {
    final at = proTrialReminderTime(trialEndsAt, DateTime.now());
    if (at == null) {
      debugPrint('⚠️ [NOTIFICATIONS] Trial reminder day has passed, skipping');
      return false;
    }
    final schedule = debugSchedule;
    if (schedule == null && !_initialized) {
      debugPrint('❌ [NOTIFICATIONS] Not initialized - no trial reminder');
      return false;
    }
    final allowed = await (debugHasPermission ?? hasPermission)();
    if (!allowed) {
      debugPrint('🔕 [NOTIFICATIONS] No permission - no trial reminder');
      return false;
    }
    if (!await NotificationPreferencesService.instance.shouldShow(null)) {
      debugPrint('🔕 [NOTIFICATIONS] Switched off - no trial reminder');
      return false;
    }
    final language = await appLanguage();
    final body = proTrialReminderBody(language, yearlyPrice);
    try {
      if (schedule != null) {
        await schedule(proTrialReminderId, AppBrand.proName, body, at);
      } else {
        await _notifications.cancel(proTrialReminderId);
        _ensureTimeZones();
        await _notifications.zonedSchedule(
          proTrialReminderId,
          AppBrand.proName,
          body,
          tz.TZDateTime.from(at, tz.local),
          _notificationDetails,
          payload: proTrialReminderPayload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      debugPrint('⏰ [NOTIFICATIONS] Trial reminder planned for $at');
      return true;
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Trial reminder failed: $e');
      return false;
    }
  }

  /// Removes the trial reminder (trial cancelled or ended early).
  Future<void> cancelProTrialReminder() => cancel(proTrialReminderId);

  /// The app language as `LanguageNotifier` resolves it: the saved choice,
  /// or the device locale for 'system' / unset (falling back to 'en').
  static Future<String> appLanguage() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Same key `LanguageNotifier` saves it under ('en', 'de', 'system').
      saved = prefs.getString('language');
    } catch (_) {}
    if (saved == 'en' || saved == 'de') return saved!;
    final system = PlatformDispatcher.instance.locale.languageCode;
    return system == 'de' ? 'de' : 'en';
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
