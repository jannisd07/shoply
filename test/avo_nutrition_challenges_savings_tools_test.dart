import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/weekly_nutrition_summary.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';

NutritionGoal _goal({
  int? dailyCalorieTarget = 2000,
  int? proteinTargetG = 120,
}) {
  final now = DateTime(2026, 1, 1);
  return NutritionGoal(
    userId: 'u',
    dailyCalorieTarget: dailyCalorieTarget,
    proteinTargetG: proteinTargetG,
    createdAt: now,
    updatedAt: now,
  );
}

WeeklyNutritionSummary _summary({
  int loggedDayCount = 5,
  double? weightDeltaKg,
  double? latestWeightKg,
  int waterLoggedDayCount = 0,
}) {
  return WeeklyNutritionSummary(
    days: List.generate(7, (i) => DateTime(2026, 1, 1 + i)),
    loggedDayCount: loggedDayCount,
    avgCalories: 1900,
    daysWithinBudget: 4,
    avgProteinG: 95.4,
    avgCarbsG: 180.2,
    avgFatG: 60.1,
    proteinReachedDays: 3,
    avgWaterMl: 1800,
    waterLoggedDayCount: waterLoggedDayCount,
    waterReachedDays: 2,
    weightDeltaKg: weightDeltaKg,
    latestWeightKg: latestWeightKg,
    loggingStreak: 3,
    caloriesByDay: const {},
    cookedMealCount: 4,
    cookedHighProteinMealCount: 2,
  );
}

DietChallenge _challenge({
  ChallengeType type = ChallengeType.noSugar30,
  Map<String, bool> checkins = const {},
  DateTime? targetEndAt,
}) {
  final now = DateTime(2026, 1, 1);
  return DietChallenge(
    id: 'c1',
    userId: 'u',
    type: type,
    startedAt: now,
    targetEndAt: targetEndAt,
    createdAt: now,
    dailyCheckins: checkins,
  );
}

ShoppingHistoryItem _historyItem({double? price, double? priceOldValue, double quantity = 1.0}) {
  return ShoppingHistoryItem(
    id: 'i',
    historyId: 'h',
    name: 'Milch',
    quantity: quantity,
    price: price,
    priceOldValue: priceOldValue,
  );
}

ShoppingHistory _trip({
  required List<ShoppingHistoryItem> items,
  DateTime? completedAt,
}) {
  return ShoppingHistory(
    id: 'h',
    userId: 'u',
    listName: 'Wocheneinkauf',
    totalItems: items.length,
    completedAt: completedAt ?? DateTime(2026, 1, 1),
    items: items,
  );
}

