import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_flow.dart';
import 'package:shoply/presentation/screens/lists/shopping_mode_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_aisles.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/areas/lists_routes.dart';
import 'package:shoply/routes/route_paths.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ShoppingItemModel _item(String name, {bool checked = false}) =>
    ShoppingItemModel(
      id: name,
      listId: 'l1',
      name: name,
      categoryId: 'fruits_vegetables',
      isChecked: checked,
      checkedAt: checked ? _at : null,
      createdAt: _at,
      updatedAt: _at,
    );

class _KeepAwake implements ShoppingKeepAwake {
  final calls = <String>[];

  @override
  Future<void> enable() async => calls.add('on');

  @override
  Future<void> disable() async => calls.add('off');
}

/// The list's notifier without a server: toggles change the state at once.
class _Items extends StateNotifier<AsyncValue<List<ShoppingItemModel>>>
    implements ItemsNotifier {
  _Items(List<ShoppingItemModel> items) : super(AsyncValue.data(items));

  final toggles = <String>[];

  @override
  String get listId => 'l1';

  @override
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    toggles.add('$itemId:$isChecked');
    state = AsyncValue.data([
      for (final i in state.value!)
        i.id == itemId ? i.copyWith(isChecked: isChecked, checkedAt: _at) : i,
    ]);
  }

  @override
  Future<void> loadItems() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ShoppingModeScreen(listId: 'l1'),
        ),
      ),
      child: const Text('open'),
    ),
  );
}

GoRoute? _route(List<RouteBase> routes, String name) {
  for (final r in routes) {
    if (r is GoRoute && r.name == name) return r;
    final found = _route(r.routes, name);
    if (found != null) return found;
  }
  return null;
}

void main() {
  test('route: /lists/:id/shopping on the root navigator, above the tabs', () {
    final route = _route(listsBranchRoutes, 'list-shopping')!;
    expect(route.path, 'shopping');
    expect(route.parentNavigatorKey, same(rootNavigatorKey));
    expect(_route(listsBranchRoutes, 'list-detail')!.routes, contains(route));
    expect(RoutePaths.shopping('l1'), '/lists/l1/shopping');
  });

  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_article_images': false}),
  );

  late _KeepAwake awake;
  late _Items items;
  late ProviderContainer container;
  late List<String> checkouts;

  Future<void> open(
    WidgetTester tester, {
    bool saves = true,
    ListPreferences prefs = const ListPreferences(),
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    awake = _KeepAwake();
    items = _Items([_item('Bananen'), _item('Gurken')]);
    checkouts = [];
    container = ProviderContainer(
      overrides: [
        shoppingKeepAwakeProvider.overrideWithValue(awake),
        itemsNotifierProvider.overrideWith((ref, listId) => items),
        shoppingListNameProvider.overrideWith((ref, listId) => 'Wocheneinkauf'),
        shoppingAisleOrderProvider.overrideWith(
          (ref, listId) async => const ShoppingAisleOrder(),
        ),
        isOfflineProvider.overrideWithValue(false),
        listPreferencesProvider.overrideWith(
          (ref) => ListPreferencesNotifier(null)..state = prefs,
        ),
        checkoutRunnerProvider.overrideWithValue((context, ref, listId) async {
          checkouts.add(listId);
          return saves;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(avoScreenContextProvider.notifier).state =
        const AvoScreenContext(screen: 'list', listId: 'l1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          builder: (context, child) => AvoToastHost(child: child!),
          home: const _Launcher(),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the screen on while open and in the foreground', (
    tester,
  ) async {
    await open(tester);
    expect(awake.calls, ['on']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(awake.calls, ['on', 'off']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(awake.calls, ['on', 'off', 'on']);

    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(awake.calls, ['on', 'off', 'on', 'off']);
  });

  testWidgets('"Bildschirm anlassen" off: the screen may sleep', (
    tester,
  ) async {
    await open(tester, prefs: const ListPreferences(keepScreenOn: false));
    expect(awake.calls, isEmpty);

    // Switched on while open (Avo, Einstellungen): on at once.
    final notifier = container.read(listPreferencesProvider.notifier);
    await notifier.update(const ListPreferences());
    await tester.pump();
    expect(awake.calls, ['on']);
    await notifier.update(const ListPreferences(keepScreenOn: false));
    await tester.pump();
    expect(awake.calls, ['on', 'off']);
  });

  testWidgets('tells Avo it is the shopping mode, hands back on leaving', (
    tester,
  ) async {
    await open(tester);
    expect(
      container.read(avoScreenContextProvider),
      const AvoScreenContext(
        screen: 'shopping',
        listId: 'l1',
        listName: 'Wocheneinkauf',
      ),
    );
    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(
      container.read(avoScreenContextProvider),
      const AvoScreenContext(screen: 'list', listId: 'l1'),
    );
  });

  testWidgets('sets the shopping mode session while open, clears it after', (
    tester,
  ) async {
    final before = DateTime.now();
    await open(tester);
    expect(container.read(shoppingModeSessionProvider), isNotNull);
    final session = container.read(shoppingModeSessionProvider)!;
    expect(session.listId, 'l1');
    expect(session.startedAt.isBefore(before), isFalse);

    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(container.read(shoppingModeSessionProvider), isNull);
  });

  testWidgets('leaving keeps a session that belongs to another list', (
    tester,
  ) async {
    await open(tester);
    final other = ShoppingModeSession(listId: 'l2', startedAt: _at);
    container.read(shoppingModeSessionProvider.notifier).state = other;

    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(container.read(shoppingModeSessionProvider), other);
  });

  testWidgets('a stacked shopping mode gives the session back on closing', (
    tester,
  ) async {
    await open(tester);
    // `open` ran the first mode; pretend one was already running below.
    final below = ShoppingModeSession(listId: 'l0', startedAt: _at);
    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    container.read(shoppingModeSessionProvider.notifier).state = below;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(container.read(shoppingModeSessionProvider)!.listId, 'l1');
    await tester.tap(find.bySemanticsLabel('Back').hitTestable());
    await tester.pumpAndSettle();
    expect(container.read(shoppingModeSessionProvider), below);
  });

  testWidgets('checks off through the list notifier', (tester) async {
    await open(tester);
    expect(find.text('Wocheneinkauf'), findsOneWidget);
    await tester.tap(find.text('Bananen'));
    await tester.pump();
    expect(items.toggles, ['Bananen:true']);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  });

  // A-V9: the success moment is Teil B's (V3, in the checkout flow); the
  // shopping mode only closes.
  testWidgets('a saved trip closes the shopping mode', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Bananen'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final finish = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Finish shopping',
    );
    await tester.tap(finish.hitTestable());
    await tester.pumpAndSettle();
    expect(checkouts, ['l1']);

    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Trip saved.'), findsNothing);
  });

  testWidgets('a cancelled checkout keeps the shopping mode open', (
    tester,
  ) async {
    await open(tester, saves: false);
    await tester.tap(find.text('Bananen'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is AppButton && w.label == 'Finish shopping',
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(checkouts, ['l1']);
    expect(find.text('Wocheneinkauf'), findsOneWidget);
    expect(find.text('Trip saved.'), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  });
}
