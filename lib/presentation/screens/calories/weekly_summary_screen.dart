import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/presentation/screens/calories/weight_tracking_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/macro_bar.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Weekly look-back over the last 7 days of logging: average calories vs.
/// target, per-day bars, macro averages, water and weight trend. Reached by
/// tapping the weekly strip on the calorie dashboard.
class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklyNutritionSummaryProvider);
    final textPrimary = AppColors.textPrimary(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(context.tr('weekly_summary_title'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(context.tr('calories_log_error'))),
          data: (summary) {
            if (summary == null || !summary.hasAnyData) {
              return AppEmptyState(
                icon: Icons.insights_outlined,
                title: context.tr('weekly_summary_empty_title'),
                subtitle: context.tr('weekly_summary_empty_sub'),
              );
            }
            return _SummaryBody(summary: summary);
          },
        ),
      ),
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  final WeeklyNutritionSummary summary;

  const _SummaryBody({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(nutritionGoalProvider).valueOrNull;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final locale = Localizations.localeOf(context).toString();
    final rangeFormat = DateFormat('d. MMM', locale);

    final target = goal?.dailyCalorieTarget ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(
          '${rangeFormat.format(summary.days.first)} – ${rangeFormat.format(summary.days.last)}',
          style: TextStyle(fontSize: 12.5, color: textSecondary),
        ),
        if (summary.loggingStreak >= 2) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.local_fire_department_outlined, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                context.tr('weekly_streak',
                    params: {'n': summary.loggingStreak.toString()}),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('calories'),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ø ${summary.avgCalories}',
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w700, color: textPrimary)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      target > 0 ? 'kcal / $target' : 'kcal',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('weekly_days_logged_budget', params: {
                  'logged': summary.loggedDayCount.toString(),
                  'budget': summary.daysWithinBudget.toString(),
                }),
                style: TextStyle(fontSize: 12.5, color: textSecondary),
              ),
              const SizedBox(height: 18),
              _WeekBars(summary: summary, target: target),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(context.tr('weekly_macros_title'),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                  const Spacer(),
                  Text(context.tr('weekly_macros_caption'),
                      style: TextStyle(fontSize: 11.5, color: textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              MacroBar(
                  label: context.tr('protein'),
                  valueG: summary.avgProteinG,
                  targetG: goal?.proteinTargetG,
                  color: const Color(0xFF5B9BD5)),
              const SizedBox(height: 14),
              MacroBar(
                  label: context.tr('carbs'),
                  valueG: summary.avgCarbsG,
                  targetG: goal?.carbsTargetG,
                  color: const Color(0xFFE0A458)),
              const SizedBox(height: 14),
              MacroBar(
                  label: context.tr('fat'),
                  valueG: summary.avgFatG,
                  targetG: goal?.fatTargetG,
                  color: const Color(0xFFD9694F)),
              if ((goal?.proteinTargetG ?? 0) > 0) ...[
                const SizedBox(height: 14),
                Text(
                  context.tr('weekly_protein_reached', params: {
                    'hit': summary.proteinReachedDays.toString(),
                    'logged': summary.loggedDayCount.toString(),
                  }),
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_outlined,
                      size: 20, color: Color(0xFF5B9BD5)),
                  const SizedBox(width: 8),
                  Text(context.tr('water'),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              if (summary.waterLoggedDayCount == 0)
                Text(context.tr('weekly_water_empty'),
                    style: TextStyle(fontSize: 12.5, color: textSecondary))
              else ...[
                Text(
                  context.tr('weekly_water_line', params: {
                    'liters': (summary.avgWaterMl / 1000).toStringAsFixed(1),
                    'days': summary.waterLoggedDayCount.toString(),
                  }),
                  style: TextStyle(fontSize: 13, color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('weekly_water_reached',
                      params: {'n': summary.waterReachedDays.toString()}),
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          margin: EdgeInsets.zero,
          onTap: () => Navigator.of(context)
              .push(CupertinoPageRoute(builder: (_) => const WeightTrackingScreen())),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, size: 20, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('weight_tracking_title'),
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 4),
                    if (summary.weightDeltaKg != null)
                      Text(
                        context.tr('weekly_weight_delta', params: {
                          'delta':
                              '${summary.weightDeltaKg! >= 0 ? '+' : ''}${summary.weightDeltaKg!.toStringAsFixed(1)}'
                        }),
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      )
                    else
                      Text(context.tr('weekly_weight_hint'),
                          style: TextStyle(fontSize: 12.5, color: textSecondary)),
                    if (summary.latestWeightKg != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr('weekly_weight_current', params: {
                          'weight': summary.latestWeightKg!.toStringAsFixed(1)
                        }),
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// Larger version of the dashboard's weekly strip: one bar per day with the
/// day's kcal above it (logged days only) and the weekday initial below.
class _WeekBars extends StatelessWidget {
  final WeeklyNutritionSummary summary;
  final int target;

  const _WeekBars({required this.summary, required this.target});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime.now();

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: summary.days.map((day) {
          final calories = summary.caloriesByDay[day];
          final ratio =
              target <= 0 || calories == null ? 0.0 : (calories / target).clamp(0.0, 1.2);
          final isToday =
              day.year == today.year && day.month == today.month && day.day == today.day;
          final over = target > 0 && calories != null && calories > target * 1.05;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (calories != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('$calories',
                          style: TextStyle(fontSize: 9, color: textSecondary)),
                    ),
                  Container(
                    height: 56 * (calories == null ? 0.05 : ratio.clamp(0.08, 1.0)),
                    decoration: BoxDecoration(
                      color: over
                          ? const Color(0xFFE0764A)
                          : (isToday ? accent : accent.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(DateFormat('E', locale).format(day).substring(0, 1),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: isToday ? accent : textSecondary,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