void main() {
  group('AvoAssistantService.summarizeWeeklyNutrition', () {
    test('shapes the summary with rounded macros and targets', () {
      final result = AvoAssistantService.summarizeWeeklyNutrition(_summary(), _goal());

      expect(result['found'], true);
      expect(result['days_logged'], 5);
      expect(result['avg_calories'], 1900);
      expect(result['calorie_target'], 2000);
      expect(result['avg_protein_g'], 95.4);
      expect(result['protein_target_g'], 120);
      expect(result['cooked_meals_this_week'], 4);
      expect(result['cooked_high_protein_meals_this_week'], 2);
      expect(result.containsKey('weight_change_kg'), false);
      expect(result.containsKey('avg_water_ml'), false);
    });

    test('includes weight change and water only when present', () {
      final result = AvoAssistantService.summarizeWeeklyNutrition(
        _summary(weightDeltaKg: -0.7, latestWeightKg: 74.3, waterLoggedDayCount: 3),
        _goal(),
      );

      expect(result['weight_change_kg'], -0.7);
      expect(result['latest_weight_kg'], 74.3);
      expect(result['avg_water_ml'], 1800);
    });
  });

  group('AvoAssistantService.summarizeChallengeStatus', () {
    test('reports found=0 with a note when nothing is active', () {
      final result = AvoAssistantService.summarizeChallengeStatus(const []);

      expect(result['found'], 0);
      expect(result.containsKey('challenges'), false);
      expect(result['note'], isA<String>());
    });

    test('shapes an active challenge with streak and adherence', () {
      final challenge = _challenge(
        type: ChallengeType.fasting16_8,
        checkins: {
          '2025-12-30': true,
          '2025-12-31': true,
          '2026-01-01': true,
        },
      );

      final result = AvoAssistantService.summarizeChallengeStatus([challenge]);

      expect(result['found'], 1);
      final c = (result['challenges'] as List).first as Map;
      expect(c['type'], '16:8 intermittent fasting');
      expect(c['total_checkins'], 3);
      expect(c['kept_count'], 3);
      expect(c['adherence_rate_percent'], 100);
      expect(c.containsKey('days_remaining'), false);
    });
  });

  group('AvoAssistantService.summarizeLifetimeSavings', () {
    test('reports zero total with a note when nothing was ever saved', () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [_trip(items: [_historyItem(price: 1.5, priceOldValue: null)])],
        DateTime(2026, 1, 1),
      );

      expect(result['total_saved_eur'], 0);
      expect(result.containsKey('trips_with_savings'), false);
      expect(result.containsKey('month_saved_eur'), false);
      expect(result['note'], isA<String>());
    });

    test('sums savings across trips and items, scaled by quantity', () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [
          _trip(items: [
            _historyItem(price: 0.89, priceOldValue: 1.19, quantity: 2),
            _historyItem(price: 1.5, priceOldValue: null),
          ]),
          _trip(items: [
            _historyItem(price: 2.0, priceOldValue: 2.5, quantity: 1),
          ]),
        ],
        DateTime(2026, 1, 1),
      );

      // (1.19-0.89)*2 + (2.5-2.0)*1 = 0.60 + 0.50 = 1.10
      expect(result['total_saved_eur'], 1.10);
      expect(result['trips_with_savings'], 2);
      // Both trips default to a January completedAt, matching "now".
      expect(result['month_saved_eur'], 1.10);
      expect(result.containsKey('prev_month_saved_eur'), false);
    });

    test('never reports a negative saving even if priceOldValue is lower', () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [_trip(items: [_historyItem(price: 2.0, priceOldValue: 1.0)])],
        DateTime(2026, 1, 1),
      );

      expect(result['total_saved_eur'], 0);
    });

    test(
        'month_saved_eur and prev_month_saved_eur are both 0 when the only '
        'savings are 2+ months old', () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [
          _trip(
            items: [_historyItem(price: 0.89, priceOldValue: 1.19)],
            completedAt: DateTime(2025, 11, 5),
          ),
        ],
        DateTime(2026, 1, 1),
      );

      expect(result['total_saved_eur'], 0.30);
      expect(result['month_saved_eur'], 0);
      expect(result.containsKey('prev_month_saved_eur'), false);
    });

    test('includes prev_month_saved_eur only once both months have savings',
        () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [
          _trip(
            items: [_historyItem(price: 0.89, priceOldValue: 1.19)],
            completedAt: DateTime(2026, 1, 10),
          ),
          _trip(
            items: [_historyItem(price: 1.5, priceOldValue: 2.0)],
            completedAt: DateTime(2025, 12, 20),
          ),
        ],
        DateTime(2026, 1, 15),
      );

      expect(result['month_saved_eur'], 0.30);
      expect(result['prev_month_saved_eur'], 0.50);
    });

    test('previous-month lookup rolls over January to December correctly',
        () {
      final result = AvoAssistantService.summarizeLifetimeSavings(
        [
          _trip(
            items: [_historyItem(price: 0.89, priceOldValue: 1.19)],
            completedAt: DateTime(2026, 1, 5),
          ),
          _trip(
            items: [_historyItem(price: 1.5, priceOldValue: 2.0)],
            completedAt: DateTime(2025, 12, 28),
          ),
        ],
        DateTime(2026, 1, 20),
      );

      expect(result['month_saved_eur'], 0.30);
      expect(result['prev_month_saved_eur'], 0.50);
    });
  });
}
