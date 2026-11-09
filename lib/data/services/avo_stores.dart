import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/nutrition_goal_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/weight_log_service.dart';

// What Avo's goal and cost-split cards read and write, behind interfaces
// (W1b re-review N3, N4, N8): the tool and the tap use the same store, and
// tests put an in-memory one in the providers. The decisions around them
// (what a tap writes, what its undo puts back) are the functions below.

/// The person's calorie goal and weight log.
abstract interface class AvoGoalStore {
  String? get userId;
  Future<NutritionGoal?> goal();
  Future<NutritionGoal> saveGoal(NutritionGoal goal);
  Future<WeightLogEntry?> latestWeight();
  Future<WeightLogEntry> logWeight(double kg);
  Future<void> deleteWeight(String id);
}

/// The person's shopping trips and their splits.
abstract interface class AvoSplitStore {
  String? get userId;

  /// A trip by id (the newest 30).
  Future<ShoppingHistory?> trip(String historyId);
  Future<List<ExpenseSplit>> splits(String historyId);
  Future<void> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
  });
}

final avoGoalStoreProvider = Provider<AvoGoalStore>(
  (ref) => const _ServiceGoalStore(),
);

final avoSplitStoreProvider = Provider<AvoSplitStore>(
  (ref) => const _ServiceSplitStore(),
);

String? _signedInUser() => Supabase.instance.client.auth.currentUser?.id;

class _ServiceGoalStore implements AvoGoalStore {
  const _ServiceGoalStore();

  @override
  String? get userId => _signedInUser();

  @override
  Future<NutritionGoal?> goal() => NutritionGoalService.instance.getGoal();

  @override
  Future<NutritionGoal> saveGoal(NutritionGoal goal) =>
      NutritionGoalService.instance.saveGoal(goal);

  @override
  Future<WeightLogEntry?> latestWeight() =>
      WeightLogService.instance.getLatest();

  @override
  Future<WeightLogEntry> logWeight(double kg) =>
      WeightLogService.instance.logWeight(weightKg: kg);

  @override
  Future<void> deleteWeight(String id) => WeightLogService.instance.delete(id);
}

class _ServiceSplitStore implements AvoSplitStore {
  const _ServiceSplitStore();

  @override
  String? get userId => _signedInUser();

  @override
  Future<ShoppingHistory?> trip(String historyId) async {
    final history = await ShoppingHistoryService().getRecentHistory(limit: 30);
    for (final h in history) {
      if (h.id == historyId) return h;
    }
    return null;
  }

  @override
  Future<List<ExpenseSplit>> splits(String historyId) =>
      ExpenseSplitService.instance.getSplitsForHistory(historyId);

  @override
  Future<void> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
  }) => ExpenseSplitService.instance.createSplits(
    historyId: historyId,
    totalCost: totalCost,
    shares: shares,
    paidByUserId: paidByUserId,
    paidByName: paidByName,
  );
}

// ------------------------------------------------------------------- goal

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The goal "Übernehmen" saves: the goal at the tap ([base], or a new one)
/// with exactly the fields the card showed from [shown]. Everything the
/// card did not show (water target, workouts credited, pace) stays as it
/// was at the tap.
NutritionGoal avoMergedGoal(
  NutritionGoal shown,
  NutritionGoal? base, {
  required DateTime now,
}) {
  final b = base;
  return NutritionGoal(
    userId: shown.userId,
    calorieTrackingEnabled: true,
    goalType: shown.goalType,
    activityLevel: shown.activityLevel,
    currentWeightKg: shown.currentWeightKg,
    targetWeightKg: shown.targetWeightKg,
    heightCm: shown.heightCm,
    timelineWeeks: shown.timelineWeeks,
    dailyCalorieTarget: shown.dailyCalorieTarget,
    proteinTargetG: shown.proteinTargetG,
    carbsTargetG: shown.carbsTargetG,
    fatTargetG: shown.fatTargetG,
    waterTargetMl: b?.waterTargetMl ?? shown.waterTargetMl,
    creditWorkouts: b?.creditWorkouts ?? shown.creditWorkouts,
    pace: b?.pace ?? shown.pace,
    createdAt: b?.createdAt ?? now,
    updatedAt: now,
  );
}

