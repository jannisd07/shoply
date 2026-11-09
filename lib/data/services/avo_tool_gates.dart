import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_consents.dart';

// The owner's hard rules for writes the model may ask for, as pure
// decisions (W1b review M10): what a tool call shows and answers when only
// the person's tap may write. The service calls these and never writes on
// these paths; tests check that the answer is a card and "nothing saved".

/// What a gated tool call answers: the card it shows and its result for
/// the model (always without a write).
typedef AvoGate = ({AvoWidgetPayload card, Map<String, Object?> result});

/// `update_setting` with `allergies_remove` (Kap. 6.5) or `diet_remove`:
/// the removal card with the entry as the person stored it; only its tap
/// removes. Without the consent "Ernährung und Allergien" ([healthShared])
/// the answer is the same whether the entry is stored or not (no way to
/// probe the allergies) and the consent card shows; nothing is removed.
AvoGate avoRemovalGate(
  String key,
  Object? value,
  List<String> stored, {
  required bool healthShared,
}) {
  if (!healthShared) {
    return (
      card: AvoWidgetPayload.consentRequest(AvoConsentKind.health),
      result: {
        'success': false,
        'not_shared': true,
        'note':
            'The person has not shared diet and allergies with Avo, so '
            'nothing was looked up or changed. The app shows a card to share '
            'them; ask them to tap it, then ask again.',
      },
    );
  }
  final diet = key == 'diet_remove';
  final wanted = value?.toString().trim().toLowerCase() ?? '';
  final match = stored
      .where((a) => a.trim().toLowerCase() == wanted)
      .firstOrNull;
  if (match == null) {
    return (
      card: AvoWidgetPayload.card(AvoSettingFailedCard(key)),
      result: {
        'success': false,
        'error': diet
            ? 'That is not one of the saved diets.'
            : 'That is not one of the saved allergies.',
      },
    );
  }
  return (
    card: AvoWidgetPayload.card(AvoRemovalCard(match, diet: diet)),
    result: {
      'success': false,
      'requires_confirmation': true,
      'note':
          'The app shows a card to confirm. The entry stays until the '
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
AvoGate avoGoalGate(
  NutritionGoal goal, {
  NutritionGoal? previous,
  bool todayHasWeight = true,
}) {
  final had = previous != null && previous.isConfigured;
  // The tap enters the weight for today only where there is none yet; the
  // card says so.
  final writesWeight = goal.currentWeightKg != null && !todayHasWeight;
  return (
    card: AvoWidgetPayload.card(
      AvoGoalPreviewCard(
        goal: goal,
        previous: had ? previous : null,
        writesWeight: writesWeight,
      ),
    ),
    result: {
      'requires_confirmation': true,
      'shown_preview': true,
      'goal_type': goal.goalType.dbValue,
      'daily_calorie_target': goal.dailyCalorieTarget,
      if (had) 'replaces_daily_calorie_target': previous.dailyCalorieTarget,
      if (writesWeight) 'would_log_weight_today': true,
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

/// Whether [share] is the payer's own: the person's share when they paid,
/// else the share named like the trip's payer. "Teilen" saves exactly these
/// as paid (`ExpenseSplitService.createSplits` decides by the share's user
/// id, which `avoSplitTrip` sets to the payer's), so the card's footnote
/// and the saved split agree for every payer (W1b re-review 2, I-1).
bool avoIsPayersShare(
  AvoShare share, {
  required bool payerIsYou,
  required String? payerName,
}) => share.isYou
    ? payerIsYou
    : !payerIsYou && payerName != null && share.name == payerName;

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
  // The trip's payer stays; a trip without one gets the person as payer.
  final payerIsNew = trip.paidByUserId == null && trip.paidByName == null;
  final payerIsYou =
      payerIsNew || (yourUserId != null && trip.paidByUserId == yourUserId);
  final payerName = payerIsNew ? yourName : trip.paidByName;
  // A name the model wrote differently ("lena") becomes the payer's own, so
  // the card and the saved share use the same name.
  String named(String n) =>
      !payerIsYou &&
          payerName != null &&
          n.toLowerCase() == payerName.trim().toLowerCase()
      ? payerName
      : n;
  final shares = <AvoShare>[
    (name: yourName, amount: yours, isYou: true),
    for (final n in names) (name: named(n), amount: share, isYou: false),
  ];
  // Exactly the shares "Teilen" makes again as paid ([avoIsPayersShare]);
  // every other share paid now is reset, and the card says so.
  final paidAgain = {
    for (final s in shares)
      if (avoIsPayersShare(s, payerIsYou: payerIsYou, payerName: payerName))
        s.name,
  };
  final card = AvoSplitPreviewCard(
    historyId: trip.id,
    tripDate: trip.completedAt,
    total: total,
    totalFromTrip: fromTrip,
    yourUserId: yourUserId,
    payerUserId: payerIsNew ? yourUserId : trip.paidByUserId,
    payerName: payerName,
    payerIsYou: payerIsYou,
    payerIsNew: payerIsNew,
    shares: shares,
    replaces: [
      for (final s in existing) (name: s.participantName, paid: s.isPaid),
    ],
    paidReset: [
      for (final s in existing)
        if (s.isPaid && !paidAgain.contains(s.participantName))
          s.participantName,
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
        'paid_by_you': payerIsYou,
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
