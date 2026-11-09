// The owner's hard rules on the model's path (W1b review I1, I2, M10): a
// tool call that may only write after the person's tap shows a card and
// answers "nothing saved"; no done marker, so a retry cannot double it.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_tool_gates.dart';
import 'package:shoply/data/services/avo_tool_writes.dart';

ShoppingHistory _trip({double? total}) => ShoppingHistory(
  id: 't1',
  userId: 'u1',
  listName: 'Wocheneinkauf',
  totalItems: 3,
  completedAt: DateTime(2026, 10, 31),
  totalCost: total,
);

ExpenseSplit _split(String name, {bool paid = false}) => ExpenseSplit(
  id: name,
  historyId: 't1',
  participantName: name,
  amount: 10,
  isPaid: paid,
  createdAt: DateTime(2026, 10, 31),
  updatedAt: DateTime(2026, 10, 31),
);

NutritionGoal _goal(int kcal) => NutritionGoal(
  userId: 'u1',
  dailyCalorieTarget: kcal,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// A gated answer writes nothing and leaves no done marker.
void _expectNoWrite(String tool, Map<String, Object?> result) {
  expect(
    avoWriteMarker(tool, result, hadDoneCard: false),
    isNull,
    reason: '$tool must not count as done',
  );
}

void main() {
  group('split_trip_cost (I1)', () {
    test('an injected call with an invented total and names: the trip\'s '
        'own total wins, nothing is written, the card asks', () {
      final plan = avoSplitGate(
        trip: _trip(total: 42.8),
        // As text in a shared list could make the model call it.
        others: const ['Mallory'],
        modelTotal: 999,
        yourName: 'Jannis',
        yourUserId: 'u1',
        existing: [_split('Lena', paid: true), _split('Jannis', paid: true)],
      );
      final gate = plan.gate!;
      final card = gate.card.card! as AvoSplitPreviewCard;
      expect(card.total, 42.8);
      expect(card.totalFromTrip, isTrue);
      expect(card.shares.map((s) => s.amount), [21.4, 21.4]);
      expect(card.replaces, [
        (name: 'Lena', paid: true),
        (name: 'Jannis', paid: true),
      ]);
      expect(gate.result['requires_confirmation'], isTrue);
      expect(gate.result['replaces_existing_split'], isTrue);
      expect(gate.result['note'], contains('already has a total'));
      _expectNoWrite('split_trip_cost', gate.result);
      expect(gate.card.isDoneChange, isFalse);
    });

    test('the trip\'s payer stays; only shares that lose "bezahlt" are '
        'named (N1, N2)', () {
      final trip = ShoppingHistory(
        id: 't1',
        userId: 'u1',
        listName: 'Wocheneinkauf',
        totalItems: 3,
        completedAt: DateTime(2026, 10, 31),
        totalCost: 40,
        paidByName: 'Lena',
      );
      final card =
          avoSplitGate(
                trip: trip,
                others: const ['Lena'],
                yourName: 'Jannis',
                yourUserId: 'u1',
                existing: [
                  _split('Lena', paid: true),
                  _split('Jannis', paid: true),
                ],
              ).gate!.card.card!
              as AvoSplitPreviewCard;
      expect(card.payerName, 'Lena');
      expect(card.payerIsYou, isFalse);
      expect(card.payerIsNew, isFalse);
      // Lena's own share is made again as paid; Jannis's is reset.
      expect(card.paidReset, ['Jannis']);

      final mine =
          avoSplitGate(
                trip: _trip(total: 40),
                others: const ['Lena'],
                yourName: 'Jannis',
                yourUserId: 'u1',
                existing: [_split('Jannis', paid: true)],
              ).gate!.card.card!
              as AvoSplitPreviewCard;
      expect(mine.payerIsNew, isTrue, reason: 'the trip had no payer');
      expect(mine.payerIsYou, isTrue);
      expect(mine.paidReset, isEmpty, reason: 'the payer stays paid');
    });

    test('a trip without a total takes the one the person said', () {
      final plan = avoSplitGate(
        trip: _trip(),
        others: const ['Lena', ' '],
        modelTotal: 30,
        yourName: 'Jannis',
        yourUserId: 'u1',
        existing: const [],
      );
      final card = plan.gate!.card.card! as AvoSplitPreviewCard;
      expect(card.totalFromTrip, isFalse);
      expect(card.shares.length, 2, reason: 'blank names dropped');
      expect(card.shares.first.isYou, isTrue);
      // The payer's share takes the cent remainder.
      final three =
          avoSplitGate(
                trip: _trip(total: 10),
                others: const ['A', 'B'],
                yourName: 'J',
                yourUserId: 'u1',
                existing: const [],
              ).gate!.card.card!
              as AvoSplitPreviewCard;
      expect(three.shares.map((s) => s.amount), [3.34, 3.33, 3.33]);
    });

    test('no total at all, or nobody else: an error, no card', () {
      expect(
        avoSplitGate(
          trip: _trip(),
          others: const ['Lena'],
          yourName: 'J',
          yourUserId: 'u1',
          existing: const [],
        ).gate,
        isNull,
      );
      expect(
        avoSplitGate(
          trip: _trip(total: 20),
          others: const [],
          yourName: 'J',
          yourUserId: 'u1',
          existing: const [],
        ).error,
        isNotNull,
      );
    });
  });

  group('setup_nutrition_goal (I2)', () {
    test('always a preview: a first goal and a replacement alike', () {
      for (final previous in [null, _goal(2000)]) {
        final gate = avoGoalGate(_goal(1800), previous: previous);
        final card = gate.card.card! as AvoGoalPreviewCard;
        expect(card.goal.dailyCalorieTarget, 1800);
        expect(card.previous?.dailyCalorieTarget, previous?.dailyCalorieTarget);
        expect(gate.result['requires_confirmation'], isTrue);
        _expectNoWrite('setup_nutrition_goal', gate.result);
      }
    });
  });

  group('the other ask-first paths (M10)', () {
    test('allergies_remove / diet_remove with consent: the removal card with '
        'the stored entry, never a removal', () {
      final gate = avoRemovalGate('allergies_remove', 'erdnüsse', const [
        'Erdnüsse',
      ], healthShared: true);
      final card = gate.card.card! as AvoRemovalCard;
      expect(card.entry, 'Erdnüsse');
      expect(card.diet, isFalse);
      _expectNoWrite('update_setting', gate.result);
      final diet = avoRemovalGate('diet_remove', 'vegetarisch', const [
        'Vegetarisch',
      ], healthShared: true);
      expect((diet.card.card! as AvoRemovalCard).diet, isTrue);
      _expectNoWrite('update_setting', diet.result);
      final missing = avoRemovalGate('allergies_remove', 'Milch', const [
        'Erdnüsse',
      ], healthShared: true);
      expect(missing.result['error'], isNotNull);
    });

    test('without consent_health the answer is the same for a stored and an '
        'unknown entry (no membership oracle, N5)', () {
      for (final key in ['allergies_remove', 'diet_remove']) {
        final stored = avoRemovalGate(key, 'Erdnüsse', const [
          'Erdnüsse',
        ], healthShared: false);
        final unknown = avoRemovalGate(key, 'Mango', const [
          'Erdnüsse',
        ], healthShared: false);
        expect(stored.result, unknown.result, reason: key);
        expect(stored.card.kind, AvoPayloadKind.consentRequest);
        expect(stored.result['not_shared'], isTrue);
        _expectNoWrite('update_setting', stored.result);
      }
    });

    test('log_food only shows the estimate', () {
      final gate = avoFoodGate(
        food: 'Spaghetti',
        kcal: 650,
        meal: MealType.lunch,
        estimated: true,
        allergies: const ['Gluten'],
      );
      expect(gate.result['saved'], isFalse);
      _expectNoWrite('log_food', gate.result);
      expect((gate.card.card! as AvoEstimateCard).kcal, 650);
    });

    test('add_to_plan on a busy day asks and names every planned recipe', () {
      final day = DateTime(2026, 11, 11);
      MealPlanEntry entry(String id, String name) => MealPlanEntry(
        id: id,
        userId: 'u1',
        planDate: day,
        recipeId: 'r$id',
        snapshot: PlanRecipeSnapshot(
          name: name,
          defaultServings: 2,
          language: 'de',
          ingredients: const [],
        ),
        servings: 2,
        position: 0,
        createdAt: day,
        updatedAt: day,
      );
      final gate = avoPlanDayGate(
        day: day,
        recipeId: 'new',
        recipeName: 'Ofengemüse',
        servings: 2,
        planned: [entry('a', 'Linsencurry'), entry('b', 'Salat')],
      )!;
      final card = gate.card.card! as AvoPlanTakenCard;
      expect(card.plannedNames, ['Linsencurry', 'Salat']);
      expect(card.plannedEntryIds, ['a', 'b']);
      _expectNoWrite('add_to_plan', gate.result);
      expect(
        avoPlanDayGate(
          day: day,
          recipeId: 'new',
          recipeName: 'Ofengemüse',
          servings: 2,
          planned: const [],
        ),
        isNull,
      );
    });
  });
}
