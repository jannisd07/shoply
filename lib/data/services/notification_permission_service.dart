import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/fcm_service.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/notification_service.dart';

/// The one place that shows the system notification prompt.
///
/// The app never asks at start. A screen calls [requestIfUseful] when a
/// notification clearly helps (a list is shared for the first time, a
/// reminder is switched on), after it explained why in its own words. This
/// service explains nothing itself and shows the iOS prompt at most once per
/// install; later calls only report the decision.
class NotificationPermissionService {
  NotificationPermissionService({
    bool? isSupported,
    Future<bool> Function()? prompt,
    Future<bool> Function()? isGranted,
    Future<void> Function()? onGranted,
  }) : _isSupported = isSupported ?? (Platform.isIOS || Platform.isAndroid),
       _prompt = prompt ?? _systemPrompt,
       _isGranted = isGranted ?? NotificationService.instance.hasPermission,
       _onGranted = onGranted ?? _afterGrant;

  static final NotificationPermissionService instance =
      NotificationPermissionService();

  /// SharedPreferences flag: the prompt was shown on this install.
  static const promptedKey = 'notif_permission_prompted_v1';

  final bool _isSupported;
  final Future<bool> Function() _prompt;
  final Future<bool> Function() _isGranted;
  final Future<void> Function() _onGranted;
  Future<bool>? _inFlight;

  static Future<bool> _systemPrompt() async {
    await NotificationService.instance.initialize();
    return await NotificationService.instance.requestPermissions() ?? false;
  }

  /// Push token and Avo's reminders start right away instead of on the
  /// next start (both wait for the permission).
  static Future<void> _afterGrant() async {
    await FCMService.instance.onPermissionGranted();
    final reminders = MascotNotificationService.instance;
    await reminders.rearmRestockReminder(force: true);
    await reminders.rearmDinnerIdeasReminder(force: true);
  }

  /// Whether notifications are allowed afterwards. Shows the system prompt
  /// only if it was never shown; [reason] (e.g. `list_shared`,
  /// `reminder_on`) is only logged.
  Future<bool> requestIfUseful(String reason) =>
      _inFlight ??= _request(reason).whenComplete(() => _inFlight = null);

  Future<bool> _request(String reason) async {
    if (!_isSupported) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(promptedKey) ?? false) return await _isGranted();

      await prefs.setBool(promptedKey, true);
      debugPrint('🔵 [NOTIF_PERMISSION] Asking for notifications ($reason)');
      final granted = await _prompt();
      debugPrint('✅ [NOTIF_PERMISSION] Decision ($reason): $granted');
      if (granted) await _onGranted();
      return granted;
    } catch (e) {
      debugPrint('❌ [NOTIF_PERMISSION] Request failed ($reason): $e');
      return false;
    }
  }
}
