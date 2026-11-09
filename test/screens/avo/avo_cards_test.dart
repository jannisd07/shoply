// Avo's answer cards of Kap. 5.2–5.7 (B5, slice W1b): what each card says,
// its states, "Widerrufen" and the taps that write only on the person's
// tap (estimate, goal, allergy, planned day, restock, trip).
import 'package:flutter/cupertino.dart';
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
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

import 'avo_fakes.dart';

Recipe _recipe(String id, String name, {int? kcal}) => Recipe(
  id: id,
  name: name,
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients: const [],
  instructions: const [],
  authorId: 'a',
  authorName: 'A',
  createdAt: DateTime(2026),
  nutrition: kcal == null ? null : NutritionInfo(calories: kcal),
);

ShoppingHistory _trip(String id, {double? cost}) => ShoppingHistory(
  id: id,
  userId: 'u1',
  listName: 'Wocheneinkauf',
  totalItems: 2,
  completedAt: DateTime(2026, 10, 31, 11),
  totalCost: cost,
  items: [
    ShoppingHistoryItem(id: 'h1', historyId: id, name: 'Milch', quantity: 1),
    ShoppingHistoryItem(id: 'h2', historyId: id, name: 'Brot', quantity: 1),
  ],
);

StoreOffer _offer({double? old}) => StoreOffer(
  id: 7,
  productName: 'Frische Vollmilch 3,5 %',
  brandName: 'Milbona',
  description: '',
  price: 0.99,
  oldPrice: old,
  unitShortName: 'l',
  retailerName: 'Lidl',
  retailerUniqueName: 'lidl',
  categoryName: null,
  validFrom: DateTime(2026, 11, 9),
  validTo: DateTime(2026, 11, 14),
  volume: 1,
);

