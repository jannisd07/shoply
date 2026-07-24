import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/data/services/food_log_service.dart';
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

  /// Fixed id for the "dinner ideas" reminder (Feature 8: calorie tracking
  /// × recipes × Avo nudges).
  static const int dinnerIdeasReminderId = 700002;

  /// Local hour (6 PM) the dinner-ideas reminder fires at.
  static const int _dinnerHour = 18;

  DateTime? _lastRearm;
  DateTime? _lastDinnerRearm;

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

  /// (Re-)schedule today's "dinner ideas" reminder for [_dinnerHour] local
  /// time, or cancel it when it no longer applies. Unlike the restock
  /// reminder this is never pushed to a future day: the remaining-calorie
  /// budget and the food log are specific to *today*, so if it's already
  /// past dinner time (or nothing fits) there's simply nothing to arm until
  /// the next re-arm recomputes it fresh tomorrow. Call on the same
  /// lifecycle events as [rearmRestockReminder].
  ///
  /// Throttled to once per 15 minutes unless [force] is set.
  Future<void> rearmDinnerIdeasReminder({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force &&
          _lastDinnerRearm != null &&
          now.difference(_lastDinnerRearm!).inMinutes < 15) {
        return;
      }
      _lastDinnerRearm = now;

      // Always replace the previously scheduled reminder — its content and
      // due-state are stale the moment the app is opened again.
      await NotificationService.instance.cancel(dinnerIdeasReminderId);

      if (SupabaseService.instance.currentUser == null) return;

      if (!await NotificationPreferencesService.instance
          .shouldShow(NotificationCategory.avoNudges)) {
        debugPrint('🥑 [AVO] Dinner-ideas reminder disabled by preferences');
        return;
      }

      final dinnerTimeToday =
          DateTime(now.year, now.month, now.day, _dinnerHour);
      if (!now.isBefore(dinnerTimeToday)) {
        debugPrint('🥑 [AVO] Past dinner time — no reminder for today');
        return;
      }

      final remaining =
          await CalorieRecipeNudgeService.instance.getRemainingCaloriesToday();
      if (remaining == null ||
          remaining < CalorieRecipeNudgeService.minRemainingCalories) {
        debugPrint('🥑 [AVO] No calorie budget to suggest dinner ideas for');
        return;
      }

      final userModel = await _currentUserDietAndAllergies();
      final suggestions = await CalorieRecipeNudgeService.instance.getSuggestions(
        remainingCalories: remaining,
        dietPreferences: userModel.$1,
        allergies: userModel.$2,
      );
      if (suggestions.isEmpty) return;

      final lang = await _getLanguage();
      final first = suggestions.first;
      final body = suggestions.length == 1
          ? AppTranslations.get('calorie_nudge_notification_body_one', lang,
              params: {'kcal': '$remaining', 'recipe': first.name})
          : AppTranslations.get('calorie_nudge_notification_body_many', lang,
              params: {
                'kcal': '$remaining',
                'count': '${suggestions.length}',
                'recipe': first.name,
              });

      await NotificationService.instance.scheduleNotification(
        id: dinnerIdeasReminderId,
        title: AppTranslations.get('calorie_nudge_notification_title', lang),
        body: body,
        scheduledFor: dinnerTimeToday,
        payload: jsonEncode({'type': 'avo_dinner_ideas'}),
        category: NotificationCategory.avoNudges,
      );
      debugPrint('🥑 [AVO] Dinner-ideas reminder armed for $dinnerTimeToday '
          '(${suggestions.map((r) => r.name).join(', ')})');
    } catch (e) {
      debugPrint('🥑 [AVO] Failed to re-arm dinner-ideas reminder: $e');
    }
  }

  /// (dietPreferences, allergies) for the current user, or ([], []) when
  /// signed out or the lookup fails — a fail-open default is safe here since
  /// [CalorieRecipeNudgeService.getSuggestions] only ever narrows results.
  Future<(List<String>, List<String>)> _currentUserDietAndAllergies() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return (<String>[], <String>[]);
      final row = await SupabaseService.instance.client
          .from('users')
          .select('diet_preferences, allergies')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return (<String>[], <String>[]);
      final diet = (row['diet_preferences'] as List?)?.cast<String>() ?? const [];
      final allergies = (row['allergies'] as List?)?.cast<String>() ?? const [];
      return (diet, allergies);
    } catch (e) {
      return (<String>[], <String>[]);
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

  /// Meal counts (of recipe-cooked meals logged in the rolling last-7-days
  /// window, see [WeeklyNutritionSummary]) worth a one-line celebration.
  /// Sparse on purpose, same philosophy as [_tripMilestones].
  static const List<int> _weeklyProteinMealMilestones = [3, 5, 7, 10];

  static const String _weeklyProteinMilestoneCountKey =
      'avo_weekly_protein_milestone_count';
  static const String _weeklyProteinMilestoneShownAtKey =
      'avo_weekly_protein_milestone_shown_at';

  /// Call right after a recipe-sourced meal is logged. Returns a localized
  /// celebration line when this week's cooked-high-protein-meal count just
  /// hit a milestone that hasn't already been shown for that exact count in
  /// the last 7 days — else null. The count itself is a rolling 7-day
  /// window, so it naturally resets as old entries age out; the 7-day
  /// re-show gate only guards against repeating the same milestone while the
  /// count sits on it (e.g. two more meals logged today, still at "3").
  Future<String?> weeklyHighProteinMealMessage() async {
    try {
      final entries = await FoodLogService.instance.getWeeklyRecipeSourcedEntries();
      final count =
          entries.where(WeeklyNutritionSummary.isHighProteinMeal).length;
      if (!_weeklyProteinMealMilestones.contains(count)) return null;

      final prefs = await SharedPreferences.getInstance();
      final lastCount = prefs.getInt(_weeklyProteinMilestoneCountKey);
      final lastShownAtRaw = prefs.getString(_weeklyProteinMilestoneShownAtKey);
      final lastShownAt =
          lastShownAtRaw != null ? DateTime.tryParse(lastShownAtRaw) : null;
      final now = DateTime.now();
      final recentlyShownSameCount = lastCount == count &&
          lastShownAt != null &&
          now.difference(lastShownAt).inDays < 7;
      if (recentlyShownSameCount) return null;

      await prefs.setInt(_weeklyProteinMilestoneCountKey, count);
      await prefs.setString(
          _weeklyProteinMilestoneShownAtKey, now.toIso8601String());

      final lang = await _getLanguage();
      debugPrint('🥑 [AVO] Weekly high-protein meal milestone reached: $count');
      return AppTranslations.get('weekly_high_protein_milestone_message', lang,
          params: {'count': '$count'});
    } catch (e) {
      debugPrint('🥑 [AVO] Weekly protein milestone check failed: $e');
      return null;
    }
  }
}
