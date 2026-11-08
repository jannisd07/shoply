// S0 of docs/redesign/b-screens/kalorien.md: "Kalorien heute", "Wasser
// heute" and the evening hint on Home.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_ring.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/home_sections/home_calories.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart' as slots;

import '../screens/calories/calorie_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _home() => ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: const [
        HomeCaloriesToday(),
        SizedBox(height: 24),
        AvoTileGrid(children: [SizedBox(), HomeWaterTile()]),
        SizedBox(height: 24),
        HomeCalorieIdeasHint(),
      ],
    );

void main() {
  // "Today" listens for the return from the background (needs a binding).
  TestWidgetsFlutterBinding.ensureInitialized();
  test('b_slots still exports both sections', () {
    expect(slots.homeCaloriesHasContentProvider, same(homeCaloriesHasContentProvider));
    expect(slots.homeWaterHasContentProvider, same(homeWaterHasContentProvider));
    expect(const slots.HomeCaloriesToday(), isA<HomeCaloriesToday>());
    expect(const slots.HomeWaterTile(), isA<HomeWaterTile>());
  });

  test('module off: no content, decided synchronously', () async {
    final env = await CalorieTestEnv.create();
    final container = ProviderContainer(overrides: env.overrides(module: false));
    addTearDown(container.dispose);
    expect(container.read(homeCaloriesHasContentProvider), isFalse);
    expect(container.read(homeWaterHasContentProvider), isFalse);
    expect(container.read(homeCalorieIdeasHintHasContentProvider), isFalse);
  });

  test('module on and signed in: card and tile have content in the first read', () async {
    final env = await CalorieTestEnv.create();
    final container = ProviderContainer(overrides: env.overrides());
    addTearDown(container.dispose);
    expect(container.read(homeCaloriesHasContentProvider), isTrue);
    expect(container.read(homeWaterHasContentProvider), isTrue);
  });

  testWidgets('module off renders nothing', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()});
    await pumpCalories(tester, _home(), overrides: env.overrides(module: false));
    // Zero-height children count as off screen for finders.
    expect(tester.getSize(find.byType(HomeCaloriesToday, skipOffstage: false)).height, 0);
    expect(find.text('CALORIES', skipOffstage: false), findsNothing);
    expect(find.text('Water today', skipOffstage: false), findsNothing);
  });

  testWidgets('the card: kicker, today, ring with what is left, macros, "Log food", ideas', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()}, storedGoal: goal());
    final semantics = tester.ensureSemantics();
    final visited = await pumpCalories(tester, _home(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('CALORIES'), findsOneWidget);
    expect(find.text('1,360 eaten · goal 2,000'), findsOneWidget);
    expect(find.byType(CalorieRing), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('82 of 133 g'), findsOneWidget);
    final summary = find.bySemanticsLabel(RegExp(r'^Calories today: 640 of 2,000 left, 1,360 eaten\. Protein 82'));
    expect(summary, findsOneWidget);
    expect(tester.getSemantics(summary).hint, 'Opens your diary');
    expect(find.text('What still fits? 6 recipes'), findsOneWidget);

    await tester.tap(find.text('Log food'));
    await settle(tester);
    expect(visited.last, '/calories/add?meal=lunch');
    semantics.dispose();
  });

  testWidgets('tapping the head opens the diary', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, storedGoal: goal());
    final visited = await pumpCalories(tester, _home(), overrides: env.overrides());
    await settle(tester);

    await tester.tap(find.byType(CalorieRing));
    await settle(tester);
    expect(visited.last, '/calories');
  });

  testWidgets('nothing eaten yet: the full budget, never an empty state', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: CalorieDay(dateKey: kToday)}, storedGoal: goal());
    await pumpCalories(tester, _home(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Nothing eaten yet · goal 2,000'), findsOneWidget);
    expect(find.text('0 of 133 g'), findsOneWidget);
  });

  testWidgets('over the goal: how far over, no ideas line', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()});
    await pumpCalories(tester, _home(), overrides: env.overrides(goalValue: goal(kcal: 1240)));
    await settle(tester);

    expect(find.text('kcal over'), findsOneWidget);
    expect(find.textContaining('What still fits?'), findsNothing);
  });

  testWidgets('no goal: the question and "Set a goal", no ring', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()});
    final visited = await pumpCalories(tester, _home(), overrides: env.overrides(goalValue: null));
    await settle(tester);

    expect(find.text('How much do you want to eat each day?'), findsOneWidget);
    expect(find.text('1,360 kcal eaten'), findsOneWidget);
    expect(find.byType(CalorieRing), findsNothing);
    await tester.tap(find.text('Set a goal'));
    await settle(tester);
    expect(visited.last, '/calories/goals/setup?from=empty');
  });

  testWidgets('error without a stored day: one sentence, retry, "Log food" still works', (tester) async {
    final env = await CalorieTestEnv.create();
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, _home(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Couldn\'t load today\'s calories.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Log food'), findsOneWidget);
  });

  testWidgets('first start: placeholders in the card\'s shape, no spinner', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, _home(), overrides: env.overrides(goalLoading: true));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('water tile: litres, drops, the plus adds the quick amount', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()}, storedGoal: goal());
    final semantics = tester.ensureSemantics();
    final visited = await pumpCalories(tester, _home(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('1.25 / 2 L'), findsOneWidget);
    expect(find.bySemanticsLabel('Water today, 1.25 of 2 litres. 5 of 8 glasses.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add 250 ml of water'));
    await settle(tester);
    expect(find.text('1.5 / 2 L'), findsOneWidget);
    expect(find.text('Added 250 ml of water'), findsOneWidget);

    await tester.tap(find.text('Water today'));
    await settle(tester);
    expect(visited.last, '/calories?focus=water');
    semantics.dispose();
  });

  testWidgets('midnight: the card shows the new day and "+250 ml" writes to it', (tester) async {
    var now = DateTime(2026, 11, 7, 23, 59, 30);
    final env = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      server: {kToday: usualDay()},
      storedGoal: goal(),
    );
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, _home(), overrides: env.overrides(clock: () => now));
    await settle(tester);
    expect(find.text('1,360 eaten · goal 2,000'), findsOneWidget);

    // The tap comes after midnight, before any timer ran: it is for today.
    now = DateTime(2026, 11, 8, 0, 0, 10);
    await tester.tap(find.bySemanticsLabel('Add 250 ml of water'));
    await settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeWaterTile)));
    expect(c.read(calorieDayProvider('2026-11-08')).day!.waterMl, 250);
    expect(c.read(calorieDayProvider(kToday)).day!.waterMl, 1250);

    await tester.pump(const Duration(seconds: 30));
    await settle(tester);
    expect(find.text('Nothing eaten yet · goal 2,000'), findsOneWidget);
    expect(find.text('0.25 / 2 L'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the goal fails to load, the day is known: eaten kcal and retry, no "Set a goal"', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()});
    await pumpCalories(tester, _home(), overrides: env.overrides(goalError: true));
    await settle(tester);

    expect(find.text('1,360 kcal eaten'), findsOneWidget);
    expect(find.text('Couldn\'t load your goal.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Set a goal'), findsNothing);
    expect(find.text('How much do you want to eat each day?'), findsNothing);
    expect(find.text('Log food'), findsOneWidget);
  });

  testWidgets('back online: the card loads by itself', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, _home(), overrides: env.overrides(offline: true));
    await settle(tester);
    expect(find.text('Couldn\'t load today\'s calories.'), findsOneWidget);

    env.remote.fetchError = null;
    ProviderScope.containerOf(tester.element(find.byType(HomeCaloriesToday)))
        .read(testOfflineProvider.notifier)
        .state = false;
    await settle(tester);
    expect(find.text('1,360 eaten · goal 2,000'), findsOneWidget);
  });

  test('evening hint: from 16 to 21 o\'clock with a goal, kcal left and stored ideas', () async {
    final ideas = jsonEncode({'date': kToday, 'count': 4});
    final env = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      storedGoal: goal(),
      extraPrefs: {'cal_ideas_v1_$kUser': ideas},
    );
    final evening = ProviderContainer(overrides: env.overrides(now: DateTime(2026, 11, 7, 18)));
    addTearDown(evening.dispose);
    expect(evening.read(homeCalorieIdeasHintHasContentProvider), isTrue);

    final noon = ProviderContainer(overrides: env.overrides(now: DateTime(2026, 11, 7, 12)));
    addTearDown(noon.dispose);
    expect(noon.read(homeCalorieIdeasHintHasContentProvider), isFalse);

    final hidden = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      storedGoal: goal(),
      extraPrefs: {'cal_ideas_v1_$kUser': ideas, 'cal_hint_hidden_v1_$kUser': kToday},
    );
    final dismissed = ProviderContainer(overrides: hidden.overrides(now: DateTime(2026, 11, 7, 18)));
    addTearDown(dismissed.dispose);
    expect(dismissed.read(homeCalorieIdeasHintHasContentProvider), isFalse);
  });

  testWidgets('evening hint appears at 16:00 while Home stays open', (tester) async {
    var now = DateTime(2026, 11, 7, 15, 59, 30);
    final env = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      server: {kToday: usualDay()},
      storedGoal: goal(),
      extraPrefs: {'cal_ideas_v1_$kUser': jsonEncode({'date': kToday, 'count': 4})},
    );
    await pumpCalories(tester, _home(), overrides: env.overrides(clock: () => now));
    await settle(tester);
    expect(find.text('640 kcal left today. Dinner ideas', skipOffstage: false), findsNothing);

    now = DateTime(2026, 11, 7, 16, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    await settle(tester);
    expect(find.text('640 kcal left today. Dinner ideas', skipOffstage: false), findsOneWidget);
  });

  testWidgets('evening hint: text with what is left, "Hide for today" removes it', (tester) async {
    final env = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      server: {kToday: usualDay()},
      storedGoal: goal(),
      extraPrefs: {'cal_ideas_v1_$kUser': jsonEncode({'date': kToday, 'count': 4})},
    );
    await pumpCalories(tester, _home(), overrides: env.overrides(now: DateTime(2026, 11, 7, 18)));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('640 kcal left today. Dinner ideas'), 200);

    expect(find.text('640 kcal left today. Dinner ideas'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Hide for today'));
    await settle(tester);
    expect(find.text('640 kcal left today. Dinner ideas'), findsNothing);
    expect(env.prefs.getString('cal_hint_hidden_v1_$kUser'), kToday);
  });
}
