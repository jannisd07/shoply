import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/notification_preferences_service.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Avo's notification voice.
///
/// Earlier versions of this service sent random time-of-day motivational
/// messages ("Avo says hi!") — pure noise. It now sends exactly one kind of
/// notification, based on real data: a scheduled next-morning restock
/// reminder computed from the user's own purchase rhythm
/// (`item_purchase_stats.average_days_between` via [AvoNudgeService]).
///
/// The reminder is *re-armed on every app open/resume*: while the user keeps
/// using the app they see the in-app restock card instead and the pending
/// notification keeps being pushed a day ahead — so it only ever fires when
/// the user has NOT opened the app since yesterday AND something is actually
/// due. Useful re-engagement, not spam.
class MascotNotificationService {
  static MascotNotificationService? _instance;
  static MascotNotificationService get instance {
    _instance ??= MascotNotificationService._();
    return _instance!;
  }

  MascotNotificationService._();

  static const String _languageKey = 'app_language';

  /// Fixed id so re-arming always replaces the previous pending reminder.
  static const int restockReminderId = 700001;

  /// Local hour (9 AM) the reminder fires at.
  static const int _reminderHour = 9;

  DateTime? _lastRearm;

  /// Get stored language preference (default to 'en')
  Future<String> _getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  /// (Re-)schedule the one-shot restock reminder for tomorrow morning, or
  /// cancel it when it no longer applies (signed out, nudges disabled, or
  /// nothing due). Call on app start, resume, and auth changes.
  ///
  /// Throttled to once per 15 minutes unless [force] is set, since resume
  /// events can fire often.
  Future<void> rearmRestockReminder({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force &&
          _lastRearm != null &&
          now.difference(_lastRearm!).inMinutes < 15) {
        return;
      }
      _lastRearm = now;

      if (SupabaseService.instance.currentUser == null) {
        await NotificationService.instance.cancel(restockReminderId);
        return;
      }

      if (!await NotificationPreferencesService.instance
          .shouldShow(NotificationCategory.avoNudges)) {
        await NotificationService.instance.cancel(restockReminderId);
        debugPrint('🥑 [AVO] Restock reminder disabled by preferences');
        return;
      }

      final suggestions =
          await AvoNudgeService.instance.getRestockSuggestions(limit: 3);

      // Always replace the previously scheduled reminder — its content and
      // due-state are stale the moment the app is opened again.
      await NotificationService.instance.cancel(restockReminderId);

      if (suggestions.isEmpty) {
        debugPrint('🥑 [AVO] Nothing due — no restock reminder scheduled');
        return;
      }

      final lang = await _getLanguage();
      final first = suggestions.first;
      final tomorrowMorning = DateTime(
          now.year, now.month, now.day + 1, _reminderHour);

      // When the top item also has a live discounted offer nearby, lead with
      // that — "running low AND cheaper right now" is the strongest honest
      // reason to open the app. The offer must still run when the reminder
      // actually fires tomorrow morning. Cached in AvoNudgeService, so this
      // does not hit the offers API on every re-arm.
      OfferNudge? offerForFirst;
      try {
        final offers = await AvoNudgeService.instance.getOfferNudges();
        for (final offer in offers) {
          if (offer.itemName == first.itemName &&
              (offer.validTo == null ||
                  offer.validTo!.isAfter(tomorrowMorning))) {
            offerForFirst = offer;
            break;
          }
        }
      } catch (_) {}

      final String body;
      if (offerForFirst != null) {
        body = AppTranslations.get('restock_notification_body_offer', lang,
            params: {
              'item': first.displayName,
              'store': offerForFirst.retailerName,
              'price': offerForFirst.price.toStringAsFixed(2),
            });
      } else if (suggestions.length == 1) {
        body = AppTranslations.get('restock_notification_body_one', lang,
            params: {
              'item': first.displayName,
              'days': '${first.averageDays}',
            });
      } else {
        body = AppTranslations.get('restock_notification_body_many', lang,
            params: {
              'item': first.displayName,
              'count': '${suggestions.length - 1}',
            });
      }

      await NotificationService.instance.scheduleNotification(
        id: restockReminderId,
        title: AppTranslations.get('restock_notification_title', lang),
        body: body,
        scheduledFor: tomorrowMorning,
        payload: jsonEncode({'type': 'avo_restock'}),
        category: NotificationCategory.avoNudges,
      );
      debugPrint(
          '🥑 [AVO] Restock reminder armed for $tomorrowMorning '
          '(${suggestions.map((s) => s.itemName).join(', ')})');
    } catch (e) {
      debugPrint('🥑 [AVO] Failed to re-arm restock reminder: $e');
    }
  }

  /// Trip-count milestones worth a one-line in-app celebration. Sparse on
  /// purpose — a milestone every few weeks feels earned, one every few days
  /// feels like a slot machine.
  static const List<int> _tripMilestones = [10, 25, 50, 100, 250, 500, 1000];

  static const String _milestonesShownKey = 'avo_milestones_shown';

  /// Call right after a shopping trip was completed. Returns a localized
  /// celebration line when the user's own completed-trip count just hit a
  /// milestone that hasn't been celebrated yet — else null. Each milestone
  /// fires at most once (tracked locally).
  Future<String?> milestoneMessageForCompletedTrip() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return null;

      final rows = await SupabaseService.instance.client
          .from('shopping_history')
          .select('id')
          .eq('user_id', userId);
      final count = (rows as List).length;
      if (!_tripMilestones.contains(count)) return null;

      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getStringList(_milestonesShownKey) ?? <String>[];
      if (shown.contains('$count')) return null;
      shown.add('$count');
      await prefs.setStringList(_milestonesShownKey, shown);

      final lang = await _getLanguage();
      debugPrint('🥑 [AVO] Trip milestone reached: $count');
      return AppTranslations.get('milestone_trip_message', lang,
          params: {'count': '$count'});
    } catch (e) {
      debugPrint('🥑 [AVO] Milestone check failed: $e');
      return null;
    }
  }
}
