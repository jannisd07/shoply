import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/routes/areas/offers_routes.dart' show buildOffersRoot;
import 'package:shoply/routes/route_paths.dart';

/// Collects `name -> full path` for every named GoRoute, depth first.
Map<String, String> _collect(List<RouteBase> routes, [String parent = '']) {
  final out = <String, String>{};
  for (final r in routes) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : (parent == '/' ? '/${r.path}' : '$parent/${r.path}');
      if (r.name != null) out[r.name!] = full;
      out.addAll(_collect(r.routes, full));
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        out.addAll(_collect(b.routes, parent));
      }
    } else if (r is ShellRouteBase) {
      out.addAll(_collect(r.routes, parent));
    }
  }
  return out;
}

/// The real route table, for matching without building any screen.
RouteConfiguration _config() => RouteConfiguration(
  ValueNotifier(RoutingConfig(routes: buildAppRoutes())),
  navigatorKey: rootNavigatorKey,
);

/// A small router in the same order as [buildAppRoutes]: Teil B's
/// full-screen roots first, then the shell with the Listen (Angebote) and
/// Rezepte tabs, plus Home.
GoRouter _miniRouter(String initial) {
  Widget label(String text) => Center(child: Text(text));
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: RoutePaths.offersOfferPattern,
        builder: (_, s) => label('Angebot ${s.pathParameters['offerId']}'),
      ),
      GoRoute(
        path: RoutePaths.caloriesAdd,
        builder: (_, __) => label('Essen eintragen'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: RoutePaths.home, builder: (_, __) => label('Home')),
              GoRoute(
                path: RoutePaths.calories,
                builder: (_, __) => label('Tagebuch'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.offers,
                builder: (_, __) => label('Angebote der Woche'),
                routes: [
                  GoRoute(
                    path: 'list/:listId',
                    builder: (_, __) => label('Angebote bei'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.recipes,
                builder: (_, __) => label('Rezepte'),
                routes: [
                  GoRoute(
                    path: ':recipeId',
                    builder: (_, __) => label('Rezeptdetail'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<GoRouter> _pumpMini(WidgetTester tester, String initial) async {
  final router = _miniRouter(initial);
  await tester.pumpWidget(
    WidgetsApp.router(routerConfig: router, color: const Color(0xFF000000)),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('A1 split keeps every route name and path', () {
    // Snapshot of lib/routes/app_router.dart before the split (07.11.2026),
    // plus the new mount points for Teil B (plan, settings, offers, history).
    const expected = {
      'onboarding': '/onboarding',
      'welcome': '/welcome',
      'login': '/login',
      'signup': '/signup',
      'reset-password': '/reset-password',
      'name-prompt': '/name-prompt',
      // New in A7: invitations by share code (Konzept 17 §5.1).
      'join-code': '/join/:code',
      'home': '/home',
      'recipes': '/recipes',
      'add-recipe': '/recipes/add',
      'recipe-drafts': '/recipes/drafts',
      'saved-recipes': '/recipes/saved',
      'my-recipes': '/recipes/my',
      'creators': '/recipes/creators',
      'popular-recipes': '/recipes/popular',
      'all-recipes': '/recipes/all',
      'category-recipes': '/recipes/category/:categoryId',
      'recipe-detail': '/recipes/:recipeId',
      'calories': '/calories',
      'profile': '/profile',
      'avo-chat': '/avo',
      'list-detail': '/lists/:listId',
      'list-activities': '/lists/:listId/activities',
      // New in A5: shopping mode above the tab bar.
      'list-shopping': '/lists/:listId/shopping',
      'author-profile': '/author/:authorId',
      'diet-preferences': '/diet-preferences',
      'shared-recipe': '/recipe/:recipeId',
      'shared-list': '/list/:listId',
      'list-invite': '/invite/:listId',
      // New in A1: where Teil B's routes are mounted.
      'plan': '/plan',
      'settings': '/settings',
      'offers': '/offers',
      'history': '/history',
      // New in A2: Listen tab root and the paywall path for Teil B.
      'lists': '/lists',
      'pro': '/pro',
      // Debug builds only (tests run in debug): the component gallery.
      'debug-components': '/debug/components',
    };
    expect(_collect(buildAppRoutes()), expected);
  });

  test('D2 tabs: Home, Listen, Avo, Rezepte, Profil', () {
    final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
    final roots = [
      for (final b in shell.branches) (b.routes.first as GoRoute).path,
    ];
    expect(roots, [
      RoutePaths.home,
      RoutePaths.lists,
      RoutePaths.avo,
      RoutePaths.recipes,
      RoutePaths.profile,
    ]);
    expect(shell.branches.length, AppBranch.values.length);
  });

  test('Kalorien pushes in Home, a list and Angebote/Verlauf in Listen, '
      'settings in Profil, plan in Rezepte', () {
    final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
    Iterable<String> paths(AppBranch b) =>
        shell.branches[b.index].routes.whereType<GoRoute>().map((r) => r.path);
    expect(paths(AppBranch.home), contains(RoutePaths.calories));
    expect(
      paths(AppBranch.lists),
      containsAll([RoutePaths.lists, RoutePaths.offers, RoutePaths.history]),
    );
    expect(paths(AppBranch.profile), contains(RoutePaths.settings));
    expect(paths(AppBranch.recipes), contains(RoutePaths.plan));
    final lists = shell.branches[AppBranch.lists.index].routes.first as GoRoute;
    expect((lists.routes.single as GoRoute).path, ':listId');
  });

  group('A-R1: Teil B full screens come before the shell', () {
    test('every B root route is mounted ahead of the shell', () {
      final routes = buildAppRoutes();
      final shell = routes.indexWhere((r) => r is StatefulShellRoute);
      for (final r in bRootRoutes()) {
        final i = routes.indexOf(r);
        expect(i, isNonNegative);
        expect(i, lessThan(shell), reason: (r as GoRoute).path);
      }
    });

    test('they match above the tab bar, the shell keeps its own pushes', () {
      final config = _config();
      bool aboveTabs(String location) {
        final m = config.findMatch(location);
        expect(m.isError, isFalse, reason: location);
        return m.matches.first is! ShellRouteMatch;
      }

      String pattern(String location) => config.findMatch(location).fullPath;

      expect(aboveTabs('/offers/offer/42'), isTrue);
      expect(pattern('/offers/offer/42'), RoutePaths.offersOfferPattern);
      expect(aboveTabs('/offers/recipe/r1?list=l1'), isTrue);
      expect(pattern('/offers/recipe/r1'), RoutePaths.offersRecipePattern);
      expect(aboveTabs(RoutePaths.storesPick), isTrue);
      expect(aboveTabs(RoutePaths.storesRegion), isTrue);
      expect(aboveTabs('${RoutePaths.caloriesAdd}?meal=dinner'), isTrue);
      expect(pattern(RoutePaths.caloriesAdd), RoutePaths.caloriesAdd);
      expect(aboveTabs(RoutePaths.caloriesScan), isTrue);
      expect(aboveTabs(RoutePaths.caloriesGoalsSetup), isTrue);

      expect(aboveTabs(RoutePaths.offers), isFalse);
      expect(aboveTabs('/offers/list/l1'), isFalse);
      expect(pattern('/offers/list/l1'), RoutePaths.offersListPattern);
      expect(aboveTabs(RoutePaths.calories), isFalse);
      expect(aboveTabs('/calories/goals'), isFalse);
    });

    testWidgets('/offers/offer/x opens over Rezepte and closes back to it', (
      tester,
    ) async {
      final router = await _pumpMini(tester, RoutePaths.recipes);
      expect(find.text('Rezepte'), findsOneWidget);
      router.push('/offers/offer/x');
      await tester.pumpAndSettle();
      expect(find.text('Angebot x'), findsOneWidget);
      expect(find.text('Angebote der Woche'), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Rezepte'), findsOneWidget);
      expect(find.text('Angebot x'), findsNothing);
    });

    testWidgets('/calories/add opens over Rezepte and closes back to it', (
      tester,
    ) async {
      final router = await _pumpMini(tester, RoutePaths.recipes);
      router.push('${RoutePaths.caloriesAdd}?meal=dinner');
      await tester.pumpAndSettle();
      expect(find.text('Essen eintragen'), findsOneWidget);
      expect(find.text('Tagebuch'), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Rezepte'), findsOneWidget);
    });
  });

  group('A-R2: guards', () {
    test('/offers uses the root builder of Teil B, no ModuleGate', () {
      final shell = buildAppRoutes().whereType<StatefulShellRoute>().single;
      final offers = shell.branches[AppBranch.lists.index].routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == RoutePaths.offers);
      // B's gate inside buildOffersRoot covers kill switch and module.
      expect(offers.builder, buildOffersRoot);
    });
  });

  group('Kalorien A-R3: a recipe from the Home tab (today)', () {
    test('/recipe/:id opens above any tab, /recipes/:id lives in Rezepte', () {
      final config = _config();
      expect(
        config.findMatch('/recipe/r1').matches.first,
        isNot(isA<ShellRouteMatch>()),
      );
      expect(
        config.findMatch(RoutePaths.recipe('r1')).matches.first,
        isA<ShellRouteMatch>(),
      );
    });

    testWidgets('pushing /recipes/:id from Home shows the Rezepte tab; '
        'back returns to Home', (tester) async {
      final router = await _pumpMini(tester, RoutePaths.home);
      router.push(RoutePaths.recipe('r1'));
      await tester.pumpAndSettle();
      expect(find.text('Rezeptdetail'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('A-V14: a trip of the history from another tab', () {
    test('/history/:tripId lives in the Listen tab below Verlauf', () {
      final shell = _config().findMatch('/history/t1').matches.first;
      expect(shell, isA<ShellRouteMatch>());
      final paths = (shell as ShellRouteMatch).matches
          .map((m) => m.route)
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();
      expect(paths, [RoutePaths.history, ':tripId']);
    });

    // A push stacks only the detail (an imperative match), not Verlauf below
    // it: back returns to where the person came from. A `go` would build
    // Verlauf + detail in the Listen tab instead (s5b-stand.md, A-V14).
    testWidgets('pushing it from Home shows the detail; back returns to Home', (
      tester,
    ) async {
      Widget label(String text) => Center(child: Text(text));
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: RoutePaths.home,
                    builder: (_, __) => label('Home'),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: RoutePaths.history,
                    builder: (_, __) => label('Verlauf'),
                    routes: [
                      GoRoute(
                        path: ':tripId',
                        builder: (_, __) => label('Einkauf'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        WidgetsApp.router(routerConfig: router, color: const Color(0xFF000000)),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/history/t1'));
      await tester.pumpAndSettle();
      expect(find.text('Einkauf'), findsOneWidget);
      expect(find.text('Verlauf', skipOffstage: false), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      router.go('/history/t1');
      await tester.pumpAndSettle();
      expect(find.text('Einkauf'), findsOneWidget);
      expect(find.text('Verlauf', skipOffstage: false), findsOneWidget);
    });
  });

  test(
    'RoutePaths.list builds the same link as the old shared-list target',
    () {
      expect(
        RoutePaths.list('abc', name: 'Shared List'),
        '/lists/abc?name=Shared+List',
      );
      expect(RoutePaths.list('abc'), '/lists/abc');
    },
  );
}
