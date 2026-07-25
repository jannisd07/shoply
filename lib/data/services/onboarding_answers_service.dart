import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';

/// The goal-questionnaire answers collected on the onboarding calorie page,
/// before there is an authenticated user to save them against.
class OnboardingGoalDraft {
  final NutritionGoalType goalType;
  final ActivityLevel activityLevel;
  final String gender;
  final int age;
  final double heightCm;
  final double currentWeightKg;
  final double? targetWeightKg;
  final int? timelineWeeks;

  const OnboardingGoalDraft({
    required this.goalType,
    required this.activityLevel,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.currentWeightKg,
    this.targetWeightKg,
    this.timelineWeeks,
  });

  Map<String, dynamic> toJson() => {
        'goal_type': goalType.dbValue,
        'activity_level': activityLevel.dbValue,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'current_weight_kg': currentWeightKg,
        'target_weight_kg': targetWeightKg,
        'timeline_weeks': timelineWeeks,
      };

  factory OnboardingGoalDraft.fromJson(Map<String, dynamic> json) {
    return OnboardingGoalDraft(
      goalType: NutritionGoalTypeX.fromDb(json['goal_type'] as String),
      activityLevel: ActivityLevelX.fromDb(json['activity_level'] as String),
      gender: json['gender'] as String,
      age: json['age'] as int,
      heightCm: (json['height_cm'] as num).toDouble(),
      currentWeightKg: (json['current_weight_kg'] as num).toDouble(),
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      timelineWeeks: json['timeline_weeks'] as int?,
    );
  }
}

/// Bridges the gap between onboarding (which runs before the user has an
/// account) and the account itself: onboarding answers are stashed locally
/// as they're collected, then applied to the real `users` /
/// `nutrition_goals` rows the first time we see an authenticated user on
/// this device. Idempotent — runs at most once per device via
/// [_syncedKey], so it never overwrites answers the user later changes
/// from Profile/goal settings, and it's a safe no-op for anyone who
/// completed onboarding before this existed (nothing pending to apply).
class OnboardingAnswersService {
  OnboardingAnswersService._();
  static final OnboardingAnswersService instance = OnboardingAnswersService._();

  static const _syncedKey = 'onb_answers_synced_v1';
  static const _dietKey = 'onb_pending_diet_preferences';
  static const _prioritiesKey = 'onb_pending_app_priorities';
  static const _caloriesOptInKey = 'onb_pending_calories_opt_in';
  static const _goalDraftKey = 'onb_pending_goal_draft';

  /// Called once, at the end of onboarding, before the user has signed up.
  Future<void> savePendingAnswers({
    required List<String> dietPreferences,
    required List<String> appPriorities,
    required bool caloriesOptedIn,
    OnboardingGoalDraft? goalDraft,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dietKey, dietPreferences);
    await prefs.setStringList(_prioritiesKey, appPriorities);
    await prefs.setBool(_caloriesOptInKey, caloriesOptedIn);
    if (goalDraft != null) {
      await prefs.setString(_goalDraftKey, jsonEncode(goalDraft.toJson()));
    } else {
      await prefs.remove(_goalDraftKey);
    }
    // A fresh onboarding run always supersedes anything not yet synced.
    await prefs.setBool(_syncedKey, false);
  }

  /// Applies any pending onboarding answers to [userId]'s account. Safe to
  /// call on every app start / auth change — it's a no-op after the first
  /// successful run (or if this device never collected any answers, e.g.
  /// existing users who onboarded before this feature shipped). Returns
  /// true only when it actually wrote something, so callers know whether
  /// their cached user model is now stale.
  ///
  /// [accountCreatedAt] is the `users` row's `created_at`. Onboarding
  /// answers are collected before any account exists, so they can only
  /// legitimately belong to an account created in *this* session (a fresh
  /// signup). If the account we're about to write into already existed —
  /// e.g. the device's local "synced" flag was wiped by a reinstall, the
  /// user went through onboarding again, then tapped "Log In" to an
  /// existing account instead of signing up — applying stale local answers
  /// would silently overwrite that account's real diet/goal/profile data.
  /// When omitted, the check is skipped (caller already knows the row is
  /// new, e.g. it was just inserted).
  Future<bool> applyPendingAnswersToAccount(
    String userId, {
    DateTime? accountCreatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_syncedKey) ?? false) return false;

    if (accountCreatedAt != null &&
        DateTime.now().difference(accountCreatedAt) > const Duration(minutes: 5)) {
      // Not a fresh signup — this device has nothing legitimate to apply.
      await prefs.setBool(_syncedKey, true);
      return false;
    }

    final dietPreferences = prefs.getStringList(_dietKey);
    final appPriorities = prefs.getStringList(_prioritiesKey);
    final caloriesOptedIn = prefs.getBool(_caloriesOptInKey);

    if (dietPreferences == null && appPriorities == null && caloriesOptedIn == null) {
      // Nothing was ever collected on this device — mark synced so we
      // don't keep checking on every auth refresh.
      await prefs.setBool(_syncedKey, true);
      return false;
    }

    try {
      await SupabaseService.instance.from('users').update({
        'diet_preferences': dietPreferences ?? const [],
        'app_priorities': appPriorities ?? const [],
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (caloriesOptedIn == true) {
        final draftJson = prefs.getString(_goalDraftKey);
        if (draftJson != null) {
          final draft = OnboardingGoalDraft.fromJson(
            jsonDecode(draftJson) as Map<String, dynamic>,
          );
          final targets = NutritionGoalCalculator.calculate(
            goalType: draft.goalType,
            activityLevel: draft.activityLevel,
            currentWeightKg: draft.currentWeightKg,
            heightCm: draft.heightCm,
            age: draft.age,
            gender: draft.gender,
            targetWeightKg: draft.targetWeightKg,
            timelineWeeks: draft.timelineWeeks,
          );
          final now = DateTime.now();
          await NutritionGoalService.instance.saveGoal(NutritionGoal(
            userId: userId,
            calorieTrackingEnabled: true,
            goalType: draft.goalType,
            activityLevel: draft.activityLevel,
            currentWeightKg: draft.currentWeightKg,
            targetWeightKg: draft.targetWeightKg,
            heightCm: draft.heightCm,
            timelineWeeks: draft.timelineWeeks,
            dailyCalorieTarget: targets.dailyCalorieTarget,
            proteinTargetG: targets.proteinTargetG,
            carbsTargetG: targets.carbsTargetG,
            fatTargetG: targets.fatTargetG,
            createdAt: now,
            updatedAt: now,
          ));
          await WeightLogService.instance.logWeight(
            weightKg: draft.currentWeightKg,
          );
          await SupabaseService.instance.from('users').update({
            'age': draft.age,
            'height': draft.heightCm,
            'height_unit': 'cm',
            'gender': draft.gender,
          }).eq('id', userId);
        } else {
          // Opted in but skipped the goal questions — still flip the
          // server-side switch so the tab preference survives a reinstall;
          // the calories dashboard prompts for goal setup separately.
          await NutritionGoalService.instance.setTrackingEnabled(true);
        }
      }

      await prefs.setBool(_syncedKey, true);
      await prefs.remove(_dietKey);
      await prefs.remove(_prioritiesKey);
      await prefs.remove(_caloriesOptInKey);
      await prefs.remove(_goalDraftKey);
      return true;
    } catch (e) {
      debugPrint('⚠️ [OnboardingSync] Failed to apply pending answers: $e');
      // Leave _syncedKey false — retried on the next auth refresh.
      return false;
    }
  }
}
