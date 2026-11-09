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
  String? chain = 'lidl',
}) {
  return ShoppingHistory(
    id: 'h',
    userId: 'u',
    listName: 'Wocheneinkauf',
    totalItems: items.length,
    completedAt: completedAt ?? DateTime(2026, 1, 1),
    items: items,
    storeChainId: chain,
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

  group('AvoAssistantService.summarizeSavings (rounded, region only)', () {
    test('nothing saved: no amount, the trips of the month still count', () {
      final result = AvoAssistantService.summarizeSavings(
        [_trip(items: [_historyItem(price: 1.5, priceOldValue: null)])],
        DateTime(2026, 1, 1),
        realRegion: true,
      );
      expect(result['month_trips'], 1);
      expect(result['month_saved_cents'], isNull);
      expect(result.containsKey('month_saved_about_eur'), isFalse);
      expect(result['note'], isA<String>());
    });

    test('sums across trips and rounds to 10 ct', () {
      final result = AvoAssistantService.summarizeSavings(
        [
          _trip(items: [
            _historyItem(price: 0.89, priceOldValue: 1.19, quantity: 2),
            _historyItem(price: 1.5, priceOldValue: null),
          ]),
          _trip(items: [
            _historyItem(price: 2.0, priceOldValue: 2.57, quantity: 1),
          ]),
        ],
        DateTime(2026, 1, 1),
        realRegion: true,
      );
      // (1.19-0.89)*2 + (2.57-2.0) = 0.60 + 0.57 = 1.17 -> about 1.20
      expect(result['month_saved_cents'], 120);
      expect(result['month_saved_about_eur'], 1.2);
      expect(result['total_saved_about_eur'], 1.2);
      expect(result['month_trips'], 2);
    });

    test('I5: a trip without a market saves nothing, as in V4/V9', () {
      final result = AvoAssistantService.summarizeSavings(
        [
          _trip(
            chain: null,
            items: [_historyItem(price: 1.0, priceOldValue: 3.0)],
          ),
        ],
        DateTime(2026, 1, 1),
        realRegion: true,
      );
      expect(result['month_saved_cents'], isNull);
    });

    test('below 0,50 € there is no amount', () {
      final result = AvoAssistantService.summarizeSavings(
        [_trip(items: [_historyItem(price: 0.89, priceOldValue: 1.19)])],
        DateTime(2026, 1, 1),
        realRegion: true,
      );
      expect(result['month_saved_cents'], isNull);
    });

    test('never negative', () {
      final result = AvoAssistantService.summarizeSavings(
        [_trip(items: [_historyItem(price: 2.0, priceOldValue: 1.0)])],
        DateTime(2026, 1, 1),
        realRegion: true,
      );
      expect(result['month_saved_cents'], isNull);
    });

    test('without a real region there is no savings figure at all', () {
      final result = AvoAssistantService.summarizeSavings(
        [_trip(items: [_historyItem(price: 1.0, priceOldValue: 3.0)])],
        DateTime(2026, 1, 1),
        realRegion: false,
      );
      expect(result['month_saved_cents'], isNull);
      expect(result.containsKey('total_saved_about_eur'), isFalse);
    });

    test('the previous month rolls over January to December', () {
      final result = AvoAssistantService.summarizeSavings(
        [
          _trip(
            items: [_historyItem(price: 1.0, priceOldValue: 2.0)],
            completedAt: DateTime(2026, 1, 5),
          ),
          _trip(
            items: [_historyItem(price: 1.5, priceOldValue: 2.5)],
            completedAt: DateTime(2025, 12, 28),
          ),
        ],
        DateTime(2026, 1, 20),
        realRegion: true,
      );
      expect(result['month_saved_about_eur'], 1.0);
      expect(result['prev_month_saved_about_eur'], 1.0);
      expect(result['month_trips'], 1);
    });
  });
}
