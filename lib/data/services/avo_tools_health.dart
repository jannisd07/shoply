part of 'avo_assistant_service.dart';

// Calories and health (Kap. 5.6, 7.2).
extension AvoHealthTools on AvoAssistantService {
  Future<Map<String, Object?>> _toolGetUserProfile(WidgetRef ref) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return {'error': 'Not signed in'};

    final trackingOn = ref.read(moduleEnabledProvider(AppModule.calories));
    final zip = await UserLocationService.instance.getManualZipCode();
    final goal = trackingOn
        ? await NutritionGoalService.instance.getGoal()
        : null;

    return {
      'display_name': user.displayName ?? 'not set',
      'age': user.age ?? 'not set',
      'gender': user.gender ?? 'not set',
      'height': user.height == null
          ? 'not set'
          : '${user.height!.round()} ${user.heightUnit ?? 'cm'}',
      'diet_preferences': user.dietPreferences.isEmpty
          ? 'none'
          : user.dietPreferences,
      'allergies': user.allergies.isEmpty ? 'none' : user.allergies,
      'language': ref.read(languageProvider.notifier).savedSetting,
      'theme': ref.read(themeModeProvider).name,
      'notifications_enabled': user.notificationEnabled,
      'calorie_tracking_enabled': trackingOn,
      // Whether a postcode is set, never the postcode (server contract).
      'postcode_set': zip != null && zip.isNotEmpty,
      if (trackingOn)
        'nutrition_goal': (goal != null && goal.isConfigured)
            ? {
                'goal_type': goal.goalType.dbValue,
                'daily_calorie_target': goal.dailyCalorieTarget,
                'protein_target_g': goal.proteinTargetG,
                'carbs_target_g': goal.carbsTargetG,
                'fat_target_g': goal.fatTargetG,
                if (goal.targetWeightKg != null)
                  'target_weight_kg': goal.targetWeightKg,
              }
            : 'not configured — offer setup_nutrition_goal',
      'note':
          'Anything "not set" can be changed via update_setting; the '
          'calorie goal via setup_nutrition_goal.',
    };
  }

  Future<Map<String, Object?>> _toolSetupNutritionGoal(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final store = ref.read(avoGoalStoreProvider);
    final userId = store.userId;
    if (userId == null) return {'error': 'Not signed in'};

    // Validate the enum-ish args strictly so a hallucinated value can't be
    // silently coerced into the wrong goal.
    NutritionGoalType? goalType;
    final goalArg = (args['goal_type'] as String?)?.toLowerCase().trim();
    if (goalArg != null && goalArg.isNotEmpty) {
      const valid = {'lose_weight', 'gain_muscle', 'maintain', 'custom'};
      if (!valid.contains(goalArg)) {
        return {'error': 'goal_type must be one of: ${valid.join(', ')}'};
      }
      goalType = NutritionGoalTypeX.fromDb(goalArg);
    }
    ActivityLevel? activityLevel;
    final activityArg = (args['activity_level'] as String?)
        ?.toLowerCase()
        .trim();
    if (activityArg != null && activityArg.isNotEmpty) {
      const valid = {'sedentary', 'light', 'moderate', 'active', 'very_active'};
      if (!valid.contains(activityArg)) {
        return {'error': 'activity_level must be one of: ${valid.join(', ')}'};
      }
      activityLevel = ActivityLevelX.fromDb(activityArg);
    }
    var gender = (args['gender'] as String?)?.toLowerCase().trim();
    if (gender != null &&
        gender.isNotEmpty &&
        gender != 'male' &&
        gender != 'female') {
      return {
        'error':
            'gender must be "male" or "female" — it is only used to pick '
            'the BMR formula variant.',
      };
    }

    // Prefill everything not passed from the profile, the existing goal and
    // the weight log — the same sources the goal-setup screen prefills from.
    final user = await ref.read(currentUserProvider.future);
    final existing = await store.goal();
    final hasConfiguredGoal = existing != null && existing.isConfigured;

    if (gender == null || gender.isEmpty) {
      gender = (user?.gender == 'male' || user?.gender == 'female')
          ? user!.gender
          : null;
    }
    final age = (args['age'] as num?)?.round() ?? user?.age;
    if (age != null && (age < 10 || age > 120)) {
      return {'error': 'age must be between 10 and 120'};
    }
    var heightCm =
        (args['height_cm'] as num?)?.toDouble() ?? existing?.heightCm;
    if (heightCm == null &&
        user?.height != null &&
        (user!.heightUnit == null || user.heightUnit == 'cm')) {
      heightCm = user.height;
    }
    if (heightCm != null && (heightCm < 100 || heightCm > 250)) {
      return {'error': 'height_cm must be between 100 and 250'};
    }
    var weight =
        (args['current_weight_kg'] as num?)?.toDouble() ??
        existing?.currentWeightKg;
    weight ??= (await store.latestWeight())?.weightKg;
    if (weight != null && (weight < 20 || weight > 400)) {
      return {'error': 'current_weight_kg must be between 20 and 400'};
    }
    goalType ??= hasConfiguredGoal ? existing.goalType : null;
    activityLevel ??= hasConfiguredGoal ? existing.activityLevel : null;
    final needsTarget =
        goalType == NutritionGoalType.loseWeight ||
        goalType == NutritionGoalType.gainMuscle;
    final targetWeight =
        (args['target_weight_kg'] as num?)?.toDouble() ??
        existing?.targetWeightKg;
    if (needsTarget &&
        targetWeight != null &&
        (targetWeight < 20 || targetWeight > 400)) {
      return {'error': 'target_weight_kg must be between 20 and 400'};
    }
    final timelineWeeks =
        ((args['timeline_weeks'] as num?)?.round() ??
                existing?.timelineWeeks ??
                12)
            .clamp(4, 104)
            .toInt();

    final missing = <String>[
      if (goalType == null) 'goal_type',
      if (gender == null) 'gender',
      if (age == null) 'age',
      if (heightCm == null) 'height_cm',
      if (weight == null) 'current_weight_kg',
      if (needsTarget && targetWeight == null) 'target_weight_kg',
      if (activityLevel == null) 'activity_level',
    ];
    if (missing.isNotEmpty) {
      return {
        'incomplete': true,
        'missing': missing,
        'known': {
          if (goalType != null) 'goal_type': goalType.dbValue,
          if (activityLevel != null) 'activity_level': activityLevel.dbValue,
          if (age != null) 'age': age,
          if (gender != null) 'gender': gender,
          if (heightCm != null) 'height_cm': heightCm,
          if (weight != null) 'current_weight_kg': weight,
          if (needsTarget && targetWeight != null)
            'target_weight_kg': targetWeight,
        },
        'note':
            'Ask the user for the missing fields (at most two per '
            'message), then call setup_nutrition_goal again with everything. '
            'The "known" values were prefilled from their profile — mention '
            'them briefly so the user can correct any that changed.',
      };
    }

    final targets = NutritionGoalCalculator.calculate(
      goalType: goalType!,
      activityLevel: activityLevel!,
      currentWeightKg: weight!,
      heightCm: heightCm!,
      age: age!,
      gender: gender!,
      targetWeightKg: needsTarget ? targetWeight : null,
      timelineWeeks: needsTarget ? timelineWeeks : null,
    );
    final now = DateTime.now();
    final goal = NutritionGoal(
      userId: userId,
      calorieTrackingEnabled: true,
      goalType: goalType,
      activityLevel: activityLevel,
      currentWeightKg: weight,
      targetWeightKg: needsTarget ? targetWeight : null,
      heightCm: heightCm,
      timelineWeeks: needsTarget ? timelineWeeks : null,
      dailyCalorieTarget: targets.dailyCalorieTarget,
      proteinTargetG: targets.proteinTargetG,
      carbsTargetG: targets.carbsTargetG,
      fatTargetG: targets.fatTargetG,
      waterTargetMl: existing?.waterTargetMl ?? 2000,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    // Always the preview with "Übernehmen" (Kap. 5.6): a first goal too, and
    // `confirm_replace` only shows it again. Only the tap saves
    // ([applyGoalForAvo]); nothing in the profile or the weight log is
    // touched here. The card names a weight entry for today when there is
    // none yet.
    final latest = await store.latestWeight();
    final gate = avoGoalGate(
      goal,
      previous: existing,
      todayHasWeight:
          latest != null && AvoAssistantService._sameDay(latest.loggedDate, now),
    );
    payloads.add(gate.card);
    return gate.result;
  }

  /// "Übernehmen" on a goal preview ([avoApplyGoal]): the goal and today's
  /// weight are read at the tap; the profile is never touched.
  Future<AvoGoalRecord> applyGoalForAvo(
    WidgetRef ref,
    AvoGoalPreviewCard card,
  ) => avoApplyGoal(
    ref.read(avoGoalStoreProvider),
    card,
    now: DateTime.now(),
    changed: () {
      ref.invalidate(nutritionGoalProvider);
      invalidateNutritionLog(ref);
      unawaited(
        MascotNotificationService.instance.rearmDinnerIdeasReminder(
          force: true,
        ),
      );
    },
  );

  Future<Map<String, Object?>> _toolNutritionStatus(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final today = DateTime.now();
    final goal = await NutritionGoalService.instance.getGoal();
    final entries = await FoodLogService.instance.getEntriesForDate(today);
    final totals = DailyNutritionTotals.fromEntries(entries);
    final waterMl = await WaterLogService.instance.getTotalForDate(today);
    payloads.add(
      AvoWidgetPayload.card(
        AvoNutritionStatusCard(
          consumedKcal: totals.calories,
          goalKcal: goal?.isConfigured ?? false
              ? goal!.dailyCalorieTarget
              : null,
        ),
      ),
    );

    final result = <String, Object?>{
      'tracking_enabled': true,
      'goal_configured': goal?.isConfigured ?? false,
      'consumed_today': {
        'calories': totals.calories,
        'protein_g': AvoAssistantService._round1(totals.proteinG),
        'carbs_g': AvoAssistantService._round1(totals.carbsG),
        'fat_g': AvoAssistantService._round1(totals.fatG),
        'water_ml': waterMl,
      },
      'entries_today': entries
          .map(
            (e) => {
              'entry_id': e.id,
              'meal': e.mealType.dbValue,
              'food': e.foodName,
              'calories': e.calories,
            },
          )
          .toList(),
    };
    if (goal != null && goal.isConfigured) {
      result['goal_type'] = goal.goalType.dbValue;
      result['targets'] = {
        'calories': goal.dailyCalorieTarget,
        'protein_g': goal.proteinTargetG,
        'carbs_g': goal.carbsTargetG,
        'fat_g': goal.fatTargetG,
        'water_ml': goal.waterTargetMl,
      };
      result['remaining'] = {
        'calories': goal.dailyCalorieTarget! - totals.calories,
        if (goal.proteinTargetG != null)
          'protein_g': AvoAssistantService._round1(
            goal.proteinTargetG! - totals.proteinG,
          ),
        if (goal.carbsTargetG != null)
          'carbs_g': AvoAssistantService._round1(
            goal.carbsTargetG! - totals.carbsG,
          ),
        if (goal.fatTargetG != null)
          'fat_g': AvoAssistantService._round1(goal.fatTargetG! - totals.fatG),
        'water_ml': goal.waterTargetMl - waterMl,
      };
    } else {
      result['note'] =
          'No calorie goal is configured yet, so there are no targets — '
          'totals only. Offer to set one up right here in chat via '
          'setup_nutrition_goal.';
    }
    return result;
  }

  /// `log_food` never saves on its own (Kap. 5.6, 7.2): it shows the
  /// estimate, and only "Eintragen" on the card writes the diary entry.
  Future<Map<String, Object?>> _toolLogFood(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final foodName = (args['food_name'] as String?)?.trim() ?? '';
    if (foodName.isEmpty) return {'error': 'food_name is required'};

    final portion = (args['portion'] as String?)?.trim() ?? '';
    var calories = (args['calories'] as num?)?.round();
    var protein = (args['protein_g'] as num?)?.toDouble();
    var carbs = (args['carbs_g'] as num?)?.toDouble();
    var fat = (args['fat_g'] as num?)?.toDouble();

    var estimated = false;
    if (calories == null) {
      final description = portion.isEmpty ? foodName : '$portion $foodName';
      final estimate = await _estimateFoodNutrition(description);
      if (estimate == null) {
        return {
          'error':
              'Could not estimate nutrition for "$description" — ask '
              'the user for the calories and call log_food again with them.',
        };
      }
      calories = (estimate['calories'] as num?)?.round() ?? 0;
      protein ??= (estimate['protein_g'] as num?)?.toDouble();
      carbs ??= (estimate['carbs_g'] as num?)?.toDouble();
      fat ??= (estimate['fat_g'] as num?)?.toDouble();
      estimated = true;
    }

    final gate = avoFoodGate(
      food: foodName,
      kcal: calories,
      meal: AvoAssistantService._mealTypeFromArg(args['meal_type'] as String?),
      estimated: estimated,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      portion: portion.isEmpty ? null : portion,
      allergies:
          ref.read(currentUserProvider).valueOrNull?.allergies ?? const [],
    );
    payloads.add(gate.card);
    return gate.result;
  }

  /// "Eintragen" on an estimate card: writes the diary entry (with the photo
  /// in the private bucket when there is one) and answers with its card.
  Future<AvoFoodRecord> logEstimateForAvo(
    WidgetRef ref,
    AvoEstimateCard estimate, {
    required MealType meal,
    double factor = 1,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('not signed in');
    String? photoPath;
    final photo = estimate.photo;
    if (photo != null) {
      try {
        photoPath = await MealPhotoStorageService.instance.uploadPhoto(photo);
      } catch (e) {
        debugPrint('⚠️ [AVO] Meal photo not stored: $e');
      }
    }
    double? scaled(double? v) =>
        v == null ? null : AvoAssistantService._round1(v * factor);
    final kcal = (estimate.kcal * factor).round();
    final now = DateTime.now();
    final name = estimate.portion == null || factor != 1
        ? estimate.name
        : '${estimate.name} (${estimate.portion})';
    final entry = await FoodLogService.instance.addEntry(
      FoodLogEntry(
        id: const Uuid().v4(),
        userId: userId,
        loggedDate: now,
        mealType: meal,
        origin: photo != null
            ? FoodEntryOrigin.photo
            : estimate.estimated
            ? FoodEntryOrigin.manualEstimated
            : FoodEntryOrigin.manual,
        foodName: name,
        calories: kcal,
        proteinG: scaled(estimate.proteinG),
        carbsG: scaled(estimate.carbsG),
        fatG: scaled(estimate.fatG),
        photoPath: photoPath,
        estimated: estimate.estimated,
        confidence: EstimateConfidenceX.fromDb(estimate.confidence),
        createdAt: now,
      ),
    );
    invalidateNutritionLog(ref);
    final goal = await NutritionGoalService.instance.getGoal();
    final totals = DailyNutritionTotals.fromEntries(
      await FoodLogService.instance.getEntriesForDate(now),
    );
    return AvoFoodRecord(
      tool: 'log_food',
      name: estimate.name,
      meal: meal,
      kcal: kcal,
      leftKcal: goal?.dailyCalorieTarget == null
          ? null
          : goal!.dailyCalorieTarget! - totals.calories,
      undo: () async {
        try {
          await FoodLogService.instance.deleteEntry(entry.id);
          // The photo goes with its entry.
          if (photoPath != null) {
            await MealPhotoStorageService.instance.deletePhoto(photoPath);
          }
          invalidateNutritionLog(ref);
          return AvoUndoResult.undone;
        } catch (e) {
          debugPrint('❌ [AVO] Food entry not taken back: $e');
          return AvoUndoResult.failed;
        }
      },
    );
  }

  Future<Map<String, Object?>> _toolLogWater(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final amount = ((args['amount_ml'] as num?)?.round() ?? 250).clamp(1, 3000);
    final entry = await WaterLogService.instance.addEntry(amount);
    invalidateNutritionLog(ref);
    final total = await WaterLogService.instance.getTotalForDate(
      DateTime.now(),
    );
    final goal = await NutritionGoalService.instance.getGoal();
    final target = goal?.waterTargetMl ?? 2000;
    payloads.add(
      AvoWidgetPayload.record(
        AvoWaterRecord(
          tool: 'log_water',
          amountMl: amount,
          totalMl: total,
          targetMl: target,
          undo: () async {
            try {
              await WaterLogService.instance.deleteEntry(entry.id);
              invalidateNutritionLog(ref);
              return AvoUndoResult.undone;
            } catch (e) {
              debugPrint('❌ [AVO] Water not taken back: $e');
              return AvoUndoResult.failed;
            }
          },
        ),
      ),
    );
    return {
      'success': true,
      'added_ml': amount,
      'total_today_ml': total,
      'target_ml': target,
    };
  }

  Future<Map<String, Object?>> _toolLogWeight(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final weight = (args['weight_kg'] as num?)?.toDouble();
    if (weight == null || weight < 20 || weight > 400) {
      return {'error': 'weight_kg must be between 20 and 400'};
    }
    final previous = await WeightLogService.instance.getLatest();
    final saved = await WeightLogService.instance.logWeight(weightKg: weight);
    invalidateNutritionLog(ref);
    final goal = await NutritionGoalService.instance.getGoal();
    final today = DateTime.now();
    bool sameDay(DateTime a) =>
        a.year == today.year && a.month == today.month && a.day == today.day;
    // Today's entry is replaced: undo brings back what today had, or
    // removes the entry when today had none.
    final replaced = previous != null && sameDay(previous.loggedDate)
        ? previous
        : null;
    payloads.add(
      AvoWidgetPayload.record(
        AvoWeightRecord(
          tool: 'log_weight',
          kg: weight,
          day: today,
          undo: () async {
            try {
              // Only while today's entry is still the one Avo wrote.
              final latest = await WeightLogService.instance.getLatest();
              if (latest == null ||
                  !AvoAssistantService._sameDay(latest.loggedDate, today) ||
                  latest.weightKg != weight) {
                return AvoUndoResult.changedSince;
              }
              if (replaced != null) {
                await WeightLogService.instance.upsertForDate(
                  weightKg: replaced.weightKg,
                  date: replaced.loggedDate,
                  note: replaced.note,
                );
              } else {
                await WeightLogService.instance.delete(saved.id);
              }
              invalidateNutritionLog(ref);
              return AvoUndoResult.undone;
            } catch (e) {
              debugPrint('❌ [AVO] Weight not taken back: $e');
              return AvoUndoResult.failed;
            }
          },
        ),
      ),
    );
    return {
      'success': true,
      'weight_kg': weight,
      if (previous != null) 'previous_weight_kg': previous.weightKg,
      if (previous != null)
        'previous_logged_date': previous.loggedDate.toIso8601String().substring(
          0,
          10,
        ),
      if (goal?.targetWeightKg != null)
        'target_weight_kg': goal!.targetWeightKg,
    };
  }

  Future<Map<String, Object?>> _toolWeeklyNutritionSummary(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final goal = await ref.read(nutritionGoalProvider.future);
    if (goal == null || !goal.isConfigured) {
      return {
        'found': false,
        'note':
            'No calorie goal is configured yet, so there is nothing to '
            'summarize. Offer to set one up via setup_nutrition_goal.',
      };
    }
    final summary = await ref.read(weeklyNutritionSummaryProvider.future);
    payloads.add(
      AvoWidgetPayload.card(
        AvoWeekCard(
          days: summary?.days ?? const [],
          kcalByDay: summary?.caloriesByDay ?? const {},
          averageKcal: summary?.avgCalories ?? 0,
          goalKcal: goal.dailyCalorieTarget,
        ),
      ),
    );
    if (summary == null || !summary.hasAnyData) {
      return {'found': false, 'note': 'Nothing was logged in the last 7 days.'};
    }
    return AvoAssistantService.summarizeWeeklyNutrition(summary, goal);
  }

  Future<Map<String, Object?>> _toolChallengeStatus(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final challenges = await ref.read(activeChallengesProvider.future);
    payloads.add(
      AvoWidgetPayload.card(
        AvoChallengesCard([
          for (final c in challenges)
            (
              type: c.type,
              title: c.title,
              day: c.daysElapsed,
              totalDays: c.fixedDurationDays,
              checkedInToday: c.isCheckedInToday,
            ),
        ]),
      ),
    );
    return AvoAssistantService.summarizeChallengeStatus(challenges);
  }

  Future<Map<String, Object?>> _toolLogWorkout(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.calories))) {
      return {
        'tracking_enabled': false,
        'note': AvoAssistantService._trackingDisabledNote,
      };
    }
    final activity = (args['activity'] as String?)?.trim() ?? '';
    final minutes = (args['duration_min'] as num?)?.toInt() ?? 0;
    if (activity.isEmpty || minutes <= 0) {
      return {'error': 'activity and duration_min are required'};
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {'error': 'not signed in'};
    final type = AvoAssistantService.workoutTypeOf(activity);
    final given = (args['calories'] as num?)?.toInt();
    final kcal =
        given ??
        estimateWorkoutCalories(
          type: type,
          intensity: WorkoutIntensity.moderate,
          durationMin: minutes,
        ).kcal;
    final now = DateTime.now();
    final saved = await WorkoutLogService.instance.upsert(
      Workout(
        id: const Uuid().v4(),
        userId: userId,
        startedAt: now.subtract(Duration(minutes: minutes)),
        durationMin: minutes,
        type: type,
        calories: kcal,
        createdAt: now,
      ),
    );
    invalidateNutritionLog(ref);
    payloads.add(
      AvoWidgetPayload.record(
        AvoWorkoutRecord(
          tool: 'log_workout',
          type: type,
          minutes: minutes,
          kcal: kcal,
          estimated: given == null,
          undo: () async {
            try {
              await WorkoutLogService.instance.delete(saved.id);
              invalidateNutritionLog(ref);
              return AvoUndoResult.undone;
            } catch (e) {
              debugPrint('❌ [AVO] Workout not taken back: $e');
              return AvoUndoResult.failed;
            }
          },
        ),
      ),
    );
    return {
      'success': true,
      'activity': type.name,
      'duration_min': minutes,
      'calories': kcal,
      'calories_estimated': given == null,
    };
  }
}