Future<FakeAvoBackend> _pump(
  WidgetTester tester,
  List<AvoWidgetPayload> payloads, {
  Set<AppModule>? modules,
  bool offers = true,
  bool offline = false,
  String message = '',
}) async {
  final backend = FakeAvoBackend([
    AvoScript(payloads: payloads, message: message),
  ]);
  await tester.pumpWidget(
    avoHarness(
      const SingleChildScrollView(child: AvoRounds()),
      avoCardOverrides(
        backend: backend,
        modules:
            modules ??
            const {
              AppModule.offers,
              AppModule.calories,
              AppModule.mealPlan,
              AppModule.costSplit,
            },
        offers: offers,
        offline: offline,
      ),
    ),
  );
  await settle(tester);
  return backend;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('records (writes with "Widerrufen")', () {
    testWidgets('recipe on a list: the object, what happened, undo', (
      tester,
    ) async {
      final backend = FakeAvoBackend();
      var undone = 0;
      await _pump(tester, [
        AvoWidgetPayload.record(
          AvoItemsRecord(
            tool: 'add_recipe_to_list',
            source: AvoItemsSource.recipe,
            listId: 'w',
            listName: 'Wocheneinkauf',
            added: 9,
            alreadyOn: const ['Zwiebeln', 'Olivenöl'],
            servings: 4,
            undo: () async {
              undone++;
              return AvoUndoResult.undone;
            },
          ),
        ),
      ]);
      expect(backend.asked, isEmpty);
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(
        find.text(
          '9 ingredients added · for 4 servings · 2 already on it: '
          'Zwiebeln, Olivenöl',
        ),
        findsOneWidget,
      );
      expect(find.text('Open list'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(undone, 1);
      expect(find.text('Undone'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('water, weight, workout, goal, module and split', (
      tester,
    ) async {
      await _pump(tester, [
        AvoWidgetPayload.record(
          AvoWaterRecord(
            tool: 'log_water',
            amountMl: 250,
            totalMl: 1250,
            targetMl: 2000,
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          AvoWeightRecord(
            tool: 'log_weight',
            kg: 78.4,
            day: DateTime(2026, 11, 7),
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          AvoWorkoutRecord(
            tool: 'log_workout',
            type: WorkoutType.running,
            minutes: 30,
            kcal: 310,
            estimated: true,
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          AvoGoalRecord(
            tool: 'setup_nutrition_goal',
            kcal: 1800,
            previousKcal: 2000,
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          AvoModuleRecord(
            tool: 'set_module',
            module: AppModule.calories,
            enabled: true,
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          AvoSplitRecord(
            tool: 'split_trip_cost',
            tripDate: DateTime(2026, 10, 31),
            shares: const [
              (name: 'Lena', amount: 21.4, isYou: false),
              (name: 'Jannis', amount: 21.4, isYou: true),
            ],
          ),
        ),
      ]);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('250 ml logged · 1.25 of 2 l today'), findsOneWidget);
      expect(find.text('78.4 kg logged · Sat, Nov 7'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(
        find.text('30 min logged · about 310 kcal, estimated'),
        findsOneWidget,
      );
      expect(find.text('Goal set: 1,800 kcal a day'), findsOneWidget);
      expect(
        find.text('was 2,000 · guide value, not medical advice'),
        findsOneWidget,
      );
      expect(find.textContaining('turned on'), findsOneWidget);
      expect(find.text('Trip on Sat, Oct 31'), findsOneWidget);
      expect(find.text('Split: Lena €21.40 · you €21.40'), findsOneWidget);
      // Five undos: the split cannot be taken back (L9).
      expect(find.text('Undo'), findsNWidgets(5));
    });

    testWidgets('settings in the person\'s words, allergy added', (
      tester,
    ) async {
      await _pump(tester, [
        AvoWidgetPayload.record(
          AvoSettingRecord(
            tool: 'update_setting',
            key: 'theme_mode',
            value: 'dark',
            previous: 'system',
            undo: () async => AvoUndoResult.undone,
          ),
        ),
        AvoWidgetPayload.record(
          const AvoSettingRecord(
            tool: 'update_setting',
            key: 'allergies_add',
            value: 'Erdnuss',
          ),
        ),
      ]);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Dark, was System'), findsOneWidget);
      expect(find.text('Allergies'), findsOneWidget);
      expect(
        find.text('Erdnuss added · recipes with Erdnuss will be flagged'),
        findsOneWidget,
      );
    });

    testWidgets('A8 settings name themselves, on/off and times read like '
        'the settings pages, unknown keys fall back', (tester) async {
      await _pump(tester, [
        AvoWidgetPayload.record(
          const AvoSettingRecord(
            tool: 'update_setting',
            key: 'show_item_images',
            value: 'off',
            previous: 'on',
          ),
        ),
        AvoWidgetPayload.record(
          const AvoSettingRecord(
            tool: 'update_setting',
            key: 'start_list',
            value: 'last used list',
            previous: 'Wocheneinkauf',
          ),
        ),
        AvoWidgetPayload.record(
          const AvoSettingRecord(
            tool: 'update_setting',
            key: 'notif_time_dinner',
            value: '18:30',
            previous: '18:00',
          ),
        ),
        AvoWidgetPayload.record(
          const AvoSettingRecord(
            tool: 'update_setting',
            key: 'something_new',
            value: 'x',
            previous: 'y',
          ),
        ),
      ]);
      expect(find.text('Show item pictures'), findsOneWidget);
      expect(find.text('off, was on'), findsOneWidget);
      expect(find.text('List at start'), findsOneWidget);
      expect(find.text('Last used list, was Wocheneinkauf'), findsOneWidget);
      expect(find.text('Dinner ideas: time'), findsOneWidget);
      expect(find.text('6:30 PM, was 6:00 PM'), findsOneWidget);
      expect(find.text('Setting'), findsOneWidget);
    });
  });

  group('§5.2 history and restocking', () {
    testWidgets('trips: date, items, amount only when recorded; all back '
        'on the list with its own undo', (tester) async {
      final backend = await _pump(tester, [
        AvoWidgetPayload.card(
          AvoTripsCard(
            [_trip('t1', cost: 42.8), _trip('t2')],
            listId: 'w',
            listName: 'Wocheneinkauf',
          ),
        ),
      ]);
      expect(find.text('Shopping trips'), findsOneWidget);
      expect(find.text('Sat, Oct 31 · 2 items · €42.80'), findsOneWidget);
      expect(find.text('Sat, Oct 31 · 2 items'), findsOneWidget);
      // A tap unfolds a trip's items.
      await tester.tap(find.text('Sat, Oct 31 · 2 items'));
      await settle(tester);
      expect(find.text('Milch, Brot'), findsOneWidget);

      await tester.tap(find.text('All back on Wocheneinkauf'));
      await settle(tester);
      expect(backend.cardWrites, ['items:w:Milch,Brot']);
      expect(find.text('2 added'), findsOneWidget);
      expect(find.text('All back on Wocheneinkauf'), findsNothing);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Undone'), findsOneWidget);
      expect(backend.recordUndos, 1);
    });

    testWidgets('a split is only a preview until "Teilen"; it names what it '
        'replaces and who had paid (I1)', (tester) async {
      final card = AvoWidgetPayload.card(
        AvoSplitPreviewCard(
          historyId: 't1',
          tripDate: DateTime(2026, 10, 31),
          total: 42.8,
          totalFromTrip: true,
          yourUserId: 'u1',
          shares: const [
            (name: 'Jannis', amount: 21.4, isYou: true),
            (name: 'Lena', amount: 21.4, isYou: false),
          ],
          replaces: const [(name: 'Lena', paid: true)],
          paidReset: const ['Lena'],
        ),
      );
      final backend = FakeAvoBackend([
        AvoScript(payloads: [card]),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(
        find.text('Split: you €21.40 · Lena €21.40 · total €42.80 · You paid'),
        findsOneWidget,
      );
      expect(
        find.text('Replaces the earlier split. "Paid" for Lena will be reset.'),
        findsOneWidget,
      );
      expect(backend.cardWrites, isEmpty, reason: 'nothing before the tap');
      await tester.tap(find.text('Split'));
      await settle(tester);
      expect(backend.cardWrites, ['split:t1:42.8']);
      expect(find.text('Split: you €21.40 · Lena €21.40'), findsOneWidget);
      expect(find.text('Undo'), findsNothing, reason: 'no way back yet (L9)');
    });

    testWidgets('a split card that is out of date says so and offers nothing', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              AvoSplitPreviewCard(
                historyId: 't1',
                tripDate: DateTime(2026, 10, 31),
                total: 30,
                totalFromTrip: false,
                yourUserId: 'u1',
                shares: const [
                  (name: 'J', amount: 15, isYou: true),
                  (name: 'Lena', amount: 15, isYou: false),
                ],
              ),
            ),
          ],
        ),
      ])..splitStale = true;
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.textContaining('as you said'), findsOneWidget);
      await tester.tap(find.text('Split'));
      await settle(tester);
      expect(find.text('This request has expired. Ask again.'), findsOneWidget);
      expect(find.text('Split'), findsNothing);
    });

    testWidgets('no trips yet', (tester) async {
      await _pump(tester, [AvoWidgetPayload.card(const AvoTripsCard([]))]);
      expect(find.text('No shopping trips saved yet.'), findsOneWidget);
    });

    testWidgets('restock: a tap puts it on the list and the row becomes its '
        'result with undo', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              const AvoRestockCard(
                [(name: 'Milch', everyDays: 6, quantity: 2, category: null)],
                listId: 'w',
                listName: 'Wocheneinkauf',
              ),
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.text('Maybe also'), findsOneWidget);
      expect(find.text('you buy it about every 6 days'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Milch, you buy it about every 6 days'),
        findsOneWidget,
      );
      await tester.tap(find.text('Milch'));
      await settle(tester);
      expect(backend.added, ['w:Milch']);
      expect(find.text('1 added · Wocheneinkauf'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Undone'), findsOneWidget);
    });
  });

  group('§5.3 recipes', () {
    testWidgets('three rows at most, kcal only with the calories module, '
        'the allergen note and "Mehr Rezepte"', (tester) async {
      final card = AvoWidgetPayload.card(
        AvoRecipesCard(
          [for (var i = 0; i < 4; i++) _recipe('r$i', 'Rezept $i', kcal: 520)],
          allergensHidden: true,
          query: 'Feta',
        ),
      );
      await _pump(tester, [card]);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Rezept 2'), findsOneWidget);
      expect(find.text('Rezept 3'), findsNothing);
      expect(find.text('35 min · 2 servings · 520 kcal'), findsNWidgets(3));
      expect(
        find.text('Recipes with your allergens are hidden.'),
        findsOneWidget,
      );
      expect(find.text('More recipes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, [card], modules: const {AppModule.offers});
      expect(find.text('35 min · 2 servings'), findsNWidgets(3));
    });

    testWidgets('none found, none saved', (tester) async {
      await _pump(tester, [
        AvoWidgetPayload.card(const AvoRecipesCard([])),
        AvoWidgetPayload.card(const AvoRecipesCard([], saved: true)),
      ]);
      expect(find.text("I couldn't find a recipe for that."), findsOneWidget);
      expect(find.text('No saved recipes yet.'), findsOneWidget);
    });

    testWidgets('nutrition per serving, estimated', (tester) async {
      await _pump(tester, [
        AvoWidgetPayload.card(
          const AvoRecipeNutritionCard(
            recipeName: 'Ofengemüse',
            kcal: 520,
            proteinG: 24,
            carbsG: 48,
            fatG: 26,
            estimated: true,
          ),
        ),
      ]);
      expect(find.text('520'), findsOneWidget);
      expect(find.text('24 g'), findsOneWidget);
      expect(find.text('per serving, estimated'), findsOneWidget);
    });
  });

  group('§5.4 meal plan', () {
    testWidgets('today and nothing planned', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await _pump(tester, [
        AvoWidgetPayload.card(
          AvoPlanCard(
            from: today,
            days: 1,
            lines: [
              (
                entryId: 'e',
                day: today,
                recipeId: 'r',
                name: 'Ofengemüse mit Feta',
                servings: 2,
                imageUrl: null,
                kcal: null,
              ),
            ],
          ),
        ),
        AvoWidgetPayload.card(
          AvoPlanCard(from: today, days: 1, lines: const []),
        ),
      ]);
      expect(find.text('Today: Ofengemüse mit Feta'), findsOneWidget);
      expect(find.text('Nothing planned for today.'), findsOneWidget);
    });

    testWidgets('kcal in plan rows only with the calories module (M4)', (
      tester,
    ) async {
      final card = AvoWidgetPayload.card(
        AvoPlanCard(
          from: DateTime(2026, 11, 9),
          days: 7,
          lines: [
            (
              entryId: 'e',
              day: DateTime(2026, 11, 11),
              recipeId: 'r',
              name: 'Linsencurry',
              servings: 2,
              imageUrl: null,
              kcal: 610,
            ),
          ],
        ),
      );
      await _pump(tester, [card]);
      expect(find.text('Wed, Nov 11 · 2 servings · 610 kcal'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, [card], modules: const {AppModule.mealPlan});
      expect(find.text('Wed, Nov 11 · 2 servings'), findsOneWidget);
    });

    testWidgets('a day that has a recipe asks first; "Ersetzen" plans with '
        'undo', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              AvoPlanTakenCard(
                day: DateTime(2026, 11, 11),
                recipeId: 'r',
                recipeName: 'Ofengemüse',
                servings: 2,
                plannedNames: const ['Linsencurry'],
                plannedEntryIds: const ['e1'],
              ),
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(
        find.text('Linsencurry is already planned for Wednesday.'),
        findsOneWidget,
      );
      expect(backend.cardWrites, isEmpty, reason: 'nothing planned yet');
      await tester.tap(find.text('Replace'));
      await settle(tester);
      expect(backend.cardWrites, ['plan:Ofengemüse:replace']);
      expect(find.text('Ofengemüse · 2 servings'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('§5.5 offers', () {
    testWidgets('search: the market, "laut Händler", the region, plus to '
        'add; nothing at all while offers are off', (tester) async {
      final card = AvoWidgetPayload.card(
        AvoOfferSearchCard(
          storeName: 'Lidl',
          offers: [_offer(old: 1.15)],
          query: 'Milch',
          zip: '80331',
          listId: 'w',
        ),
      );
      await _pump(tester, [card]);
      expect(find.text('Lidl, this week'), findsOneWidget);
      expect(
        find.textContaining('was €1.15, as stated by the retailer'),
        findsOneWidget,
      );
      expect(find.textContaining('in your area (80331)'), findsOneWidget);
      expect(find.bySemanticsLabel('Add Milch'), findsOneWidget);
      // No percentage discount (the 3,5 % is the milk's fat).
      expect(find.textContaining(RegExp(r'-\s?\d+\s?%')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, [card], offers: false);
      expect(find.text('Lidl, this week'), findsNothing);
    });

    testWidgets('no region, no market', (tester) async {
      await _pump(tester, [
        AvoWidgetPayload.card(const AvoOfferSetupCard.region()),
        AvoWidgetPayload.card(
          const AvoOfferSetupCard.store(listId: 'w', listName: 'Wocheneinkauf'),
        ),
      ]);
      expect(
        find.text('Set your postcode to see offers in your area'),
        findsOneWidget,
      );
      expect(find.text('Wocheneinkauf has no store yet.'), findsOneWidget);
      expect(find.text('Choose store'), findsOneWidget);
    });

    testWidgets('deals in the mandatory wording; savings rounded or none', (
      tester,
    ) async {
      await _pump(tester, [
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
            offers: [(item: 'Milch', offer: _offer())],
          ),
        ),
        AvoWidgetPayload.card(
          AvoSavingsCard(month: DateTime(2026, 11), trips: 6, savedCents: 1240),
        ),
        AvoWidgetPayload.card(
          AvoSavingsCard(month: DateTime(2026, 10), trips: 2),
        ),
      ]);
      expect(
        find.text('4 of 11 items on offer at Lidl this week'),
        findsOneWidget,
      );
      expect(find.textContaining('about €3.20 saved'), findsOneWidget);
      expect(
        find.text('November: about €12.40 saved through offers'),
        findsOneWidget,
      );
      expect(find.text('according to the retailer · 6 trips'), findsOneWidget);
      expect(find.text('No savings recorded for October.'), findsOneWidget);
    });
  });

  group('§5.6 calories and health', () {
    testWidgets('left and over the goal (symbol and words, never colour '
        'alone); week; challenges', (tester) async {
      final days = [for (var i = 0; i < 7; i++) DateTime(2026, 11, 3 + i)];
      await _pump(tester, [
        AvoWidgetPayload.card(
          const AvoNutritionStatusCard(consumedKcal: 1360, goalKcal: 2000),
        ),
        AvoWidgetPayload.card(
          const AvoNutritionStatusCard(consumedKcal: 2120, goalKcal: 2000),
        ),
        AvoWidgetPayload.card(
          AvoWeekCard(
            days: days,
            kcalByDay: {for (final d in days) d: 1840},
            averageKcal: 1840,
            goalKcal: 2000,
          ),
        ),
        AvoWidgetPayload.card(
          const AvoChallengesCard([
            (
              type: ChallengeType.noSugar30,
              title: null,
              day: 4,
              totalDays: 30,
              checkedInToday: true,
            ),
          ]),
        ),
      ]);
      expect(find.text('640 kcal left'), findsOneWidget);
      expect(find.text('1,360 of 2,000 kcal today'), findsOneWidget);
      expect(find.text('120 kcal over'), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_triangle),
        findsOneWidget,
      );
      expect(
        find.text('This week you averaged 1,840 kcal, goal 2,000.'),
        findsOneWidget,
      );
      expect(find.text('30 days without sugar'), findsOneWidget);
      expect(find.text('Day 4 of 30 · checked in today'), findsOneWidget);
    });

    testWidgets('a goal preview saves only on "Übernehmen"', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              AvoGoalPreviewCard(
                writesWeight: true,
                goal: NutritionGoal(
                  userId: 'u1',
                  dailyCalorieTarget: 1800,
                  proteinTargetG: 120,
                  currentWeightKg: 80,
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
          ],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.text('New goal: 1,800 kcal a day'), findsOneWidget);
      expect(
        find.text('was 2,000 · guide value, not medical advice'),
        findsOneWidget,
      );
      // Every field that changes is named (N3).
      expect(
        find.text('Per day: protein 120 g · carbs – g · fat – g'),
        findsOneWidget,
      );
      expect(find.text("Also logs 80 kg as today's weight"), findsOneWidget);
      expect(backend.cardWrites, isEmpty);
      await tester.tap(find.text('Use this goal'));
      await settle(tester);
      expect(backend.cardWrites, ['goal:1800']);
      expect(find.text('Goal set: 1,800 kcal a day'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('an estimate is never saved before "Eintragen"; meal and '
        'portions change in place; the allergen gets a warning line', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              const AvoEstimateCard(
                name: 'Spaghetti Bolognese',
                kcal: 650,
                proteinG: 28,
                carbsG: 72,
                fatG: 24,
                confidence: 'high',
                meal: MealType.dinner,
                grams: 400,
                allergens: ['Gluten'],
              ),
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.text('Spaghetti Bolognese'), findsOneWidget);
      expect(
        find.text('about 650 kcal · estimated, fairly sure'),
        findsOneWidget,
      );
      expect(
        find.text('Estimated. Guide values, not medical advice.'),
        findsOneWidget,
      );
      expect(
        find.text(
          "Probably contains Gluten. You've listed Gluten as an allergy.",
        ),
        findsOneWidget,
      );
      expect(find.byType(AppButton), findsWidgets);
      expect(backend.cardWrites, isEmpty);

      // Lunch instead of dinner, two portions.
      await tester.tap(find.text('Dinner'));
      await settle(tester);
      await tester.tap(find.text('Lunch').last);
      await settle(tester);
      final stepper = find.byType(ValueStepper);
      tester.widget<ValueStepper>(stepper).onChanged(2);
      await settle(tester);
      expect(
        find.text('about 1,300 kcal · estimated, fairly sure'),
        findsOneWidget,
      );

      await tester.tap(find.text('Log'));
      await settle(tester);
      expect(backend.cardWrites, ['food:Spaghetti Bolognese:lunch:2']);
      expect(find.text('Spaghetti Bolognese logged'), findsOneWidget);
      expect(find.text('Lunch · 1,300 kcal · 640 kcal left'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('§5.7 settings', () {
    testWidgets('removing an allergy only from the safety card', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [AvoWidgetPayload.card(const AvoRemovalCard('Erdnuss'))],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.text('Remove Erdnuss from your allergies?'), findsOneWidget);
      expect(
        find.text('Recipes with Erdnuss will no longer be flagged.'),
        findsOneWidget,
      );
      expect(backend.cardWrites, isEmpty);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(backend.cardWrites, ['allergy:Erdnuss']);
      expect(find.text('Erdnuss removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('removing a diet entry goes through its own confirm card', (
      tester,
    ) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [
            AvoWidgetPayload.card(
              const AvoRemovalCard('Vegetarisch', diet: true),
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      expect(find.text('Remove Vegetarisch from your diet?'), findsOneWidget);
      expect(backend.cardWrites, isEmpty);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(backend.cardWrites, ['diet:Vegetarisch']);
      expect(find.text('Vegetarisch removed'), findsOneWidget);
    });

    testWidgets('cancel keeps it', (tester) async {
      final backend = FakeAvoBackend([
        AvoScript(
          payloads: [AvoWidgetPayload.card(const AvoRemovalCard('Erdnuss'))],
        ),
      ]);
      await tester.pumpWidget(
        avoHarness(
          const SingleChildScrollView(child: AvoRounds()),
          avoCardOverrides(backend: backend),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Not removed.'), findsOneWidget);
      expect(backend.cardWrites, isEmpty);
    });

    testWidgets('a plan entry and a past trip have their own confirm texts', (
      tester,
    ) async {
      final deletes = AvoPendingDeletes();
      await _pump(tester, [
        AvoWidgetPayload.confirmDelete(
          deletes.propose(
            target: AvoDeleteTarget.planEntry,
            targetId: 'e1',
            name: 'Linsencurry',
            date: DateTime(2026, 11, 11),
          ),
        ),
        AvoWidgetPayload.confirmDelete(
          deletes.propose(
            target: AvoDeleteTarget.historyTrip,
            targetId: 't1',
            name: 'Wocheneinkauf',
            date: DateTime(2026, 10, 31),
          ),
        ),
      ]);
      expect(
        find.text('Remove Linsencurry on Wed, Nov 11 from the plan?'),
        findsOneWidget,
      );
      expect(find.text('The ingredients stay on your lists.'), findsOneWidget);
      expect(find.text('Delete the trip on Sat, Oct 31?'), findsOneWidget);
    });
  });

  group('after the answer (Kap. 2.13, 5.7)', () {
    Future<void> ask(
      WidgetTester tester,
      List<AvoWidgetPayload> payloads,
    ) async {
      final backend = FakeAvoBackend([AvoScript(payloads: payloads)]);
      await tester.pumpWidget(
        avoHarness(const AvoTabScreen(), avoCardOverrides(backend: backend)),
      );
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'Frage');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
    }

    testWidgets('Avo switching itself off waits for the end of the answer, '
        'then the global toast offers "Widerrufen"', (tester) async {
      var applied = 0;
      await ask(tester, [
        AvoWidgetPayload.record(
          AvoModuleRecord(
            tool: 'set_module',
            module: AppModule.avo,
            enabled: false,
            applyAfterAnswer: () async => applied++,
          ),
        ),
      ]);
      expect(applied, 1);
      expect(find.text('Avo turned off'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('the meal plan on a list: the figure celebrates for a while', (
      tester,
    ) async {
      await ask(tester, [
        AvoWidgetPayload.record(
          const AvoItemsRecord(
            tool: 'plan_to_list',
            source: AvoItemsSource.plan,
            listId: 'w',
            listName: 'Wocheneinkauf',
            added: 17,
          ),
        ),
      ]);
      expect(find.text('17 ingredients added'), findsOneWidget);
      expect(
        tester.widget<AvoFigure>(find.byType(AvoFigure)).pose,
        AvoPose.celebrating,
      );
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(
        tester.widget<AvoFigure>(find.byType(AvoFigure)).pose,
        AvoPose.waving,
      );
    });

    testWidgets('money and health never celebrate', (tester) async {
      await ask(tester, [
        AvoWidgetPayload.record(
          AvoSplitRecord(
            tool: 'split_trip_cost',
            tripDate: DateTime(2026, 10, 31),
            shares: const [(name: 'Lena', amount: 10, isYou: false)],
          ),
        ),
      ]);
      expect(
        tester.widget<AvoFigure>(find.byType(AvoFigure)).pose,
        AvoPose.waving,
      );
    });
  });
}
