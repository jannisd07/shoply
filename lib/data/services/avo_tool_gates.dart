import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';

// The owner's hard rules for writes the model may ask for, as pure
// decisions (W1b review M10): what a tool call shows and answers when only
// the person's tap may write. The service calls these and never writes on
// these paths; tests check that the answer is a card and "nothing saved".

/// What a gated tool call answers: the card it shows and its result for
/// the model (always without a write).
typedef AvoGate = ({AvoWidgetPayload card, Map<String, Object?> result});

/// `update_setting` with `allergies_remove` (Kap. 6.5): the safety card
/// with the entry as the person stored it; null when it is no allergy of
/// theirs (the result then says so). Never removes anything.
AvoGate? avoAllergyRemovalGate(Object? value, List<String> stored) {
  final wanted = value?.toString().trim().toLowerCase() ?? '';
  final match = stored
      .where((a) => a.trim().toLowerCase() == wanted)
      .firstOrNull;
  if (match == null) return null;
  return (
    card: AvoWidgetPayload.card(AvoAllergyCard(match)),
    result: {
      'success': false,
      'requires_confirmation': true,
      'note':
          'The app shows a card to confirm. The allergy stays until the '
          'person taps Remove on it.',
    },
  );
}

/// `log_food` (Kap. 5.6, 7.2): the estimate card; nothing is saved until
/// "Eintragen". [allergies] are the person's own, matched on the device.
AvoGate avoFoodGate({
  required String food,
  required int kcal,
  required MealType meal,
  required bool estimated,
  double? proteinG,
  double? carbsG,
  double? fatG,
  String? portion,
  List<String> allergies = const [],
}) => (
  card: AvoWidgetPayload.card(
    AvoEstimateCard(
      name: food,
      kcal: kcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      estimated: estimated,
      meal: meal,
      portion: portion,
      allergens: _allergensIn(allergies, food),
    ),
  ),
  result: {
    'saved': false,
    'shown_estimate': true,
    'food': food,
    'meal': meal.dbValue,
    'calories': kcal,
    'estimated': estimated,
    'note':
        'Nothing is saved yet: the app shows the estimate and the person '
        'taps Eintragen to log it. Do not say it was logged.',
  },
);

/// `setup_nutrition_goal` with every field known (Kap. 5.6): always the
/// preview with "Übernehmen", for a first goal too and whatever
/// `confirm_replace` says. [previous] is the goal in place now (for
/// "bisher"); the tap reads it again.
AvoGate avoGoalGate(NutritionGoal goal, {NutritionGoal? previous}) {
  final had = previous != null && previous.isConfigured;
  return (
    card: AvoWidgetPayload.card(
      AvoGoalPreviewCard(goal: goal, previous: had ? previous : null),
    ),
    result: {
      'requires_confirmation': true,
      'shown_preview': true,
      'goal_type': goal.goalType.dbValue,
      'daily_calorie_target': goal.dailyCalorieTarget,
      if (had) 'replaces_daily_calorie_target': previous.dailyCalorieTarget,
      'note':
          'Nothing is saved yet: the app shows the new goal with a button '
          '"Übernehmen"; only the person\'s tap saves it. Calling again, also '
          'with confirm_replace, only shows the same preview. Say it is a '
          'guide value, not medical advice.',
    },
  );
}

/// `add_to_plan` on a day with recipes (Kap. 5.4): "Dazulegen / Ersetzen";
/// null when the day is free (then the tool plans right away, with undo).
AvoGate? avoPlanDayGate({
  required DateTime day,
  required String recipeId,
  required String recipeName,
  required int servings,
  required List<MealPlanEntry> planned,
}) {
  if (planned.isEmpty) return null;
  return (
    card: AvoWidgetPayload.card(
      AvoPlanTakenCard(
        day: day,
        recipeId: recipeId,
        recipeName: recipeName,
        servings: servings,
        plannedNames: [for (final e in planned) e.snapshot.name],
        plannedEntryIds: [for (final e in planned) e.id],
      ),
    ),
    result: {
      'asked': true,
      'already_planned': [for (final e in planned) e.snapshot.name],
      'note':
          'The day has recipes already. The app asks whether to add it '
          'alongside or replace them; nothing is planned until the person '
          'taps.',
    },
  );
}

/// `split_trip_cost` (Kap. 5.2): the split as a preview; only "Teilen"
/// saves it. The trip's own total always wins over the model's
/// [modelTotal] (contract: a total only for a trip without one). Existing
/// splits are named on the card ([existing]), with who has paid. Without a
/// total or other people the plan holds only an error for the model.
AvoSplitPlan avoSplitGate({
  required ShoppingHistory trip,
  required List<String> others,
  required String yourName,
  required String? yourUserId,
  required List<ExpenseSplit> existing,
  double? modelTotal,
}) {
  final tripTotal = trip.totalCost;
  final fromTrip = tripTotal != null && tripTotal > 0;
  final total = fromTrip ? tripTotal : modelTotal;
  if (total == null || total <= 0) {
    return (
      gate: null,
      error: {
        'error':
            'This trip has no known total yet. Ask the person for the '
            'total in euros and call split_trip_cost again with total_cost.',
      },
    );
  }
  final names = [
    for (final n in others)
      if (n.trim().isNotEmpty) n.trim(),
  ];
  if (names.isEmpty) {
    return (
      gate: null,
      error: {'error': 'participant_names must name at least one other person'},
    );
  }
  final share = double.parse((total / (names.length + 1)).toStringAsFixed(2));
  // The payer's share takes the cent remainder, so the shares add up.
  final yours = double.parse((total - share * names.length).toStringAsFixed(2));
  final card = AvoSplitPreviewCard(
    historyId: trip.id,
    tripDate: trip.completedAt,
    total: total,
    totalFromTrip: fromTrip,
    yourUserId: yourUserId,
    shares: [
      (name: yourName, amount: yours, isYou: true),
      for (final n in names) (name: n, amount: share, isYou: false),
    ],
    replaces: [
      for (final s in existing) (name: s.participantName, paid: s.isPaid),
    ],
  );
  return (
    gate: (
      card: AvoWidgetPayload.card(card),
      result: {
        'requires_confirmation': true,
        'shown_preview': true,
        'trip': trip.listName,
        'total_cost': total,
        'total_from_trip': fromTrip,
        'each_share': share,
        'participants': [yourName, ...names],
        if (existing.isNotEmpty) 'replaces_existing_split': true,
        'note':
            'Nothing is split yet: the app shows the split and only the '
            'person\'s tap on Teilen saves it.'
            '${fromTrip && modelTotal != null && modelTotal != tripTotal ? ' The trip already has a total; that one is used.' : ''}',
      },
    ),
    error: null,
  );
}

/// [avoSplitGate]'s answer: the gate, or the error for the model.
typedef AvoSplitPlan = ({AvoGate? gate, Map<String, Object?>? error});

/// The person's allergies [text] names (on the device, a hint only).
List<String> _allergensIn(List<String> allergies, String text) =>
    allergies.isEmpty
    ? const []
    : [for (final m in AllergenMatcher(allergies).matches(text)) m.allergy];
