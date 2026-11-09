// Layout matrix for Avo's answer cards of Kap. 5.2–5.7 and the photo cards
// of Kap. 7 (B5 slice W1b): widths 320–440, text 1.0–3.1, bold, dark,
// contrast. Fails on any overflow, cut text or small tap target.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/models/workout.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../../screens/avo/avo_fakes.dart';
import '../../layout_matrix.dart';

/// One conversation with its own fake backend, built once per case.
class _Case extends StatefulWidget {
  const _Case({this.payloads = const [], this.photo = false});

  final List<AvoWidgetPayload> payloads;
  final bool photo;

  @override
  State<_Case> createState() => _CaseState();
}

class _CaseState extends State<_Case> {
  late final FakeAvoBackend _backend = FakeAvoBackend([
    AvoScript(payloads: widget.payloads),
  ]);

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: avoCardOverrides(backend: _backend),
    child: AvoToastHost(
      child: AvoRounds(
        questions: const ['Was gibt es Neues bei Wocheneinkauf und Kalorien?'],
        photo: widget.photo ? kTinyPng : null,
      ),
    ),
  );
}

Recipe _recipe(String id) => Recipe(
  id: id,
  name: 'Ofengemüse mit Feta, Kichererbsen und Zitronen-Joghurt',
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 4,
  ingredients: const [],
  instructions: const [],
  authorId: 'a',
  authorName: 'A',
  createdAt: DateTime(2026),
  nutrition: const NutritionInfo(calories: 520),
);

final _offer = StoreOffer(
  id: 7,
  productName: 'Frische Vollmilch 3,5 % Fett aus der Region',
  brandName: 'Milbona',
  description: '',
  price: 0.99,
  oldPrice: 1.15,
  unitShortName: 'l',
  retailerName: 'Lidl',
  retailerUniqueName: 'lidl',
  categoryName: null,
  validFrom: DateTime(2026, 11, 9),
  validTo: DateTime(2026, 11, 14),
  volume: 1,
);

Future<AvoUndoResult> _undo() async => AvoUndoResult.undone;

