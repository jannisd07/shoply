// What "Übernehmen" and "Teilen" write and what their undo puts back (W1b
// re-review N1, N3, N4): against in-memory stores.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/weight_log_entry.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_stores.dart';
import 'package:shoply/data/services/expense_split_service.dart';

final _now = DateTime(2026, 11, 9, 12);

class _GoalStore implements AvoGoalStore {
  NutritionGoal? stored;
  final List<WeightLogEntry> weights = [];
  int _n = 0;
  bool failDelete = false;

  @override
  String? get userId => 'u1';

  @override
  Future<NutritionGoal?> goal() async => stored;

  @override
  Future<NutritionGoal> saveGoal(NutritionGoal goal) async => stored = goal;

  @override
  Future<WeightLogEntry?> latestWeight() async =>
      weights.isEmpty ? null : weights.last;

  @override
  Future<WeightLogEntry> logWeight(double kg) async {
    final e = WeightLogEntry(
      id: 'w${_n++}',
      userId: 'u1',
      loggedDate: _now,
      weightKg: kg,
      createdAt: _now,
    );
    weights.add(e);
    return e;
  }

  @override
  Future<void> deleteWeight(String id) async {
    if (failDelete) throw Exception('offline');
    weights.removeWhere((w) => w.id == id);
  }
}

