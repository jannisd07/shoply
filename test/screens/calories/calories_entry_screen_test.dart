// S9 "Eintrag bearbeiten" of docs/redesign/b-screens/kalorien.md: the name
// as the large title, amount with stepper (numbers follow), meal, day, time,
// nutrients, the source, "Eintrag löschen" (at once, undo), saving when the
// screen is left ("Eintrag geändert · Widerrufen"), and closing without a
// word when the entry is gone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_entry_screen.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesEntryScreen)));

Future<ProviderContainer> _pump(WidgetTester tester, CalorieTestEnv env, String id, {String date = kToday}) async {
  await pumpCalories(tester, CaloriesEntryScreen(entryId: id, dateKey: date), overrides: env.overrides());
  await settleFrames(tester);
  return _container(tester);
}

Future<CalorieTestEnv> _env({CalorieDay? day}) {
  final d = day ?? usualDay();
  return CalorieTestEnv.create(stored: {d.dateKey: d}, server: {d.dateKey: d});
}

void main() {
  testWidgets('the name is the title; fields, the source and "Delete entry"', (tester) async {
    final env = await _env();
    final semantics = tester.ensureSemantics();
    await _pump(tester, env, 'e1');

    expect(find.text('Haferflocken'), findsWidgets);
    expect(tester.getSemantics(find.text('Haferflocken').first), isSemantics(isHeader: true));
    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('220'), findsOneWidget);
    expect(find.text('Entered by you'), findsOneWidget);
    expect(find.text('Delete entry'), findsOneWidget);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Delete entry')).hint, 'Deletes at once; you can undo it afterwards.');
    semantics.dispose();
  });

  testWidgets('more grams: kcal follow; leaving saves with "Entry changed · Undo"', (tester) async {
    final env = await _env();
    final semantics = tester.ensureSemantics();
    final container = await _pump(tester, env, 'e1');

    await tester.tap(find.bySemanticsLabel('Increase'));
    await settleFrames(tester);
    expect(find.text('70'), findsOneWidget);
    expect(find.text('257'), findsOneWidget, reason: '220 kcal × 70 / 60');

    await tester.tap(find.bySemanticsLabel('Back'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEntryScreen), findsNothing);
    expect(find.text('Entry changed'), findsOneWidget);
    final saved = container.read(calorieDayProvider(kToday)).day!.entries.firstWhere((e) => e.id == 'e1');
    expect(saved.quantity, 70);
    expect(saved.calories, 257);

    await tester.tap(find.text('Undo'));
    await settleFrames(tester);
    final back = container.read(calorieDayProvider(kToday)).day!.entries.firstWhere((e) => e.id == 'e1');
    expect(back.quantity, 60);
    expect(back.calories, 220);
    semantics.dispose();
  });

  testWidgets('no change: leaving saves nothing and says nothing', (tester) async {
    final env = await _env();
    await _pump(tester, env, 'e1');
    await tester.tap(find.bySemanticsLabel('Back'));
    await settleFrames(tester);
    expect(find.text('Entry changed'), findsNothing);
    expect(env.remote.executed, isEmpty);
  });

  testWidgets('another meal from the menu is saved on leaving', (tester) async {
    final env = await _env();
    final container = await _pump(tester, env, 'e1');

    await tester.tap(find.text('Meal'));
    await settleFrames(tester);
    await tester.tap(find.text('Snacks').last);
    await settleFrames(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.firstWhere((e) => e.id == 'e1').mealType, MealType.snack);
  });

  testWidgets('"Delete entry" deletes at once with undo and closes; no dialog', (tester) async {
    final env = await _env();
    final container = await _pump(tester, env, 'e2');

    await tester.ensureVisible(find.text('Delete entry'));
    await tester.tap(find.text('Delete entry'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEntryScreen), findsNothing);
    expect(find.text('Banane deleted'), findsOneWidget);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.map((e) => e.id), isNot(contains('e2')));
    expect(env.remote.executed.where((w) => w.kind == 'food').every((w) => w.entityId == 'e2'), isTrue,
        reason: 'only the delete, never a save of the deleted entry');

    await tester.tap(find.text('Undo'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.map((e) => e.id), contains('e2'));
  });

  testWidgets('an invalid number keeps the screen open', (tester) async {
    final env = await _env();
    await _pump(tester, env, 'e1');

    await tester.enterText(find.byType(EditableText).at(2), '');
    await settleFrames(tester);
    expect(find.text('Enter a number, for example 450 or 450.5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEntryScreen), findsOneWidget);
  });

  testWidgets('deleted on another device: the screen closes without a word', (tester) async {
    final env = await _env();
    final container = await _pump(tester, env, 'e2');

    env.remote.days[kToday] = usualDay().copyWith(entries: usualDay().entries.where((e) => e.id != 'e2').toList());
    await container.read(calorieDayProvider(kToday).notifier).refresh();
    await settleFrames(tester);
    expect(find.byType(CaloriesEntryScreen), findsNothing);
    expect(find.text('Entry changed'), findsNothing);
  });

  testWidgets('a photo estimate names its source and level; edited numbers say "adjusted by you"', (tester) async {
    final photo = FoodLogEntry(
      id: 'p1',
      userId: kUser,
      loggedDate: DateTime(2026, 11, 7),
      mealType: MealType.lunch,
      origin: FoodEntryOrigin.photo,
      foodName: 'Linsen-Dal',
      unit: 'serving',
      calories: 470,
      estimated: true,
      confidence: EstimateConfidence.medium,
      loggedTime: const FoodLogTime(12, 41),
      createdAt: DateTime(2026, 11, 7, 12, 41),
    );
    final env = await _env(day: CalorieDay(dateKey: kToday, entries: [photo]));
    await _pump(tester, env, 'p1');

    // intl puts a narrow no-break space before "PM".
    expect(find.textContaining('Estimated from a photo, Sat, Nov 7, 12:41'), findsOneWidget);
    expect(find.text('Unsure · estimated'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(2), '500');
    await settleFrames(tester);
    expect(find.text('Unsure · estimated, adjusted by you'), findsOneWidget);
  });

  testWidgets('"More": log again today; save as own food (grams, after the migration)', (tester) async {
    const past = '2026-11-05';
    final env = await _env(day: usualDay(date: past));
    final container = await _pump(tester, env, 'e1', date: past);

    await tester.tap(find.bySemanticsLabel('More'));
    await settleFrames(tester);
    expect(find.text('Save as your own food'), findsOneWidget);
    await tester.tap(find.text('Log again today'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.single.foodName, 'Haferflocken');

    await tester.tap(find.bySemanticsLabel('More'));
    await settleFrames(tester);
    await tester.tap(find.text('Save as your own food'));
    await settleFrames(tester);
    expect(container.read(userFoodsProvider).single.name, 'Haferflocken');
    expect(find.text('Saved as your own food'), findsOneWidget);
  });
}