final _records = [
  AvoWidgetPayload.record(
    const AvoItemsRecord(
      tool: 'add_recipe_to_list',
      source: AvoItemsSource.recipe,
      listId: 'w',
      listName: 'Wocheneinkauf für das lange Wochenende',
      added: 9,
      alreadyOn: ['Zwiebeln', 'Olivenöl extra vergine'],
      servings: 4,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoWaterRecord(
      tool: 'log_water',
      amountMl: 250,
      totalMl: 1250,
      targetMl: 2000,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    AvoWeightRecord(
      tool: 'log_weight',
      kg: 78.4,
      day: DateTime(2026, 11, 7),
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoWorkoutRecord(
      tool: 'log_workout',
      type: WorkoutType.strength,
      minutes: 45,
      kcal: 310,
      estimated: true,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoFoodRecord(
      tool: 'log_food',
      name: 'Spaghetti Bolognese mit Parmesan',
      meal: MealType.lunch,
      kcal: 650,
      leftKcal: -120,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoGoalRecord(
      tool: 'setup_nutrition_goal',
      kcal: 1800,
      previousKcal: 2000,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoSettingRecord(
      tool: 'update_setting',
      key: 'theme_mode',
      value: 'dark',
      previous: 'system',
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoSettingRecord(
      tool: 'update_setting',
      key: 'allergies_add',
      value: 'Erdnüsse',
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    const AvoModuleRecord(
      tool: 'set_module',
      module: AppModule.calories,
      enabled: true,
      undo: _undo,
    ),
  ),
  AvoWidgetPayload.record(
    AvoSplitRecord(
      tool: 'split_trip_cost',
      tripDate: DateTime(2026, 10, 31),
      shares: const [
        (name: 'Lena-Marie', amount: 21.4, isYou: false),
        (name: 'Jannis', amount: 21.4, isYou: true),
      ],
    ),
  ),
];

final _reads = [
  AvoWidgetPayload.card(
    AvoTripsCard(
      [
        ShoppingHistory(
          id: 't1',
          userId: 'u1',
          listName: 'Wocheneinkauf für das lange Wochenende',
          totalItems: 14,
          completedAt: DateTime(2026, 10, 31),
          totalCost: 42.8,
          items: const [
            ShoppingHistoryItem(id: 'h', historyId: 't1', name: 'Milch'),
          ],
        ),
      ],
      listId: 'w',
      listName: 'Wocheneinkauf',
    ),
  ),
  AvoWidgetPayload.card(
    const AvoRestockCard(
      [
        (name: 'Hafermilch ungesüßt', everyDays: 6, quantity: 1, category: null),
        (name: 'Eier', everyDays: 9, quantity: 10, category: null),
      ],
      listId: 'w',
      listName: 'Wocheneinkauf',
    ),
  ),
  AvoWidgetPayload.card(
    AvoRecipesCard(
      [_recipe('a'), _recipe('b')],
      allergensHidden: true,
      query: 'Feta',
    ),
  ),
  AvoWidgetPayload.card(
    const AvoRecipeNutritionCard(
      recipeName: 'Ofengemüse mit Feta',
      kcal: 520,
      proteinG: 24,
      carbsG: 48,
      fatG: 26,
      estimated: true,
    ),
  ),
  AvoWidgetPayload.card(
    AvoPlanCard(
      from: DateTime(2026, 11, 9),
      days: 7,
      lines: [
        (
          entryId: 'e',
          day: DateTime(2026, 11, 11),
          recipeId: 'r',
          name: 'Linsencurry mit Spinat und Kokosmilch',
          servings: 2,
          imageUrl: null,
          kcal: 610,
        ),
      ],
    ),
  ),
  AvoWidgetPayload.card(
    AvoPlanTakenCard(
      day: DateTime(2026, 11, 11),
      recipeId: 'r',
      recipeName: 'Ofengemüse',
      servings: 2,
      plannedNames: const ['Linsencurry mit Spinat', 'Gurkensalat'],
      plannedEntryIds: const ['e'],
    ),
  ),
];

final _offers = [
  AvoWidgetPayload.card(
    AvoOfferSearchCard(
      storeName: 'Lidl',
      offers: [_offer],
      query: 'Milch',
      zip: '80331',
      listId: 'w',
    ),
  ),
  AvoWidgetPayload.card(const AvoOfferSetupCard.region()),
  AvoWidgetPayload.card(
    const AvoOfferSetupCard.store(
      listId: 'w',
      listName: 'Wocheneinkauf für das lange Wochenende',
    ),
  ),
  AvoWidgetPayload.card(
    AvoDealsCard(
      listId: 'w',
      listName: 'Wocheneinkauf',
      summary: const OfferSummary(
        chainId: 'lidl',
        storeName: 'Lidl',
        matched: 4,
        total: 11,
        savingsCents: 320,
      ),
      offers: [(item: 'Milch', offer: _offer)],
    ),
  ),
  AvoWidgetPayload.card(
    AvoSavingsCard(month: DateTime(2026, 11), trips: 6, savedCents: 1240),
  ),
];

final _health = [
  AvoWidgetPayload.card(
    const AvoNutritionStatusCard(consumedKcal: 2120, goalKcal: 2000),
  ),
  AvoWidgetPayload.card(
    AvoWeekCard(
      days: [for (var i = 0; i < 7; i++) DateTime(2026, 11, 3 + i)],
      kcalByDay: {
        for (var i = 0; i < 7; i++) DateTime(2026, 11, 3 + i): 1600 + 50 * i,
      },
      averageKcal: 1750,
      goalKcal: 2000,
    ),
  ),
  AvoWidgetPayload.card(
    const AvoChallengesCard([
      (
        type: ChallengeType.fasting16_8,
        title: null,
        day: 12,
        totalDays: null,
        checkedInToday: true,
      ),
    ]),
  ),
  AvoWidgetPayload.card(
    AvoGoalPreviewCard(
      goal: NutritionGoal(
        userId: 'u1',
        dailyCalorieTarget: 1800,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      previous: NutritionGoal(
        userId: 'u1',
        dailyCalorieTarget: 2000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ),
  ),
  AvoWidgetPayload.card(
    const AvoEstimateCard(
      name: 'Spaghetti Bolognese mit Parmesan und Basilikum',
      kcal: 650,
      proteinG: 28,
      carbsG: 72,
      fatG: 24,
      confidence: 'low',
      meal: MealType.breakfast,
      grams: 400,
      allergens: ['Gluten', 'Milchprodukte'],
    ),
  ),
];

final _settingsAndPhoto = [
  AvoWidgetPayload.card(const AvoRemovalCard('Erdnüsse')),
  AvoWidgetPayload.card(const AvoRemovalCard('Vegetarisch', diet: true)),
  AvoWidgetPayload.card(const AvoSettingFailedCard('zip_code')),
  AvoWidgetPayload.card(const AvoAppInfoCard(isPro: true)),
  AvoWidgetPayload.confirmDelete(
    AvoPendingDeletes().propose(
      target: AvoDeleteTarget.historyTrip,
      targetId: 't1',
      name: 'Wocheneinkauf',
      date: DateTime(2026, 10, 31),
    ),
  ),
  AvoWidgetPayload.card(
    AvoListImportCard(
      items: [
        ExtractedListItem(name: 'Hafermilch ungesüßt', quantity: 2, unit: 'l'),
        ExtractedListItem(name: 'Eier', quantity: 10),
      ],
      unreadable: const ['unleserliche Zeile'],
    ),
  ),
  AvoWidgetPayload.card(
    const AvoPhotoErrorCard(code: 'unreadable_image', meal: false),
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix(
    'Avo cards: records with undo',
    (_) => _Case(payloads: _records),
    scrollable: true,
    checkTapTargets: true,
    // The cards are really there (not an empty frame).
    afterPump: (tester) async {
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Undo'), findsNWidgets(9));
    },
  );

  layoutMatrix(
    'Avo cards: history, recipes, meal plan',
    (_) => _Case(payloads: _reads),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo cards: offers',
    (_) => _Case(payloads: _offers),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo cards: calories and health, estimate',
    (_) => _Case(payloads: _health),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo cards: settings, confirm, photo note and error',
    (_) => _Case(payloads: _settingsAndPhoto),
    scrollable: true,
    checkTapTargets: true,
  );

  layoutMatrix(
    'Avo photo bubble and its choice',
    (_) => const _Case(photo: true),
    scrollable: true,
    checkTapTargets: true,
    afterPump: (tester) async {
      expect(find.text('What should I do with this photo?'), findsOneWidget);
    },
  );
}
