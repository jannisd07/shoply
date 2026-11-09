import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_progress.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_timers.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

final _recipe = Recipe(
  id: 'r1',
  name: 'Ofengemüse mit Feta',
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients: const [
    Ingredient(name: 'Kartoffeln', amount: 750, unit: 'g'),
    Ingredient(name: 'Hirtenkäse', amount: 300, unit: 'g'),
    Ingredient(name: 'Olivenöl', amount: 3, unit: 'EL'),
    Ingredient(name: 'Oregano', amount: 1, unit: 'TL'),
    Ingredient(name: 'Salz nach Geschmack', amount: 0, unit: ''),
  ],
  instructions: const [
    'Den Ofen auf 200 Grad vorheizen. Die Kartoffeln waschen und in Spalten schneiden.',
    'Alles mit Olivenöl, Oregano und Salz mischen, auf einem Blech verteilen und 15 Minuten backen.',
  ],
  authorId: 'someone',
  authorName: 'Mara',
  createdAt: DateTime(2026, 11, 1),
);

class _Awake implements CookingKeepAwake {
  final calls = <bool>[];
  @override
  Future<void> enable() async => calls.add(true);
  @override
  Future<void> disable() async => calls.add(false);
}

class _Alerts implements CookingTimerAlerts {
  final scheduled = <int>{};
  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async => scheduled.add(id);
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

class _Clock {
  DateTime now = DateTime(2026, 11, 8, 18);
  DateTime call() => now;
}

List<Override> _overrides({
  _Awake? awake,
  _Alerts? alerts,
  _Clock? clock,
  List<int>? ratings,
  bool pro = true,
}) => [
  isSubscribedProvider.overrideWithValue(pro),
  cookingKeepAwakeProvider.overrideWithValue(awake ?? _Awake()),
  cookingTimerAlertsProvider.overrideWithValue(alerts ?? _Alerts()),
  cookingClockProvider.overrideWithValue((clock ?? _Clock()).call),
  cookingRateRecipeProvider.overrideWithValue(
    (id, r) async => ratings?.add(r),
  ),
  cookingShareRecipeProvider.overrideWithValue((_) async {}),
  authUserIdProvider.overrideWithValue('me'),
  moduleEnabledProvider.overrideWith((ref, module) => false),
  isOfflineProvider.overrideWithValue(false),
];

/// Tears the tree down and lets the last progress save finish inside this
/// test (it would land in the next test's preferences otherwise).
Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _settle(tester);
}

/// A behaviour test that ends with [_end].
void _cookTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await _end(tester);
    });

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _next(WidgetTester tester, [String label = 'Next']) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await _settle(tester);
}

/// A host page that opens the cooking mode like the detail does.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => openCookingMode(context, recipe: _recipe, servings: 2),
      child: const Text('open'),
    ),
  );
}

