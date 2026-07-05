import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/fcm_service.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Notification categories, each backed by a device-local preference toggle.
///
/// The [prefsKey]s of the seven pre-existing categories intentionally match
/// the keys the notifications settings screen has always written, so toggles
/// users already saved keep their value now that they are actually enforced.
enum NotificationCategory {
  listActivity('notif_items_added', true),
  shoppingCompleted('notif_shopping_completed', true),
  listInvitations('notif_list_invitations', true),
  recipeLikes('notif_recipe_likes', true),
  recipeComments('notif_comments', true),
  newRecipes('notif_new_recipes', false),
  weeklySummary('notif_weekly_summary', true),
  avoNudges('notif_avo_nudges', true);

  final String prefsKey;
  final bool defaultValue;
  const NotificationCategory(this.prefsKey, this.defaultValue);
}

/// The single enforced notification gate.
///
/// Master switch: `users.notification_enabled` in Supabase (account-scoped,
/// also settable through Avo chat via [AvoSettingsBridge]), mirrored into
/// SharedPreferences so the gate can be checked synchronously/offline.
/// Category switches: device-local SharedPreferences toggles.
///
/// Every local notification passes through
/// [NotificationService.showNotification], which consults [shouldShow] —
/// so this gate really is enforced, not decorative. Disabling the master
/// switch additionally clears the user's FCM token from the DB so remote
/// pushes stop being delivered while the app is closed.
class NotificationPreferencesService {
  static NotificationPreferencesService? _instance;
  static NotificationPreferencesService get instance {
    _instance ??= NotificationPreferencesService._();
    return _instance!;
  }

  NotificationPreferencesService._();

  static const String _masterCacheKey = 'notif_master_enabled';

  /// Whether notifications are enabled at all (cached master switch).
  Future<bool> isMasterEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_masterCacheKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Whether a specific category is enabled (does NOT include master gate).
  Future<bool> isCategoryEnabled(NotificationCategory category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(category.prefsKey) ?? category.defaultValue;
    } catch (e) {
      return category.defaultValue;
    }
  }

  /// The gate every notification display/schedule path checks:
  /// master switch AND (when given) the category toggle.
  Future<bool> shouldShow(NotificationCategory? category) async {
    if (!await isMasterEnabled()) return false;
    if (category == null) return true;
    return isCategoryEnabled(category);
  }

  Future<void> setCategoryEnabled(
      NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(category.prefsKey, enabled);
    debugPrint('🔔 [NOTIF_PREFS] ${category.name} -> $enabled');
  }

  /// Set the master switch: persists to `users.notification_enabled`,
  /// mirrors into the local cache, and adds/removes the FCM token so
  /// remote pushes honor the switch too.
  Future<void> setMasterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_masterCacheKey, enabled);

    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId != null) {
        await SupabaseService.instance.client.from('users').update({
          'notification_enabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }
    } catch (e) {
      debugPrint('⚠️ [NOTIF_PREFS] Failed to persist master switch: $e');
    }

    // Make the switch real for remote pushes as well: without a stored FCM
    // token the send-push-notification edge function has nowhere to deliver.
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        if (enabled) {
          await FCMService.instance.saveTokenForCurrentUser();
        } else {
          await FCMService.instance.removeTokenForCurrentUser();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [NOTIF_PREFS] FCM token sync failed: $e');
    }

    debugPrint('🔔 [NOTIF_PREFS] Master switch -> $enabled');
  }

  /// Pull the authoritative master value from the DB into the local cache.
  /// Called on sign-in so a value set from another device (or via Avo chat)
  /// takes effect here too.
  Future<void> syncFromRemote() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;

      final row = await SupabaseService.instance.client
          .from('users')
          .select('notification_enabled')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return;

      final enabled = row['notification_enabled'] as bool? ?? true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_masterCacheKey, enabled);
      debugPrint('🔔 [NOTIF_PREFS] Synced master switch from DB: $enabled');
    } catch (e) {
      debugPrint('⚠️ [NOTIF_PREFS] Remote sync failed: $e');
    }
  }

  /// Mirror a master-switch change that was already written to the DB by
  /// someone else (e.g. Avo chat's settings bridge) into the local cache
  /// and FCM token state.
  Future<void> applyMasterChangedRemotely(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_masterCacheKey, enabled);
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        if (enabled) {
          await FCMService.instance.saveTokenForCurrentUser();
        } else {
          await FCMService.instance.removeTokenForCurrentUser();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [NOTIF_PREFS] FCM token sync failed: $e');
    }
  }
}
