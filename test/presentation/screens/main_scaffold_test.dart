import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/app_tab_bar.dart';
import 'package:shoply/routes/app_branch.dart';

class _Store implements ModuleStore {
  _Store(this.local);
  Map<String, dynamic>? local;
  @override
  Future<Map<String, dynamic>?> readLocal() async => local;
  @override
  Future<void> writeLocal(Map<String, bool> json) async => local = json;
  @override
  Future<bool?> readLegacyCalories() async => null;
  @override
  Future<Map<String, dynamic>?> readRemote() async => null;
  @override
  Future<void> writeRemote(Map<String, bool> json) async {}
}

/// A counter page, to see that tab state survives switching.
class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('${widget.name} $taps'),
        ),
      );
}

GoRouter _router() {
  GoRoute root(String path, String name, {List<RouteBase> routes = const []}) =>
      GoRoute(
        path: path,
        builder: (_, _) => _Counter(name),
        routes: routes,
      );
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) =>
            MainScaffold(navigationShell: shell, location: state.fullPath),
        navigatorContainerBuilder: (context, shell, children) =>
            ShellBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(routes: [root('/home', 'home')]),
          StatefulShellBranch(routes: [
            root('/lists', 'lists', routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => Text('list ${s.pathParameters['id']}'),
              ),
            ]),
          ]),
          StatefulShellBranch(routes: [root('/avo', 'avo')]),
          StatefulShellBranch(routes: [root('/recipes', 'recipes')]),
          StatefulShellBranch(routes: [root('/profile', 'profile')]),
        ],
      ),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester, {bool avoOn = true}) async {
  SharedPreferences.setMockInitialValues({});
  final router = _router();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authUserIdProvider.overrideWith((ref) => null),
      moduleStoreProvider.overrideWithValue(_Store({'avo': avoOn})),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('five D2 tabs in order', (tester) async {
    await _pump(tester);
    final bar = tester.widget<AppTabBar>(find.byType(AppTabBar));
    expect(bar.items.map((i) => i.label),
        ['Home', 'Lists', 'Avo', 'Recipes', 'Profile']);
    expect(bar.selectedIndex, 0);
  });

  testWidgets('Avo module off: the Avo tab disappears', (tester) async {
    await _pump(tester, avoOn: false);
    final bar = tester.widget<AppTabBar>(find.byType(AppTabBar));
    expect(bar.items.map((i) => i.label),
        ['Home', 'Lists', 'Recipes', 'Profile']);
  });

  testWidgets('switching tabs keeps each tab\'s state', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('home 0'));
    await tester.pump();
    expect(find.text('home 1'), findsOneWidget);

    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.text('recipes 0'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('home 1'), findsOneWidget);
  });

  testWidgets('tapping the active tab again returns to its root',
      (tester) async {
    final router = await _pump(tester);
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    router.go('/lists/abc');
    await tester.pumpAndSettle();
    expect(find.text('list abc'), findsOneWidget);

    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('list abc'), findsNothing);
    expect(find.text('lists 0'), findsOneWidget);
  });

  testWidgets('the tab bar hides while the keyboard is up', (tester) async {
    await _pump(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(AppTabBar), findsNothing);
  });

  test('AppBranch order matches the shell', () {
    expect(AppBranch.values.map((b) => b.name),
        ['home', 'lists', 'avo', 'recipes', 'profile']);
  });
}