Widget _app(List<Override> overrides, Widget child) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: Scaffold(body: child),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix(
    'Kochmodus Zutaten',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: CookingModeScreen(recipe: _recipe, servings: 2),
    ),
  );

  layoutMatrix(
    'Kochmodus Schritt mit Timer',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: CookingModeScreen(recipe: _recipe, servings: 2),
    ),
    afterPump: (tester) async {
      await _next(tester);
      await _next(tester);
      // Start the timer of step 2: the capsule appears in the controls.
      await tester.tap(find.textContaining('Timer 15').first);
      await _settle(tester);
    },
  );

  layoutMatrix(
    'Kochmodus Fertig',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: CookingModeScreen(recipe: _recipe, servings: 2),
    ),
    afterPump: (tester) async {
      await _next(tester);
      await _next(tester);
      await _next(tester, 'Done');
    },
  );

  _cookTest('keeps the screen on, walks the pages, checks ingredients', (
    tester,
  ) async {
    final awake = _Awake();
    await tester.pumpWidget(_app(_overrides(awake: awake), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(awake.calls, [true]);
    expect(find.text('Get your ingredients ready'), findsOneWidget);
    expect(find.text('750 g'), findsOneWidget);
    // "Salz nach Geschmack" has no amount: no "0".
    expect(find.text('0'), findsNothing);

    await tester.tap(find.text('Kartoffeln'));
    await _settle(tester);
    expect(find.bySemanticsLabel(RegExp('Kartoffeln')), findsWidgets);

    await _next(tester);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    // Back works, the first page has no back.
    await tester.tap(find.bySemanticsLabel('Previous step'));
    await _settle(tester);
    expect(find.text('Get your ingredients ready'), findsOneWidget);

    // Swiping moves too.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('Step 1'), findsOneWidget);
  });

  _cookTest('without Pro, step 1 is the preview and step 2 opens the paywall', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              CookingModeScreen(recipe: _recipe, servings: 2),
        ),
        GoRoute(
          path: '/pro',
          builder: (context, state) =>
              Text('paywall ${state.uri.queryParameters['feature']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(pro: false),
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      ),
    );
    await _settle(tester);
    await _next(tester);
    expect(find.text('Step 1'), findsOneWidget);

    // "Weiter" carries the Pro badge and opens the paywall.
    await _next(tester, 'Next, Pro feature');
    expect(find.text('paywall cook_mode'), findsOneWidget);
    router.pop();
    await _settle(tester);
    expect(find.text('Step 1'), findsOneWidget);

    // A swipe cannot get past the gate either.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('paywall cook_mode'), findsOneWidget);
    router.pop();
    await _settle(tester);
    expect(find.text('Step 1'), findsOneWidget);
  });

  _cookTest('a step timer runs on the wall clock and reports the end', (
    tester,
  ) async {
    final alerts = _Alerts();
    final clock = _Clock();
    await tester.pumpWidget(
      _app(
        _overrides(alerts: alerts, clock: clock),
        CookingModeScreen(recipe: _recipe, servings: 2),
      ),
    );
    await _settle(tester);
    await _next(tester);
    await _next(tester);

    expect(find.text('You need'), findsOneWidget);
    expect(find.text('3 EL Olivenöl'), findsOneWidget);
    await tester.tap(find.textContaining('Timer 15').first);
    await _settle(tester);
    expect(alerts.scheduled, {700101});
    expect(find.text('Timer running'), findsOneWidget);
    expect(find.textContaining('15:00'), findsOneWidget);

    clock.now = clock.now.add(const Duration(minutes: 3, seconds: 13));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('11:47'), findsOneWidget);

    clock.now = clock.now.add(const Duration(minutes: 13));
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(find.text('Step 2 done'), findsOneWidget);
    expect(find.text('Timer done'), findsOneWidget);

    // Tapping the capsule dismisses the finished timer.
    await tester.tap(find.text('Step 2 done'));
    await _settle(tester);
    expect(find.text('Step 2 done'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  _cookTest('closing mid-cooking asks first and keeps the progress', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_overrides(), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _next(tester);

    await tester.tap(find.bySemanticsLabel('Close cooking mode'));
    await _settle(tester);
    expect(find.text('Pause cooking?'), findsOneWidget);
    await tester.tap(find.text('Keep cooking'));
    await _settle(tester);
    expect(find.text('Step 1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close cooking mode'));
    await _settle(tester);
    await tester.tap(find.text('Pause'));
    await _settle(tester);
    expect(find.text('open'), findsOneWidget);

    final saved = await CookingProgressStore.load('r1');
    expect(saved?.page, 1);

    // Reopening continues at step 1, once with "Start over".
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Continuing at step 1'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    await tester.tap(find.text('Start over'));
    await _settle(tester);
    expect(find.text('Get your ingredients ready'), findsOneWidget);
  });

  _cookTest('closing on the ingredients page without checks needs no '
      'question', (tester) async {
    await tester.pumpWidget(_app(_overrides(), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Close cooking mode'));
    await _settle(tester);
    expect(find.text('Pause cooking?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  _cookTest('servings open full screen; checks stay', (tester) async {
    await tester.pumpWidget(_app(_overrides(), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.text('Kartoffeln'));
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('2 servings'));
    await _settle(tester);
    expect(find.text('Servings'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp('Increase|Erhöhen|Mehr')).last);
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Done'));
    await _settle(tester);

    expect(find.text('for 3 servings'), findsOneWidget);
    expect(find.text('1125 g'), findsOneWidget); // 750 g × 3 / 2
    final potatoes = tester.widget<CheckCircle>(
      find.byWidgetPredicate(
        (w) => w is CheckCircle && w.itemName.startsWith('Kartoffeln'),
      ),
    );
    expect(potatoes.checked, isTrue);
  });

  _cookTest('the done page rates and closes; progress is gone', (
    tester,
  ) async {
    final ratings = <int>[];
    await tester.pumpWidget(_app(_overrides(ratings: ratings), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _next(tester);
    await _next(tester);
    await _next(tester, 'Done');
    expect(find.text('Enjoy your meal.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Rate 4 stars'));
    await _settle(tester);
    expect(ratings, [4]);
    await _next(tester, 'Close');
    expect(find.text('open'), findsOneWidget);
    expect(await CookingProgressStore.load('r1'), isNull);
  });

  _cookTest('Reduce Motion cross-fades the pages', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CookingModeScreen(recipe: _recipe, servings: 2),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(PageView), findsNothing);
    await _next(tester);
    expect(find.text('Step 1'), findsOneWidget);
  });

  _cookTest('dark on a light phone', (tester) async {
    await tester.pumpWidget(
      _app(_overrides(), CookingModeScreen(recipe: _recipe, servings: 2)),
    );
    await _settle(tester);
    final context = tester.element(find.text('Get your ingredients ready'));
    expect(context.colors.background, AvoColors.dark.background);
  });

  _cookTest('tells Avo where one is and restores it on close', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      _app(
        _overrides(),
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const _Host();
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(ref.read(avoScreenContextProvider)?.screen, 'recipe');
    await tester.tap(find.bySemanticsLabel('Close cooking mode'));
    await _settle(tester);
    expect(ref.read(avoScreenContextProvider), isNull);
  });
}
