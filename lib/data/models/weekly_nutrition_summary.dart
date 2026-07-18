import 'package:equatable/equatable.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/weight_log_entry.dart';

/// Aggregated look-back over the last 7 days of nutrition logging — the
/// numbers behind the weekly summary screen. Pure computation over
/// already-fetched data; no I/O, so it stays unit-testable.
///
/// Semantics (documented here because they're product decisions, not math):
/// - "Logged day" = a day with at least one food log entry. Averages are
///   per *logged* day — an unlogged day is treated as unknown, not as 0 kcal.
/// - "Within budget" = a logged day whose calories are ≤ 105% of the daily
///   target (small rounding grace); unlogged days never count as on-budget.
/// - "Protein reached" = a logged day with ≥ 90% of the protein target.
/// - Water average is per day *with water logged*, for the same reason.
/// - The weight delta is only reported when two weigh-ins fall inside the
///   7-day window — no guessing a trend from a single point.
class WeeklyNutritionSummary extends Equatable {
  /// The 7 days of the window, oldest first (normalized to midnight).
  final List<DateTime> days;
  final int loggedDayCount;
  final int avgCalories;
  final int daysWithinBudget;
  final double avgProteinG;
  final double avgCarbsG;
  final double avgFatG;
  final int proteinReachedDays;
  final int avgWaterMl;
  final int waterLoggedDayCount;
  final int waterReachedDays;

  /// First-to-last weigh-in change inside the window; null when fewer than
  /// two weigh-ins exist in the last 7 days.
  final double? weightDeltaKg;
  final double? latestWeightKg;

  /// Consecutive days with ≥1 food entry, ending today — or yesterday when
  /// today has nothing yet (an unfinished day doesn't break the streak).
  final int loggingStreak;

  /// Per-day calories for the chart, keyed by normalized day; a missing key
  /// means nothing was logged that day.
  final Map<DateTime, int> caloriesByDay;

  const WeeklyNutritionSummary({
    required this.days,
    required this.loggedDayCount,
    required this.avgCalories,
    required this.daysWithinBudget,
    required this.avgProteinG,
    required this.avgCarbsG,
    required this.avgFatG,
    required this.proteinReachedDays,
    required this.avgWaterMl,
    required this.waterLoggedDayCount,
    required this.waterReachedDays,
    required this.weightDeltaKg,
    required this.latestWeightKg,
    required this.loggingStreak,
    required this.caloriesByDay,
  });

  bool get hasAnyData => loggedDayCount > 0;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  factory WeeklyNutritionSummary.compute({
    required Map<DateTime, DailyNutritionTotals> dailyTotals,
    required Map<DateTime, int> waterTotals,
    required List<WeightLogEntry> weightHistory,
    required Set<DateTime> loggedDates,
    required NutritionGoal goal,
    required DateTime today,
  }) {
    final todayKey = _day(today);
    final days =
        List.generate(7, (i) => todayKey.subtract(Duration(days: 6 - i)));

    final calorieTarget = goal.dailyCalorieTarget ?? 0;
    final proteinTarget = goal.proteinTargetG ?? 0;
    final waterTarget = goal.waterTargetMl;

    var loggedDayCount = 0;
    var calorieSum = 0;
    var daysWithinBudget = 0;
    var proteinSum = 0.0, carbsSum = 0.0, fatSum = 0.0;
    var proteinReachedDays = 0;
    final caloriesByDay = <DateTime, int>{};

    for (final day in days) {
      final totals = dailyTotals[day];
      if (totals == null) continue;
      loggedDayCount++;
      calorieSum += totals.calories;
      caloriesByDay[day] = totals.calories;
      proteinSum += totals.proteinG;
      carbsSum += totals.carbsG;
      fatSum += totals.fatG;
      if (calorieTarget > 0 && totals.calories <= calorieTarget * 1.05) {
        daysWithinBudget++;
      }
      if (proteinTarget > 0 && totals.proteinG >= proteinTarget * 0.9) {
        proteinReachedDays++;
      }
    }

    var waterSum = 0;
    var waterLoggedDayCount = 0;
    var waterReachedDays = 0;
    for (final day in days) {
      final ml = waterTotals[day] ?? 0;
      if (ml <= 0) continue;
      waterLoggedDayCount++;
      waterSum += ml;
      if (waterTarget > 0 && ml >= waterTarget) waterReachedDays++;
    }

    final windowStart = days.first;
    final weighIns = weightHistory
        .where((e) {
          final d = _day(e.loggedDate);
          return !d.isBefore(windowStart) && !d.isAfter(todayKey);
        })
        .toList()
      ..sort((a, b) => a.loggedDate.compareTo(b.loggedDate));
    final weightDeltaKg = weighIns.length >= 2
        ? weighIns.last.weightKg - weighIns.first.weightKg
        : null;
    final latestWeightKg =
        weightHistory.isEmpty ? null : weightHistory.last.weightKg;

    final normalizedLogged = loggedDates.map(_day).toSet();
    var streak = 0;
    var cursor = normalizedLogged.contains(todayKey)
        ? todayKey
        : todayKey.subtract(const Duration(days: 1));
    while (normalizedLogged.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return WeeklyNutritionSummary(
      days: days,
      loggedDayCount: loggedDayCount,
      avgCalories: loggedDayCount == 0 ? 0 : (calorieSum / loggedDayCount).round(),
      daysWithinBudget: daysWithinBudget,
      avgProteinG: loggedDayCount == 0 ? 0 : proteinSum / loggedDayCount,
      avgCarbsG: loggedDayCount == 0 ? 0 : carbsSum / loggedDayCount,
      avgFatG: loggedDayCount == 0 ? 0 : fatSum / loggedDayCount,
      proteinReachedDays: proteinReachedDays,
      avgWaterMl:
          waterLoggedDayCount == 0 ? 0 : (waterSum / waterLoggedDayCount).round(),
      waterLoggedDayCount: waterLoggedDayCount,
      waterReachedDays: waterReachedDays,
      weightDeltaKg: weightDeltaKg,
      latestWeightKg: latestWeightKg,
      loggingStreak: streak,
      caloriesByDay: caloriesByDay,
    );
  }

  @override
  List<Object?> get props => [
        days,
        loggedDayCount,
        avgCalories,
        daysWithinBudget,
        avgProteinG,
        avgCarbsG,
        avgFatG,
        proteinReachedDays,
        avgWaterMl,
        waterLoggedDayCount,
        waterReachedDays,
        weightDeltaKg,
        latestWeightKg,
        loggingStreak,
        caloriesByDay,
      ];
}
