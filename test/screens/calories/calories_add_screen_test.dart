// S3 "Essen eintragen" of docs/redesign/b-screens/kalorien.md (the parts
// whose follow-up screens exist: meal menu, date line, "Zuletzt gegessen",
// search in the history).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';

import 'calorie_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesAddScreen)));

final _history = [
  food('h1', 'Haferflocken', 220, quantity: 60, unit: 'g', date: '2026-11-06', created: DateTime(2026, 11, 6, 8)),
  food('h2', 'Haferflocken', 220, quantity: 60, unit: 'g', date: '2026-11-05', created: DateTime(2026, 11, 5, 8)),
  food('h3', 'Skyr Natur', 130, quantity: 250, unit: 'g', brand: 'Milbona', date: '2026-11-06',
      created: DateTime(2026, 11, 6, 15)),
  food('h4', 'Apfel', 80, date: '2026-11-04', created: DateTime(2026, 11, 4, 10)),
];

void main() {
  testWidgets('title is the meal of the time of day; the menu changes it', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.bySemanticsLabel('Log Lunch'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Log Lunch')).hint, 'Change meal');
    expect(find.byWidgetPredicate((w) => w is AppSegmentedControl), findsNothing);

    await tester.tap(find.bySemanticsLabel('Log Lunch'));
    await settle(tester);
    await tester.tap(find.text('Dinner'));
    await settle(tester);
    expect(find.bySemanticsLabel('Log Dinner'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('"Zuletzt gegessen" lists each food once, recent and frequent mixed', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.text('RECENTLY EATEN'), findsOneWidget);
    expect(find.text('Haferflocken'), findsOneWidget);
    expect(find.text('60 g · 220 kcal'), findsOneWidget);
    expect(find.text('250 g · 130 kcal'), findsOneWidget);
    expect(find.text('80 kcal'), findsOneWidget);
  });

  testWidgets('one tap logs it for the chosen meal: check, "Logged", undo; the screen stays', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.breakfast),
        overrides: env.overrides(recent: _history));
    await settle(tester);

    final row = find.bySemanticsLabel('Haferflocken, 60 g, 220 calories');
    expect(tester.getSemantics(row).hint, 'Log Haferflocken');
    await tester.tap(row);
    await settle(tester);

    expect(find.text('Logged'), findsOneWidget);
    expect(find.text('Haferflocken logged'), findsOneWidget);
    final day = containerOf(tester).read(calorieDayProvider(kToday)).day!;
    final logged = day.entries.single;
    expect(logged.foodName, 'Haferflocken');
    expect(logged.mealType, MealType.breakfast);
    expect(logged.calories, 220);
    expect(find.byType(CaloriesAddScreen), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(containerOf(tester).read(calorieDayProvider(kToday)).day!.entries, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Logged'), findsNothing);
    semantics.dispose();
  });

  testWidgets('another day: "For Thu, Nov 5" and logging goes to that day', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(dateKey: '2026-11-05'),
        overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.text('For Thu, Nov 5'), findsOneWidget);
    await tester.tap(find.text('Apfel'));
    await settle(tester);
    final day = containerOf(tester).read(calorieDayProvider('2026-11-05')).day!;
    expect(day.entries.map((e) => e.foodName), contains('Apfel'));
  });

  testWidgets('left open over midnight: a tap logs for the new day', (tester) async {
    var now = DateTime(2026, 11, 7, 23, 58);
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.snack),
        overrides: env.overrides(recent: _history, clock: () => now));
    await settle(tester);

    now = DateTime(2026, 11, 8, 0, 3);
    await tester.tap(find.text('Apfel'));
    await settle(tester);
    final c = containerOf(tester);
    expect(c.read(calorieDayProvider('2026-11-08')).day!.entries.single.foodName, 'Apfel');
    expect(c.read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);
  });

  testWidgets('the history fails to load: says so with retry, never the first-run note', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(),
        overrides: env.overrides(recentError: StateError('server')));
    await settle(tester);

    expect(find.text('Couldn\'t load what you ate recently.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Foods you eat often will show up here. One tap logs them.'), findsNothing);
  });

  testWidgets('a picked day starts loading at once', (tester) async {
    final env = await CalorieTestEnv.create(server: {'2026-11-05': usualDay(date: '2026-11-05')});
    await pumpCalories(tester, const CaloriesAddScreen(dateKey: '2026-11-05'), overrides: env.overrides());
    await settle(tester);
    expect(containerOf(tester).read(calorieDayProvider('2026-11-05')).day!.entries, hasLength(3));
  });

  testWidgets('search filters the history by name and brand; nothing found says so', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    await tester.enterText(find.byType(EditableText), 'milb');
    await settle(tester);
    expect(find.text('Skyr Natur'), findsOneWidget);
    expect(find.text('Haferflocken'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'Pizza');
    await settle(tester);
    expect(find.text('Nothing found for “Pizza”.'), findsOneWidget);
  });

  testWidgets('first start without history: the footnote explains what will show', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Foods you eat often will show up here. One tap logs them.'), findsOneWidget);
  });

  testWidgets('long press removes a food from "Zuletzt" and remembers it', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    await tester.longPress(find.text('Apfel'));
    await settle(tester);
    await tester.tap(find.text('Remove from recent'));
    await settle(tester);
    expect(find.text('Apfel'), findsNothing);
    expect(env.prefs.getStringList('cal_recent_hidden_v1_$kUser'), contains('apfel|'));
  });

  testWidgets('offline: the stored history still shows, the status row says so', (tester) async {
    final env = await CalorieTestEnv.create(extraPrefs: {
      'cal_recent_v1_$kUser': jsonEncode([for (final e in _history) e.toJson()]),
    });
    await pumpCalories(
      tester,
      const CaloriesAddScreen(),
      overrides: env.overrides(offline: true, recentError: StateError('offline')),
    );
    await settle(tester);

    expect(find.text('You\'re offline. Only your own and recent foods are shown.'), findsOneWidget);
    expect(find.text('Skyr Natur'), findsOneWidget);
  });

  testWidgets('close returns to where it was opened', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Close'));
    await settle(tester);
    expect(find.byType(CaloriesAddScreen), findsNothing);
  });

  test('ranking: newest, most often, second newest …, each food once, hidden ones out', () {
    final ranked = rankRecentFoods([
      food('a', 'Apfel', 80, created: DateTime(2026, 11, 7, 9)),
      food('b', 'Brot', 200, created: DateTime(2026, 11, 1)),
      food('c', 'Brot', 200, created: DateTime(2026, 11, 2)),
      food('d', 'Brot', 200, created: DateTime(2026, 11, 3)),
      food('e', 'Ei', 90, created: DateTime(2026, 11, 6)),
      food('f', 'Kaffee', 5, created: DateTime(2026, 11, 5)),
    ], hidden: {'kaffee|'});
    expect(ranked.map((r) => r.template.foodName), ['Apfel', 'Brot', 'Ei']);
    expect(ranked[1].count, 3);
    expect(ranked[1].template.id, 'd');
  });
}
