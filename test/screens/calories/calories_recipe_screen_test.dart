// S10 "Rezept ins Tagebuch" of docs/redesign/b-screens/kalorien.md: opens
// over the recipe and closes back to it, servings in halves, meal and day
// (the plan day, today when it lies ahead), "ohne Nährwerte" (estimate
// online, a field offline), deep links.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/calories/calories_recipe_screen.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

Recipe _recipe({NutritionInfo? nutrition = const NutritionInfo(calories: 420, proteinG: 12, carbsG: 50, fatG: 14)}) => Recipe(
      id: 'r1',
      name: 'Ofengemüse mit Feta',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 30,
      defaultServings: 2,
      ingredients: const [],
      instructions: const [],
      authorId: 'a',
      authorName: 'Avo',
      createdAt: DateTime(2026, 11, 1),
      nutrition: nutrition,
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesRecipeScreen)));

void main() {
  testWidgets('from the recipe: "Log" saves the servings and closes back to the recipe', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(), initial: '/recipes');
    router.push('/calories/add/recipe/r1', extra: _recipe());
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('Add to diary'), findsOneWidget);
    expect(find.text('420 kcal per serving'), findsOneWidget);
    expect(find.text('For the amount chosen, from the recipe.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Increase'));
    await settleFrames(tester);
    expect(find.text('1.5'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.origin, FoodEntryOrigin.recipe);
    expect(entry.sourceRecipeId, 'r1');
    expect(entry.quantity, 1.5);
    expect(entry.unit, 'serving');
    expect(entry.calories, 630);
    expect(entry.proteinG, 18);
    expect(find.text('Rezepte'), findsOneWidget);
    expect(find.text('Ofengemüse mit Feta logged'), findsOneWidget);
  });

  testWidgets('a plan day ahead: logged today, with a footnote', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(), initial: '/recipes');
    router.push('/calories/add/recipe/r1?date=2026-11-09&meal=dinner&servings=2', extra: _recipe());
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('Planned for Mon, Nov 9. You can log it from that day.'), findsOneWidget);
    expect(find.bySemanticsLabel('Servings'), findsWidgets);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.mealType, MealType.dinner);
    expect(entry.calories, 840);
  });

  testWidgets('a past plan day is the day logged to', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(), initial: '/recipes');
    router.push('/calories/add/recipe/r1?date=2026-11-05', extra: _recipe());
    await settleFrames(tester);
    final container = _container(tester);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(container.read(calorieDayProvider('2026-11-05')).day!.entries.single.foodName, 'Ofengemüse mit Feta');
  });

  testWidgets('no nutrition, online: "Estimate calories"; the entry is "geschätzt"', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(), initial: '/recipes');
    router.push('/calories/add/recipe/r1', extra: _recipe(nutrition: null));
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('This recipe has no nutrition data.'), findsOneWidget);
    await tester.tap(find.text('Estimate calories'));
    await settleFrames(tester);
    expect(find.text('about 320 kcal per serving, estimated'), findsOneWidget);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.calories, 320);
    expect(entry.estimated, isTrue);
  });

  testWidgets('no nutrition, offline: kcal per serving typed in', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(offline: true), initial: '/recipes');
    router.push('/calories/add/recipe/r1', extra: _recipe(nutrition: null));
    await settleFrames(tester);
    final container = _container(tester);

    expect(find.text('Estimate calories'), findsNothing);
    expect(find.text('Calories per serving'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '500');
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    final entry = container.read(calorieDayProvider(kToday)).day!.entries.single;
    expect(entry.calories, 500);
    expect(entry.estimated, isFalse);
  });

  testWidgets('a deep link loads the recipe; a failed load says so with retry', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(
      tester,
      overrides: env.overrides(recipeLoader: (id) async => _recipe()),
      initial: '/recipes',
    );
    router.push('/calories/add/recipe/r1');
    await settleFrames(tester);
    expect(find.text('Ofengemüse mit Feta'), findsOneWidget);

    final failing = await CalorieTestEnv.create();
    final router2 = await pumpCaloriesFlow(tester, overrides: failing.overrides(), initial: '/recipes');
    router2.push('/calories/add/recipe/r9');
    await settleFrames(tester);
    expect(find.text('Couldn\'t load the recipe.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the estimate asks per serving even without servings, and at most 4.000 characters', (tester) async {
    final env = await CalorieTestEnv.create();
    String? sent;
    int? sentServings;
    final router = await pumpCaloriesFlow(
      tester,
      overrides: env.overrides(estimator: (String text, {int? servings}) async {
        sent = text;
        sentServings = servings;
        return const CalorieNutritionEstimate(kcal: 300, confidence: EstimateConfidence.low);
      }),
      initial: '/recipes',
    );
    final long = Recipe(
      id: 'r2',
      name: 'Eintopf',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 1,
      cookTimeMinutes: 1,
      defaultServings: 0,
      ingredients: [for (var i = 0; i < 400; i++) Ingredient(name: 'Zutat Nummer $i', amount: 1, unit: 'g')],
      instructions: const [],
      authorId: 'a',
      authorName: 'Avo',
      createdAt: DateTime(2026, 11, 1),
    );
    router.push('/calories/add/recipe/r2', extra: long);
    await settleFrames(tester);
    await tester.tap(find.text('Estimate calories'));
    await settleFrames(tester);
    expect(sent!.length, lessThanOrEqualTo(4000));
    expect(sentServings, 1);
  });
}