/// "Übernehmen" on a goal preview: reads the goal and today's weight now,
/// saves [avoMergedGoal], and writes the card's weight for today only when
/// the card said so ([AvoGoalPreviewCard.writesWeight]) and today still
/// has no entry. "Widerrufen" takes back exactly that, the weight entry
/// first, so a failed step can be tried again (Avo's own leftover is never
/// "Inzwischen geändert"). [changed] refreshes what shows the goal.
Future<AvoGoalRecord> avoApplyGoal(
  AvoGoalStore store,
  AvoGoalPreviewCard card, {
  required DateTime now,
  void Function()? changed,
}) async {
  final before = await store.goal();
  final saved = await store.saveGoal(
    avoMergedGoal(card.goal, before, now: now),
  );
  WeightLogEntry? added;
  final kg = card.goal.currentWeightKg;
  if (card.writesWeight && kg != null) {
    final latest = await store.latestWeight();
    if (latest == null || !_sameDay(latest.loggedDate, now)) {
      added = await store.logWeight(kg);
    }
  }
  changed?.call();
  final had = before != null && before.isConfigured;
  var weightBack = added == null;
  return AvoGoalRecord(
    tool: 'setup_nutrition_goal',
    kcal: saved.dailyCalorieTarget ?? card.goal.dailyCalorieTarget ?? 0,
    previousKcal: had ? before.dailyCalorieTarget : null,
    weightKg: added?.weightKg,
    undo: () async {
      try {
        final current = await store.goal();
        final goalStill =
            current != null &&
            current.dailyCalorieTarget == saved.dailyCalorieTarget &&
            current.goalType == saved.goalType &&
            current.activityLevel == saved.activityLevel;
        if (!goalStill) return AvoUndoResult.changedSince;
        if (!weightBack) {
          final latest = await store.latestWeight();
          final ours =
              latest != null &&
              latest.id == added!.id &&
              latest.weightKg == added.weightKg;
          if (!ours) return AvoUndoResult.changedSince;
          await store.deleteWeight(added.id);
          weightBack = true;
        }
        await store.saveGoal(
          before ??
              NutritionGoal(
                userId: saved.userId,
                calorieTrackingEnabled: true,
                waterTargetMl: saved.waterTargetMl,
                createdAt: saved.createdAt,
                updatedAt: DateTime.now(),
              ),
        );
        changed?.call();
        return AvoUndoResult.undone;
      } catch (_) {
        return AvoUndoResult.failed;
      }
    },
  );
}

// ------------------------------------------------------------------ split

/// "Teilen" on a split preview: reads trip, payer and split again and saves
/// only when all are as the card showed them and the module is still on
/// ([moduleOn]); null otherwise (the card is out of date). The trip's payer
/// stays; only a trip without one gets the person as payer, as the card
/// said ([AvoSplitPreviewCard.payerIsNew]).
Future<AvoSplitRecord?> avoSplitTrip(
  AvoSplitStore store,
  AvoSplitPreviewCard card, {
  required bool moduleOn,
}) async {
  if (!moduleOn) return null;
  final userId = store.userId;
  if (userId == null || userId != card.yourUserId) return null;
  final trip = await store.trip(card.historyId);
  if (trip == null) return null;
  final total = trip.totalCost;
  final hasTotal = total != null && total > 0;
  if (hasTotal != card.totalFromTrip ||
      (hasTotal && (total - card.total).abs() > 0.005)) {
    return null;
  }
  final payerNow = (id: trip.paidByUserId, name: trip.paidByName);
  final payerShown = card.payerIsNew
      ? (id: null, name: null)
      : (id: card.payerUserId, name: card.payerName);
  if (payerNow != payerShown) return null;
  final existing = await store.splits(card.historyId);
  final now = [
    for (final s in existing) (name: s.participantName, paid: s.isPaid),
  ];
  if (now.length != card.replaces.length ||
      !now.every(card.replaces.contains)) {
    return null;
  }
  await store.createSplits(
    historyId: card.historyId,
    totalCost: card.total,
    shares: [
      for (final s in card.shares)
        SplitShare(
          userId: s.isYou ? userId : null,
          participantName: s.name,
          amount: s.amount,
        ),
    ],
    paidByUserId: card.payerIsNew ? userId : card.payerUserId,
    paidByName: card.payerName,
  );
  return AvoSplitRecord(
    tool: 'split_trip_cost',
    tripDate: card.tripDate,
    shares: card.shares,
  );
}
