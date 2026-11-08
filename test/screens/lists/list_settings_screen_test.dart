import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/category_order_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_changes.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';
import 'all_lists_fakes.dart';

// Mid-afternoon, so "12 to 44 min ago" stays on the same day at any hour
// the tests run.
final _now = DateTime(2026, 11, 8, 15);

ShoppingListModel _list({String owner = 'u1', int items = 12}) =>
    ShoppingListModel(
      id: 'w',
      name: 'Wocheneinkauf',
      ownerId: owner,
      isShared: true,
      createdAt: DateTime(2026, 10, 12),
      updatedAt: DateTime(2026, 11, 7),
      itemCount: items,
      uncheckedCount: 11,
      backgroundType: 'color',
      backgroundValue: '#007AFF',
    );

const _members = [
  ListMember(userId: 'u1', name: 'Jannis', isOwner: true),
  ListMember(userId: 'lena', name: 'Lena'),
];

ListActivity _event(
  ListActivityType type, {
  String user = 'lena',
  String name = 'Lena',
  String item = 'Butter',
  Duration ago = const Duration(minutes: 12),
}) => ListActivity(
  id: '${type.name}-${ago.inSeconds}-$item',
  listId: 'w',
  type: type,
  userId: user,
  userName: name,
  timestamp: _now.subtract(ago),
  metadata: {'itemName': item},
);

final _events = [
  _event(ListActivityType.itemAdded),
  _event(ListActivityType.itemChecked, item: 'Joghurt', ago: const Duration(minutes: 40)),
  _event(ListActivityType.itemChecked, item: 'Eier', ago: const Duration(minutes: 44)),
  _event(
    ListActivityType.itemAdded,
    user: 'u1',
    name: 'Jannis',
    item: 'Mineralwasser',
    ago: const Duration(days: 1, hours: 2),
  ),
];

