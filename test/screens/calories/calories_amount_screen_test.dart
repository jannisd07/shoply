// S7 "Menge" of docs/redesign/b-screens/kalorien.md: product header, the
// amount with stepper and unit chips, numbers live, meal and day, "Nährwerte
// fehlen" (typed in per 100 g and remembered), deep links, logging.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_amount_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

const _code = '4056489123453';

CalorieAmountFood _skyr({double? servingG, double? packageG, int? kcal = 63}) => CalorieAmountFood.fromProduct(
      offProduct(_code, 'Skyr Natur', brand: 'Milbona', kcal: kcal, servingG: servingG, packageG: packageG),
      origin: FoodEntryOrigin.barcode,
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesAmountScreen)));

void main() {
  testWidgets('product, amount 100 g by default, numbers follow the stepper and the field', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, CaloriesAmountScreen(foodId: _code, food: _skyr()), overrides: env.overrides());
    await settleFrames(tester);

    expect(find.text('Amount'), findsWidgets);
    expect(find.text('Skyr Natur'), findsOneWidget);
    expect(find.text('Milbona'), findsOneWidget);
    expect(find.text('63 kcal per 100 g'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^63 calories, 11 grams of Protein')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Increase'));
    await settleFrames(tester);
    expect(find.bySemanticsLabel(RegExp(r'^69 calories')), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Amount').last).value, isNotEmpty);

    await tester.enterText(find.byKey(const ValueKey('cal-amount-field')), '250');
    await settleFrames(tester);
    expect(find.bySemanticsLabel(RegExp(r'^158 calories, 28 grams of Protein')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('serving and pack become chips; a serving starts at one', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, CaloriesAmountScreen(foodId: _code, food: _skyr(servingG: 150, packageG: 500)),
        overrides: env.overrides());
    await settleFrames(tester);

    expect(find.text('g'), findsWidgets);
    expect(find.text('Serving · 150 g'), findsOneWidget);
    expect(find.text('Pack · 500 g'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^95 calories')), findsOneWidget, reason: '150 g × 63 kcal / 100 g');

    await tester.ensureVisible(find.text('Pack · 500 g').last);
    await settleFrames(tester);
    await tester.tap(find.text('Pack · 500 g').last);
    await settleFrames(tester);
    expect(find.bySemanticsLabel(RegExp(r'^315 calories')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an invalid amount says so under the field; "Log" is off', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, CaloriesAmountScreen(foodId: _code, food: _skyr()), overrides: env.overrides());
    await settleFrames(tester);

    await tester.enterText(find.byKey(const ValueKey('cal-amount-field')), '0');
    await settleFrames(tester);
    expect(find.text('Enter a number, for example 450 or 450.5'), findsOneWidget);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(_container(tester).read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);
  });

  testWidgets('"Log" saves the grams for the chosen meal and closes with undo', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(
      tester,
      CaloriesAmountScreen(foodId: _code, food: _skyr(), meal: MealType.breakfast),
      overrides: env.overrides(),
    );
    await settleFrames(tester);
    final container = _container(tester);

    await tester.enterText(find.byKey(const ValueKey('cal-amount-field')), '250');
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);

    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.foodName, 'Skyr Natur');
    expect(entry.brand, 'Milbona');
    expect(entry.quantity, 250);
    expect(entry.unit, 'g');
    expect(entry.calories, 158);
    expect(entry.proteinG, closeTo(27.5, 0.01));
    expect(entry.origin, FoodEntryOrigin.barcode);
    expect(entry.barcode, _code);
    expect(entry.mealType, MealType.breakfast);
    expect(find.byType(CaloriesAmountScreen), findsNothing);
    expect(find.text('Skyr Natur logged'), findsOneWidget);
  });

  testWidgets('no nutrition: per 100 g from the pack; "Log" waits for kcal; the values are remembered', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, CaloriesAmountScreen(foodId: _code, food: _skyr(kcal: null)), overrides: env.overrides());
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('This product has no nutrition data. Enter it from the pack (per 100 g).'), findsOneWidget);
    expect(find.text('NUTRITION PER 100 G'), findsOneWidget);
    expect(find.text('We\'ll remember these values next time.'), findsOneWidget);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);

    await tester.enterText(find.byType(EditableText).at(0), '80');
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider(kToday)).day!.entries.single.calories, 80);
    expect(container.read(calorieProductCacheProvider).products[_code]!.caloriesPer100g, 80);
    expect(container.read(userFoodsProvider).single.barcode, _code);
  });

  testWidgets('a deep link without the product looks it up; an unknown code offers manual entry', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(
      tester,
      const CaloriesAmountScreen(foodId: _code),
      overrides: env.overrides(offProducts: {_code: offProduct(_code, 'Skyr Natur')}),
    );
    await settleFrames(tester);
    expect(find.text('Skyr Natur'), findsOneWidget);

    final other = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAmountScreen(foodId: '4000000000099'), overrides: other.overrides());
    await settleFrames(tester);
    expect(find.text('Nothing is known about this barcode.'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);
  });

  testWidgets('an earlier entry in servings steps in halves and logs servings', (tester) async {
    final env = await CalorieTestEnv.create();
    final earlier = food('r1', 'Ofengemüse', 520, quantity: 1, unit: 'serving');
    await pumpCalories(
      tester,
      CaloriesAmountScreen(foodId: 'recent:r1', food: CalorieAmountFood.fromEntry(earlier)),
      overrides: env.overrides(),
    );
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('1 serving · 520 kcal'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Increase').first);
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.quantity, 1.5);
    expect(entry.unit, 'serving');
    expect(entry.calories, 780);
  });
}
