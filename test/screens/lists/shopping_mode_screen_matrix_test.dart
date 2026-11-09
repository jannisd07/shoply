// Layout matrix (A11) for the `ShoppingModeScreen` shell, the full screen as
// the router opens it: providers fed through overrides, no Supabase. States:
// content, nothing to buy, loading, load failed, offline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/shopping_mode_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_aisles.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_header.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../layout/layout_matrix.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ShoppingItemModel _item(
  String name,
  String category, {
  bool checked = false,
  double quantity = 1,
  String? unit,
  String? notes,
}) => ShoppingItemModel(
  id: name,
  listId: 'l1',
  name: name,
  categoryId: category,
  quantity: quantity,
  unit: unit,
  notes: notes,
  isChecked: checked,
  checkedAt: checked ? _at : null,
  createdAt: _at,
  updatedAt: _at,
);

/// Wocheneinkauf: 9 open in five aisles, 2 done.
final _week = [
  _item('Bananen', 'fruits_vegetables'),
  _item('Tomaten', 'fruits_vegetables', quantity: 500, unit: 'g'),
  _item('Vollkornbrot mit Sonnenblumenkernen', 'bakery'),
  _item('Milch', 'dairy', quantity: 2),
  _item('Feta', 'dairy', quantity: 200, unit: 'g'),
  _item('Hähnchenbrust', 'meat_fish', quantity: 400, unit: 'g'),
  _item('Spaghetti', 'staples', quantity: 2),
  _item('Mehl', 'staples', quantity: 1, unit: 'kg'),
  _item('Mineralwasser', 'beverages', quantity: 6, notes: 'still, Glas'),
  _item('Eier', 'dairy', checked: true),
  _item('Joghurt', 'dairy', checked: true),
];

/// The list's notifier without a server, in any state.
class _Items extends StateNotifier<AsyncValue<List<ShoppingItemModel>>>
    implements ItemsNotifier {
  _Items(super.state);

  int loads = 0;

  @override
  String get listId => 'l1';

  @override
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {}

  @override
  Future<void> loadItems() async => loads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KeepAwake implements ShoppingKeepAwake {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

List<Override> _overrides(
  _Items items, {
  bool offline = false,
  String? name = 'Wocheneinkauf fürs lange Wochenende',
  List<String> companions = const [],
}) => [
  shoppingKeepAwakeProvider.overrideWithValue(_KeepAwake()),
  itemsNotifierProvider.overrideWith((ref, listId) => items),
  shoppingListNameProvider.overrideWith((ref, listId) => name),
  shoppingAisleOrderProvider.overrideWith(
    (ref, listId) async => const ShoppingAisleOrder(),
  ),
  shoppingCompanionsProvider.overrideWith((ref, listId) => companions),
  isOfflineProvider.overrideWithValue(offline),
  listPreferencesProvider.overrideWith(
    (ref) => ListPreferencesNotifier(null)..state = const ListPreferences(),
  ),
];

Widget _screen(
  AsyncValue<List<ShoppingItemModel>> state, {
  bool offline = false,
  String? name = 'Wocheneinkauf fürs lange Wochenende',
  List<String> companions = const [],
  _Items? items,
}) => ProviderScope(
  overrides: _overrides(
    items ?? _Items(state),
    offline: offline,
    name: name,
    companions: companions,
  ),
  child: const AvoToastHost(
    child: SizedBox.expand(child: ShoppingModeScreen(listId: 'l1')),
  ),
);

/// The extremes and dark mode for the extra states.
const _stateCases = [
  LayoutCase(width: 320, scale: 1),
  LayoutCase(width: 320, scale: 3.1),
  LayoutCase(width: 390, scale: 1),
  LayoutCase(width: 440, scale: 2),
  LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
  LayoutCase(width: 390, scale: 1, highContrast: true),
];

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'show_article_images': false}),
  );

  layoutMatrix(
    'ShoppingModeScreen Inhalt',
    (context) =>
        _screen(AsyncValue.data(_week), companions: const ['Mara', 'Deniz']),
  );

  layoutMatrix(
    'ShoppingModeScreen alles erledigt',
    (context) => _screen(
      AsyncValue.data([
        for (final i in _week) i.copyWith(isChecked: true, checkedAt: _at),
      ]),
    ),
    cases: _stateCases,
  );

  layoutMatrix(
    'ShoppingModeScreen leer',
    (context) => _screen(const AsyncValue.data([])),
    cases: _stateCases,
  );

  layoutMatrix(
    'ShoppingModeScreen lädt, Name noch unbekannt',
    (context) => _screen(const AsyncValue.loading(), name: null),
    cases: _stateCases,
  );

  layoutMatrix(
    'ShoppingModeScreen Fehler',
    (context) =>
        _screen(AsyncValue.error(Exception('offline'), StackTrace.empty)),
    cases: _stateCases,
  );

  layoutMatrix(
    'ShoppingModeScreen offline',
    (context) => _screen(AsyncValue.data(_week), offline: true),
    cases: _stateCases,
  );

  layoutMatrix(
    'ShoppingModeScreen tap targets',
    (context) => _screen(AsyncValue.data(_week)),
    cases: const [
      LayoutCase(width: 390, scale: 1),
      LayoutCase(width: 320, scale: 3.1),
    ],
    checkTapTargets: true,
  );

  group('ShoppingModeScreen states', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        layoutHarness(const LayoutCase(width: 390, scale: 1), child),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('no name yet: the generic title', (tester) async {
      await pump(tester, _screen(const AsyncValue.loading(), name: null));
      expect(find.text('Shopping'), findsWidgets);
    });

    testWidgets('load failed: "Try again" loads the items again', (
      tester,
    ) async {
      final items = _Items(
        AsyncValue.error(Exception('offline'), StackTrace.empty),
      );
      await pump(tester, _screen(const AsyncValue.loading(), items: items));
      await tester.tap(find.text('Try again').hitTestable());
      await tester.pump();
      expect(items.loads, 1);
    });
  });
}