List<Override> _overrides({
  ShoppingListModel? list,
  bool offline = false,
  FakeListActions? actions,
  List<ListActivity>? events,
}) => [
  allListsSourceProvider.overrideWithValue(AsyncData([list ?? _list()])),
  authUserIdProvider.overrideWithValue('u1'),
  listChangesClockProvider.overrideWithValue(() => _now),
  isOfflineProvider.overrideWithValue(offline),
  listMembersProvider.overrideWith((ref, id) async => _members),
  listActionsProvider.overrideWithValue(actions ?? FakeListActions()),
  pinnedListProvider.overrideWith((ref) => PinnedListNotifier(null)),
  offersAvailableProvider.overrideWithValue(true),
  offersHiddenForListProvider.overrideWith((ref, id) => false),
  storeForListProvider.overrideWith((ref, id) => null),
  listChangesProvider.overrideWith((ref, id) async => events ?? _events),
  categoryOrderOpenCountsProvider.overrideWith(
    (ref, id) => const {'dairy': 3},
  ),
];

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child,
  List<Override> overrides, {
  double height = kLayoutHeight,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(390 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        AvoToastHost(child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

const _info = ListSettingsScreen(listId: 'w', listName: 'Wocheneinkauf');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('changes of one person within ten minutes are one row', () {
    final rows = bundleChanges(_events);
    expect(rows.map((r) => r.count), [1, 2, 1]);
  });

  group('Listen-Info', () {
    testWidgets('shows name, creator, store, members, pin, changes, delete', (
      tester,
    ) async {
      await _pump(tester, _info, _overrides(), height: 2400);
      expect(find.text('List info'), findsOneWidget);
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.text('Created by Jannis · since Oct 12'), findsOneWidget);
      expect(find.text('Store order'), findsOneWidget);
      expect(find.text('Offers on this list'), findsOneWidget);
      expect(find.text('MEMBERS (2)'), findsOneWidget);
      expect(find.text('You · Creator'), findsOneWidget);
      expect(find.text('Invite people'), findsOneWidget);
      expect(find.text('Pin to top'), findsOneWidget);
      expect(find.text('Lena added Butter'), findsOneWidget);
      expect(find.text('Lena checked off 2 items'), findsOneWidget);
      expect(find.text('You added Mineralwasser'), findsOneWidget);
      expect(find.text('Show all'), findsOneWidget);
      expect(find.text('Delete list'), findsOneWidget);
      expect(find.text('The list is deleted for all members.'), findsOneWidget);
    });

    testWidgets('renaming saves when editing ends', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, _info, _overrides(actions: actions));
      await tester.tap(find.text('Wocheneinkauf'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, 'Großeinkauf');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(actions.renamed, ['w:Großeinkauf']);
    });

    testWidgets('an empty name goes back to the old one', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, _info, _overrides(actions: actions));
      await tester.tap(find.text('Wocheneinkauf'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(actions.renamed, isEmpty);
      expect(find.text('Wocheneinkauf'), findsOneWidget);
    });

    testWidgets('focusName opens with the name field focused', (tester) async {
      await _pump(
        tester,
        const ListSettingsScreen(
          listId: 'w',
          listName: 'Wocheneinkauf',
          focusName: true,
        ),
        _overrides(),
      );
      final field = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('a colour circle sets the colour', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, _info, _overrides(actions: actions));
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pump();
      expect(actions.colors, ['w:#FF3B30']);
    });

    testWidgets('pinning', (tester) async {
      final container = await _pump(tester, _info, _overrides(), height: 2400);
      await tester.tap(find.text('Pin to top'));
      await tester.pump();
      expect(container.read(pinnedListProvider).listId, 'w');
    });

    testWidgets('delete asks first, with the number of items', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, _info, _overrides(actions: actions), height: 2400);
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Wocheneinkauf”?'), findsOneWidget);
      expect(
        find.text(
          'The list and 12 items will be deleted for all members. This '
          'can’t be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.deleted, isEmpty);
      await tester.tap(find.text('Delete list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(actions.deleted, ['w']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('members leave instead of delete', (tester) async {
      final actions = FakeListActions();
      await _pump(
        tester,
        _info,
        _overrides(list: _list(owner: 'tom'), actions: actions),
        height: 2400,
      );
      expect(find.text('Delete list'), findsNothing);
      await tester.tap(find.text('Leave list'));
      await tester.pumpAndSettle();
      expect(find.text('Leave “Wocheneinkauf”?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(actions.left, ['w']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the creator removes a member after asking', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, _info, _overrides(actions: actions), height: 2400);
      await tester.longPress(find.text('Lena'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Lena?'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(actions.removed, ['w:lena']);
    });

    testWidgets('offline: delete needs a connection', (tester) async {
      final actions = FakeListActions();
      await _pump(
        tester,
        _info,
        _overrides(actions: actions, offline: true),
        height: 2400,
      );
      expect(find.text('Needs a connection'), findsOneWidget);
      await tester.tap(find.text('Delete list'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Delete “Wocheneinkauf”?'), findsNothing);
    });

    testWidgets('no changes yet', (tester) async {
      await _pump(
        tester,
        _info,
        _overrides(events: const []),
        height: 2400,
      );
      expect(find.text('No changes yet.'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
    });
  });

  group('store order', () {
    const screen = CategoryOrderScreen(listId: 'w', listName: 'Wocheneinkauf');

    testWidgets('lists every category with open counts and saves moves', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'custom_categories_w': jsonEncode([
          {'id': 'custom_1', 'name': 'Getränkemarkt', 'color': 0xFF9E9E9E},
        ]),
      });
      final handle = tester.ensureSemantics();
      await _pump(tester, screen, _overrides(), height: 2400);
      expect(
        find.text('For “Wocheneinkauf”, saved on this device.'),
        findsOneWidget,
      );
      expect(find.text('Getränkemarkt'), findsOneWidget);
      expect(find.text('Fruits & Vegetables'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Add category'), findsOneWidget);
      expect(find.text('Default order'), findsOneWidget);

      tester.semantics.customAction(
        find.semantics.byLabel('Getränkemarkt'),
        CustomSemanticsAction(label: 'Move down'),
      );
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList('category_order_w')!;
      expect(order.indexOf('custom_1'), 1);
      handle.dispose();
    });

    testWidgets('pops true after a change', (tester) async {
      bool? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () async => result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => screen),
              ),
              child: const Text('start'),
            ),
          ),
        ),
        _overrides(),
      );
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Default order'));
      await tester.tap(find.text('Default order'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a new category with a taken name is refused', (tester) async {
      await _pump(tester, screen, _overrides(), height: 2400);
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'fruits & vegetables');
      await tester.pump();
      expect(find.text('This category already exists.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Getränkemarkt');
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Getränkemarkt'), findsOneWidget);
    });
  });

  testWidgets('all changes: sections per day', (tester) async {
    await _pump(
      tester,
      const ListActivitiesScreen(listId: 'w', listName: 'Wocheneinkauf'),
      _overrides(),
    );
    expect(find.text('All changes'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('Lena checked off 2 items'), findsOneWidget);
  });

  layoutMatrix(
    'ListSettingsScreen',
    (context) => ProviderScope(overrides: _overrides(), child: _info),
  );
  layoutMatrix(
    'CategoryOrderScreen',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: const CategoryOrderScreen(
        listId: 'w',
        listName: 'Wocheneinkauf fürs lange Wochenende',
      ),
    ),
  );
  layoutMatrix(
    'ListActivitiesScreen',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: const ListActivitiesScreen(
        listId: 'w',
        listName: 'Wocheneinkauf',
      ),
    ),
  );
}
