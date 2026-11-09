// kalorien.md §1: the diary is a push in the Home tab, "Essen eintragen"
// opens full screen above whatever tab it was opened from and closes back
// to it, although its path starts with the diary's `/calories`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_amount_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_entry_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_manual_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/routes/areas/calories_routes.dart';

import '../screens/calories/calorie_fakes.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/recipes',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => shell,
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (_, __) => const Text('Home')),
              GoRoute(path: '/calories', builder: buildCaloriesRoot, routes: caloriesChildRoutes),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/recipes', builder: (_, __) => const Text('Rezepte')),
            ]),
          ],
        ),
        ...caloriesRootRoutes,
      ],
    );

Future<GoRouter> _pump(WidgetTester tester) async {
  final env = await CalorieTestEnv.create();
  final router = _router();
  await tester.pumpWidget(ProviderScope(
    overrides: env.overrides(),
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('/calories/add opens over the Rezepte tab and closes back to it', (tester) async {
    final router = await _pump(tester);
    expect(find.text('Rezepte'), findsOneWidget);

    router.push('/calories/add?meal=dinner');
    await tester.pumpAndSettle();
    expect(find.byType(CaloriesAddScreen), findsOneWidget);
    expect(find.byType(CaloriesDiaryScreen), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Rezepte'), findsOneWidget);
  });

  testWidgets('/calories?date= opens the diary on that day; a future date means today', (tester) async {
    final router = await _pump(tester);
    router.go('/calories?date=2026-11-05');
    await tester.pumpAndSettle();
    expect(tester.widget<CaloriesDiaryScreen>(find.byType(CaloriesDiaryScreen)).initialDateKey, '2026-11-05');

    router.go('/calories?date=2999-01-01');
    await tester.pumpAndSettle();
    expect(tester.widget<CaloriesDiaryScreen>(find.byType(CaloriesDiaryScreen)).initialDateKey, isNull);
  });

  testWidgets('shoply://calories/water opens the diary at the water row', (tester) async {
    final router = await _pump(tester);
    router.go('/calories/water?ml=250');
    await tester.pumpAndSettle();
    expect(tester.widget<CaloriesDiaryScreen>(find.byType(CaloriesDiaryScreen)).focusWater, isTrue);
  });

  testWidgets('"Eintragen" in S7 closes the whole flow: back where S3 was opened', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides(), initial: '/recipes');
    router.push('/calories/add?meal=lunch');
    await settleFrames(tester);
    expect(find.byType(CaloriesAddScreen), findsOneWidget);
    router.push(
      '/calories/add/food/4056489123453?meal=lunch',
      extra: CalorieAmountFood.fromProduct(offProduct('4056489123453', 'Skyr Natur'), origin: FoodEntryOrigin.search),
    );
    await settleFrames(tester);
    expect(find.byType(CaloriesAmountScreen), findsOneWidget);

    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(find.byType(CaloriesAmountScreen), findsNothing);
    expect(find.byType(CaloriesAddScreen), findsNothing);
    expect(find.text('Rezepte'), findsOneWidget);
    expect(find.text('Skyr Natur logged'), findsOneWidget);
  });

  testWidgets('"Eintragen" in S8 closes S3 too', (tester) async {
    final env = await CalorieTestEnv.create();
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides());
    router.push('/calories/add');
    await settleFrames(tester);
    router.push('/calories/add/manual?name=Suppe');
    await settleFrames(tester);
    expect(find.byType(CaloriesManualScreen), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(1), '250');
    await settleFrames(tester);
    await tester.tap(find.text('Log'));
    await settleFrames(tester);
    expect(find.byType(CaloriesAddScreen), findsNothing);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('a diary row opens S9 above the tab; "Edit" is in its menu', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()});
    final router = await pumpCaloriesFlow(tester, overrides: env.overrides());
    router.go('/calories');
    await settleFrames(tester);

    await tester.longPress(find.text('Banane'));
    await settleFrames(tester);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await settleFrames(tester);
    expect(find.byType(CaloriesEntryScreen), findsOneWidget);
    expect(tester.widget<CaloriesEntryScreen>(find.byType(CaloriesEntryScreen)).entryId, 'e2');

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settleFrames(tester);
    await tester.tap(find.text('Haferflocken'));
    await settleFrames(tester);
    expect(tester.widget<CaloriesEntryScreen>(find.byType(CaloriesEntryScreen)).entryId, 'e1');
  });
}
