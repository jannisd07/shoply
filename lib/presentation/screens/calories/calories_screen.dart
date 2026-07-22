import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/presentation/screens/calories/goal_setup_screen.dart';
import 'package:shoply/presentation/screens/calories/weekly_summary_screen.dart';
import 'package:shoply/presentation/screens/calories/weight_tracking_screen.dart';
import 'package:shoply/presentation/screens/calories/what_can_i_eat_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_ring.dart';
import 'package:shoply/presentation/screens/calories/widgets/challenges_entry_card.dart';
import 'package:shoply/presentation/screens/calories/widgets/food_entry_sheet.dart';
import 'package:shoply/presentation/screens/calories/widgets/food_log_tile.dart';
import 'package:shoply/presentation/screens/calories/widgets/macro_bar.dart';
import 'package:shoply/presentation/screens/calories/widgets/water_tracker_card.dart';
import 'package:shoply/presentation/screens/calories/widgets/weekly_calories_strip.dart';
import 'package:shoply/presentation/state/calorie_tracking_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Kalorien tab — dashboard: today's totals vs. goal, macro bars, water,
/// and the meal-by-meal food log. Falls back to a goal-setup prompt when
/// the user has enabled tracking but hasn't answered the questionnaire yet.
class CaloriesScreen extends ConsumerWidget {
  const CaloriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(nutritionGoalProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        bottom: false,
        child: goalAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(context.tr('calories_v0_card_sub'))),
          data: (goal) {
            if (goal == null || !goal.isConfigured) {
              return const _SetupPrompt();
            }
            return _Dashboard(goal: goal);
          },
        ),
      ),
    );
  }
}

class _SetupPrompt extends ConsumerWidget {
  const _SetupPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenHorizontalPadding, 18, AppDimensions.screenHorizontalPadding, 140),
      children: [
        Text(
          context.tr('calories').toUpperCase(),
          style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600, color: accent),
        ),
        const SizedBox(height: 4),
        Text(context.tr('calories_v0_title'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 24),
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_fire_department_outlined, size: 26, color: accent),
              const SizedBox(height: 12),
              Text(context.tr('goal_setup_prompt_title'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 6),
              Text(context.tr('goal_setup_prompt_sub'),
                  style: TextStyle(fontSize: 13.5, height: 1.45, color: textSecondary)),
              const SizedBox(height: 16),
              AppButton(
                text: context.tr('goal_setup_prompt_cta'),
                onPressed: () => Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => const GoalSetupScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(calorieTrackingEnabledProvider.notifier).setEnabled(false);
            },
            child: Text(context.tr('hide_calories_tab'),
                style: TextStyle(fontSize: 13, color: textSecondary)),
          ),
        ),
      ],
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final NutritionGoal goal;

  const _Dashboard({required this.goal});

  static const _mealOrder = [MealType.breakfast, MealType.lunch, MealType.dinner, MealType.snack];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedLogDateProvider);
    final entriesAsync = ref.watch(dailyFoodLogProvider);
    final totals = ref.watch(dailyNutritionTotalsProvider);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final locale = Localizations.localeOf(context).toString();

    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    void changeDay(int delta) {
      HapticFeedback.selectionClick();
      ref.read(selectedLogDateProvider.notifier).state =
          selectedDate.add(Duration(days: delta));
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyFoodLogProvider);
        ref.invalidate(dailyWaterTotalProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenHorizontalPadding, 12, AppDimensions.screenHorizontalPadding, 140),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => changeDay(-1), icon: const Icon(Icons.chevron_left)),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(selectedLogDateProvider.notifier).state =
                      DateTime(today.year, today.month, today.day);
                },
                child: Text(
                  isToday
                      ? context.tr('today')
                      : DateFormat('EEEE, d. MMM', locale).format(selectedDate),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                ),
              ),
              IconButton(
                onPressed: isToday ? null : () => changeDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => const GoalSetupScreen())),
                icon: Icon(Icons.tune, color: textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => const WeeklySummaryScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(context.tr('weekly_summary_entry'),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentColor(context))),
                      Icon(Icons.chevron_right,
                          size: 16, color: AppColors.accentColor(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          WeeklyCaloriesStrip(
            target: goal.dailyCalorieTarget ?? 2000,
            onTap: () => Navigator.of(context)
                .push(CupertinoPageRoute(builder: (_) => const WeeklySummaryScreen())),
          ),
          const SizedBox(height: 16),
          Center(
            child: CalorieRing(
              consumed: totals.calories,
              target: goal.dailyCalorieTarget ?? 2000,
              leftLabel: context.tr('calories_left'),
              overLabel: context.tr('calories_over'),
            ),
          ),
          const SizedBox(height: 16),
          AppOutlineButton(
            text: context.tr('what_can_i_eat_cta'),
            icon: Icons.restaurant_menu_outlined,
            onPressed: () => Navigator.of(context)
                .push(CupertinoPageRoute(builder: (_) => const WhatCanIEatScreen())),
          ),
          const SizedBox(height: 24),
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                MacroBar(
                    label: context.tr('protein'),
                    valueG: totals.proteinG,
                    targetG: goal.proteinTargetG,
                    color: const Color(0xFF5B9BD5)),
                const SizedBox(height: 14),
                MacroBar(
                    label: context.tr('carbs'),
                    valueG: totals.carbsG,
                    targetG: goal.carbsTargetG,
                    color: const Color(0xFFE0A458)),
                const SizedBox(height: 14),
                MacroBar(
                    label: context.tr('fat'),
                    valueG: totals.fatG,
                    targetG: goal.fatTargetG,
                    color: const Color(0xFFD9694F)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WaterTrackerCard(targetMl: goal.waterTargetMl),
          const SizedBox(height: 16),
          const ChallengesEntryCard(),
          const SizedBox(height: 16),
          AppOutlineButton(
            text: context.tr('log_weight_cta'),
            icon: Icons.monitor_weight_outlined,
            onPressed: () => Navigator.of(context)
                .push(CupertinoPageRoute(builder: (_) => const WeightTrackingScreen())),
          ),
          const SizedBox(height: 24),
          entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text(context.tr('calories_log_error'), style: TextStyle(color: textSecondary)),
            data: (entries) => Column(
              children: _mealOrder.map((meal) {
                final mealEntries = entries.where((e) => e.mealType == meal).toList();
                final mealCalories = mealEntries.fold(0, (sum, e) => sum + e.calories);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: AppCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(context.tr('meal_${meal.dbValue}'),
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                            const Spacer(),
                            if (mealCalories > 0)
                              Text('$mealCalories kcal',
                                  style: TextStyle(fontSize: 13, color: textSecondary)),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => showFoodEntrySheet(context,
                                  mealType: meal, date: selectedDate),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.add_circle_outline,
                                    color: AppColors.accentColor(context), size: 22),
                              ),
                            ),
                          ],
                        ),
                        if (mealEntries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(context.tr('meal_empty'),
                                style: TextStyle(fontSize: 12.5, color: textSecondary)),
                          )
                        else
                          ...mealEntries.map((entry) => FoodLogTile(
                                entry: entry,
                                onDelete: () async {
                                  await ref.read(foodLogServiceProvider).deleteEntry(entry.id);
                                  invalidateNutritionLog(ref);
                                },
                              )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
