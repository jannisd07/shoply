// kalorien.md §1: the diary is a push in the Home tab, "Essen eintragen"
// opens full screen above whatever tab it was opened from and closes back
// to it, although its path starts with the diary's `/calories`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
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
}
