// S8 "Manuell eintragen" of docs/redesign/b-screens/kalorien.md: name and
// kcal, "Kalorien schätzen lassen" (online, with a name, AI on), optional
// macros and amount, the discard question, and the own food it leaves.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/presentation/screens/calories/calories_manual_screen.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesManualScreen)));

/// The field after the label [label] (fields are found in order).
Finder _field(int index) => find.byType(EditableText).at(index);

void main() {
  testWidgets('the name comes along; "Log" waits for a valid kcal number', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(name: 'Käsebrötchen'), overrides: env.overrides());
    await settleFrames(tester);

    expect(find.text('Enter manually'), findsOneWidget);
    expect(find.text('Käsebrötchen'), findsOneWidget);
    await tester.enterText(_field(1), '4,5,6');
    await settleFrames(tester);
    expect(find.text('Enter a number, for example 450 or 450.5'), findsOneWidget);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(_container(tester).read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);

    await tester.enterText(_field(1), '310');
    await settleFrames(tester);
    expect(find.text('Enter a number, for example 450 or 450.5'), findsNothing);
    final container = _container(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.foodName, 'Käsebrötchen');
    expect(entry.calories, 310);
    expect(entry.origin, FoodEntryOrigin.manual);
    expect(entry.estimated, isFalse);
    expect(entry.proteinG, isNull, reason: 'empty macros do not count');
  });

  testWidgets('"Estimate calories" fills the fields; the entry stays "geschätzt"', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(name: 'Käsebrötchen', meal: MealType.breakfast),
        overrides: env.overrides());
    await settleFrames(tester);
    final container = _container(tester);

    await tester.tap(find.text('Estimate calories'));
    await settleFrames(tester);
    expect(find.text('320'), findsOneWidget);
    expect(find.text('estimated, please check'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.origin, FoodEntryOrigin.manualEstimated);
    expect(entry.estimated, isTrue);
    expect(entry.confidence, EstimateConfidence.medium);
    expect(entry.proteinG, 14);
    expect(entry.mealType, MealType.breakfast);
  });

  testWidgets('a changed estimate is the person\'s own number', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(name: 'Käsebrötchen'), overrides: env.overrides());
    await settleFrames(tester);
    final container = _container(tester);

    await tester.tap(find.text('Estimate calories'));
    await settleFrames(tester);
    await tester.enterText(_field(1), '400');
    await settleFrames(tester);
    expect(find.text('estimated, please check'), findsNothing);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.origin, FoodEntryOrigin.manual);
    expect(entry.estimated, isFalse);
  });

  testWidgets('no estimate offline, with the AI off or without a name', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(name: 'Brot'), overrides: env.overrides(offline: true));
    await settleFrames(tester);
    expect(find.text('Estimate calories'), findsNothing);

    await pumpCalories(tester, const CaloriesManualScreen(name: 'Brot'), overrides: env.overrides(ai: false));
    await settleFrames(tester);
    expect(find.text('Estimate calories'), findsNothing);

    await pumpCalories(tester, const CaloriesManualScreen(), overrides: env.overrides());
    await settleFrames(tester);
    expect(find.text('Estimate calories'), findsNothing);
  });

  testWidgets('a failed estimate says so with retry', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(
      tester,
      const CaloriesManualScreen(name: 'Brot'),
      overrides: env.overrides(estimator: (String text, {int? servings}) async => throw const ClaudeException('timeout')),
    );
    await settleFrames(tester);

    await tester.tap(find.text('Estimate calories'));
    await settleFrames(tester);
    expect(find.text('The estimate didn\'t work.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('with grams and a barcode the food becomes an own food', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(name: 'Hafer-Riegel', barcode: '4000000000099'),
        overrides: env.overrides());
    await settleFrames(tester);
    final container = _container(tester);

    await tester.enterText(_field(1), '180');
    await tester.enterText(_field(5), '45');
    await settleFrames(tester);
    await tester.ensureVisible(find.text('g').last);
    await tester.tap(find.text('g').last);
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);

    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.quantity, 45);
    expect(entry.unit, 'g');
    expect(entry.barcode, '4000000000099');
    final own = container.read(userFoodsProvider).single;
    expect(own.name, 'Hafer-Riegel');
    expect(own.barcode, '4000000000099');
    expect(own.kcal100, closeTo(400, 0.01));
  });

  testWidgets('leaving with input asks first; "Keep editing" stays, "Discard" leaves', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesManualScreen(), overrides: env.overrides());
    await settleFrames(tester);

    await tester.enterText(_field(0), 'Suppe');
    await settleFrames(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await settleFrames(tester);
    expect(find.text('Discard your input?'), findsOneWidget);
    expect(find.text('The food won\'t be logged.'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settleFrames(tester);
    expect(find.byType(CaloriesManualScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await settleFrames(tester);
    await tester.tap(find.text('Discard'));
    await settleFrames(tester);
    expect(find.byType(CaloriesManualScreen), findsNothing);
  });
}
