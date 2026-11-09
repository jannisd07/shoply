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

/// A time of day of a reminder.
typedef ReminderClock = ({int hour, int minute});

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
///
/// At start the scheduler in main.dart re-arms once, 3 s after the first
/// frame ([rearmAfterLaunch]); earlier calls are skipped, and nothing is
/// computed while notifications are not allowed. Reminders never mention
/// offers (Kap. 19 §1, S-14), so a re-arm needs no offer data at all.
class MascotNotificationService {
  static MascotNotificationService? _instance;
  static MascotNotificationService get instance {
    _instance ??= MascotNotificationService._();
    return _instance!;
  }

  MascotNotificationService._();

  /// A fresh instance with its own launch gate and throttles.
  @visibleForTesting
  MascotNotificationService.forTesting();

  /// Fixed id so re-arming always replaces the previous pending reminder.
  static const int restockReminderId = 700001;

  /// Local time (9:00) the reminder fires at unless the person chose one.
  static const ReminderClock defaultRestockTime = (hour: 9, minute: 0);

  /// Fixed id for the "dinner ideas" reminder (Feature 8: calorie tracking
  /// × recipes × Avo nudges).
  static const int dinnerIdeasReminderId = 700002;

  /// Local time (18:00) the dinner-ideas reminder fires at by default.
  static const ReminderClock defaultDinnerTime = (hour: 18, minute: 0);

  /// The times chosen in Einstellungen › Mitteilungen ("H:MM", Teil A's
  /// `NotificationTimeSlot`), and the switch "Ideen fürs Abendessen"
  /// (`NotificationSetting.dinnerIdeas`, default on).
  static const String restockTimeKey = 'setp_notif_time_restock';
  static const String dinnerTimeKey = 'setp_notif_time_dinner';
  static const String dinnerIdeasKey = 'notif_dinner_ideas';

  /// [raw] ("9:00", "18:30") as a time of day, or [fallback] when it is
  /// missing or no valid time.
  static ReminderClock parseReminderTime(
    String? raw,
    ReminderClock fallback,
  ) {
    final parts = raw?.trim().split(':');
    if (parts == null || parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return (hour: hour, minute: minute);
  }

  /// The restock reminder's moment: the next day at [time].
  static DateTime restockMoment(DateTime now, ReminderClock time) =>
      DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);

  /// The dinner-ideas reminder's moment: today at [time].
  static DateTime dinnerMoment(DateTime now, ReminderClock time) =>
      DateTime(now.year, now.month, now.day, time.hour, time.minute);

  Future<ReminderClock> _storedTime(String key, ReminderClock fallback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return parseReminderTime(prefs.getString(key), fallback);
    } catch (_) {
      return fallback;
    }
  }

  /// The chosen time of the restock reminder.
  @visibleForTesting
  Future<ReminderClock> restockTime() =>
      _storedTime(restockTimeKey, defaultRestockTime);

  /// The chosen time of the dinner-ideas reminder.
  @visibleForTesting
  Future<ReminderClock> dinnerTime() =>
      _storedTime(dinnerTimeKey, defaultDinnerTime);

  /// "Ideen fürs Abendessen" is on (its own switch, not the restock one).
  @visibleForTesting
  Future<bool> dinnerIdeasEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(dinnerIdeasKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  DateTime? _lastRearm;
  DateTime? _lastDinnerRearm;
  bool _launchSettled = false;

  /// Whether the system allows notifications (never prompts). Without it a
  /// re-arm only cancels: no account or network work for a reminder that
  /// cannot show.
  Future<bool> Function() notificationsAllowed =
      NotificationService.instance.hasPermission;

  /// The start-up re-arm, 3 s after the first frame. Until it ran, every
  /// re-arm call (first frame, auth events at start) is skipped, so a cold
  /// start costs no reminder work before the app is usable.
  Future<void> rearmAfterLaunch() async {
    _launchSettled = true;
    await rearmRestockReminder(force: true);
    await rearmDinnerIdeasReminder(force: true);
  }

  /// The restock reminder's text for [suggestions] (most due first): the
  /// first item and its buying rhythm, or the first item and how many more
  /// are due. Never an offer or a price.
  @visibleForTesting
  static String restockReminderBody(
    List<RestockSuggestion> suggestions,
    String lang,
  ) {
    final first = suggestions.first;
    if (suggestions.length == 1) {
      return AppTranslations.get(
        'restock_notification_body_one',
        lang,
        params: {'item': first.displayName, 'days': '${first.averageDays}'},
      );
    }
    return AppTranslations.get(
      'restock_notification_body_many',
      lang,
      params: {
        'item': first.displayName,
        'count': '${suggestions.length - 1}',
      },
    );
  }

  Future<String> _getLanguage() => NotificationService.appLanguage();


  /// (Re-)schedule the one-shot restock reminder for tomorrow morning, or
  /// cancel it when it no longer applies (signed out, nudges disabled, or
  /// nothing due). Call on resume and auth changes; the start is covered by
  /// [rearmAfterLaunch].
  ///
  /// Throttled to once per 15 minutes unless [force] is set, since resume
  /// events can fire often.
  Future<void> rearmRestockReminder({bool force = false}) async {
    if (!_launchSettled) return;
    try {
      final now = DateTime.now();
      if (!force &&
          _lastRearm != null &&
          now.difference(_lastRearm!).inMinutes < 15) {
        return;
      }
      _lastRearm = now;

      if (!await notificationsAllowed()) {
        await NotificationService.instance.cancel(restockReminderId);
        debugPrint('🥑 [AVO] Notifications not allowed, no restock reminder');
        return;
      }

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
      final tomorrowMorning = restockMoment(now, await restockTime());

      await NotificationService.instance.scheduleNotification(
        id: restockReminderId,
        title: AppTranslations.get('restock_notification_title', lang),
        body: restockReminderBody(suggestions, lang),
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

  /// (Re-)schedule today's "dinner ideas" reminder for the chosen time
  /// ([dinnerTime], 18:00 by default), or cancel it when it no longer
  /// applies. Unlike the restock
  /// reminder this is never pushed to a future day: the remaining-calorie
  /// budget and the food log are specific to *today*, so if it's already
  /// past dinner time (or nothing fits) there's simply nothing to arm until
  /// the next re-arm recomputes it fresh tomorrow. Call on the same
  /// lifecycle events as [rearmRestockReminder].
  ///
  /// Throttled to once per 15 minutes unless [force] is set.
  Future<void> rearmDinnerIdeasReminder({bool force = false}) async {
    if (!_launchSettled) return;
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

      if (!await notificationsAllowed()) {
        debugPrint(
          '🥑 [AVO] Notifications not allowed, no dinner-ideas reminder',
        );
        return;
      }

      if (SupabaseService.instance.currentUser == null) return;

      // Master switch, then "Ideen fürs Abendessen" itself (Einstellungen ›
      // Mitteilungen and › Kalorien & Gesundheit); the restock switch no
      // longer turns it off.
      if (!await NotificationPreferencesService.instance.shouldShow(null) ||
          !await dinnerIdeasEnabled()) {
        debugPrint('🥑 [AVO] Dinner-ideas reminder disabled by preferences');
        return;
      }

      final dinnerTimeToday = dinnerMoment(now, await dinnerTime());
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

  /// Meal counts (of recipe-cooked meals logged in the rolling last-7-days
  /// window, see [WeeklyNutritionSummary]) worth a one-line celebration.
  /// Sparse on purpose: a milestone every few weeks feels earned, one every
  /// few days feels like a slot machine.
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