NutritionGoal _goal(
  int kcal, {
  int water = 2000,
  bool credit = false,
  GoalPace? pace,
}) => NutritionGoal(
  userId: 'u1',
  calorieTrackingEnabled: true,
  goalType: NutritionGoalType.loseWeight,
  activityLevel: ActivityLevel.moderate,
  currentWeightKg: 80,
  dailyCalorieTarget: kcal,
  waterTargetMl: water,
  creditWorkouts: credit,
  pace: pace,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('Übernehmen (N3, N4)', () {
    test('keeps what the card did not show from the goal at the tap', () async {
      final store = _GoalStore()
        ..stored = _goal(
          2000,
          water: 2500,
          credit: true,
          pace: GoalPace.zuegig,
        );
      final card = AvoGoalPreviewCard(goal: _goal(1800));
      final record = await avoApplyGoal(store, card, now: _now);
      expect(store.stored!.dailyCalorieTarget, 1800);
      expect(store.stored!.waterTargetMl, 2500);
      expect(store.stored!.creditWorkouts, isTrue);
      expect(store.stored!.pace, GoalPace.zuegig);
      expect(store.stored!.createdAt, DateTime(2026, 1, 1));
      expect(record.previousKcal, 2000);
      expect(record.weightKg, isNull, reason: 'the card wrote no weight');
      expect(store.weights, isEmpty);
    });

    test('writes the weight only when the card said so and today has none; '
        'undo takes back exactly that', () async {
      final store = _GoalStore()..stored = _goal(2000);
      final record = await avoApplyGoal(
        store,
        AvoGoalPreviewCard(goal: _goal(1800), writesWeight: true),
        now: _now,
      );
      expect(record.weightKg, 80);
      expect(store.weights.single.weightKg, 80);
      expect(await record.undo!(), AvoUndoResult.undone);
      expect(store.weights, isEmpty);
      expect(store.stored!.dailyCalorieTarget, 2000);
    });

    test('a failed weight delete can be tried again (no "changed since" for '
        'Avo\'s own leftover)', () async {
      final store = _GoalStore()..stored = _goal(2000);
      final record = await avoApplyGoal(
        store,
        AvoGoalPreviewCard(goal: _goal(1800), writesWeight: true),
        now: _now,
      );
      store.failDelete = true;
      expect(await record.undo!(), AvoUndoResult.failed);
      expect(store.stored!.dailyCalorieTarget, 1800, reason: 'goal untouched');
      store.failDelete = false;
      expect(await record.undo!(), AvoUndoResult.undone);
      expect(store.weights, isEmpty);
      expect(store.stored!.dailyCalorieTarget, 2000);
    });

    test('today already has a weight: none written', () async {
      final store = _GoalStore()..stored = _goal(2000);
      await store.logWeight(79);
      final record = await avoApplyGoal(
        store,
        AvoGoalPreviewCard(goal: _goal(1800), writesWeight: true),
        now: _now,
      );
      expect(record.weightKg, isNull);
      expect(store.weights.single.weightKg, 79);
    });

    test(
      'changed since: nothing is touched; a first goal is cleared again',
      () async {
        final store = _GoalStore()..stored = _goal(2000);
        final record = await avoApplyGoal(
          store,
          AvoGoalPreviewCard(goal: _goal(1800)),
          now: _now,
        );
        store.stored = _goal(1700);
        expect(await record.undo!(), AvoUndoResult.changedSince);
        expect(store.stored!.dailyCalorieTarget, 1700);

        final fresh = _GoalStore();
        final first = await avoApplyGoal(
          fresh,
          AvoGoalPreviewCard(goal: _goal(1800)),
          now: _now,
        );
        expect(first.previousKcal, isNull);
        expect(await first.undo!(), AvoUndoResult.undone);
        expect(fresh.stored!.isConfigured, isFalse);
      },
    );
  });

  group('Teilen (N1)', () {
    test('keeps the trip\'s payer, refuses when the payer, the split or the '
        'module changed', () async {
      final store = _SplitStore(paidByName: 'Lena');
      final card = AvoSplitPreviewCard(
        historyId: 't1',
        tripDate: DateTime(2026, 10, 31),
        total: 40,
        totalFromTrip: true,
        yourUserId: 'u1',
        payerName: 'Lena',
        payerIsYou: false,
        shares: const [
          (name: 'Jannis', amount: 20, isYou: true),
          (name: 'Lena', amount: 20, isYou: false),
        ],
      );
      expect(await avoSplitTrip(store, card, moduleOn: false), isNull);
      expect(store.created, isEmpty);
      final record = await avoSplitTrip(store, card, moduleOn: true);
      expect(record, isNotNull);
      expect(store.created.single.paidByName, 'Lena');
      expect(store.created.single.paidByUserId, isNull);

      final moved = _SplitStore(paidByName: 'Max');
      expect(await avoSplitTrip(moved, card, moduleOn: true), isNull);
      expect(moved.created, isEmpty);
    });

    test('a trip without a payer gets the person, as the card said', () async {
      final store = _SplitStore();
      final card = AvoSplitPreviewCard(
        historyId: 't1',
        tripDate: DateTime(2026, 10, 31),
        total: 40,
        totalFromTrip: true,
        yourUserId: 'u1',
        payerUserId: 'u1',
        payerName: 'Jannis',
        payerIsNew: true,
        shares: const [
          (name: 'Jannis', amount: 20, isYou: true),
          (name: 'Lena', amount: 20, isYou: false),
        ],
      );
      expect(await avoSplitTrip(store, card, moduleOn: true), isNotNull);
      expect(store.created.single.paidByUserId, 'u1');
      expect(store.created.single.shares.first.userId, 'u1');
    });
  });
}

class _SplitStore implements AvoSplitStore {
  _SplitStore({this.paidByName});

  final String? paidByName;
  final List<
    ({String? paidByUserId, String? paidByName, List<SplitShare> shares})
  >
  created = [];

  @override
  String? get userId => 'u1';

  @override
  Future<ShoppingHistory?> trip(String historyId) async => ShoppingHistory(
    id: historyId,
    userId: 'u1',
    listName: 'Wocheneinkauf',
    totalItems: 3,
    completedAt: DateTime(2026, 10, 31),
    totalCost: 40,
    paidByName: paidByName,
  );

  @override
  Future<List<ExpenseSplit>> splits(String historyId) async => const [];

  @override
  Future<void> createSplits({
    required String historyId,
    required double totalCost,
    required List<SplitShare> shares,
    String? paidByUserId,
    String? paidByName,
  }) async => created.add((
    paidByUserId: paidByUserId,
    paidByName: paidByName,
    shares: shares,
  ));
}
