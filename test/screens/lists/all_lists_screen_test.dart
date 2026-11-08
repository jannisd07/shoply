import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/all_lists_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_body.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_quick_add.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/quick_add_tile.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';
import 'all_lists_fakes.dart';

final _now = DateTime(2026, 11, 7, 10, 42);

ShoppingListModel _list(
  String id, {
  String name = 'Wocheneinkauf',
  String owner = 'u1',
  int items = 12,
  int open = 4,
  DateTime? updated,
  bool shared = false,
  String type = 'color',
  String? value = '#007AFF',
  String? code,
}) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: owner,
  isShared: shared,
  shareCode: code,
  createdAt: DateTime(2026, 10, 12),
  updatedAt: updated ?? _now.subtract(const Duration(hours: 2)),
  itemCount: items,
  uncheckedCount: open,
  backgroundType: type,
  backgroundValue: value,
);

final _lists = [
  _list('w', shared: true, updated: _now.subtract(const Duration(hours: 2))),
  _list(
    'r',
    name: 'REWE',
    value: '#FF3B30',
    items: 4,
    updated: _now.subtract(const Duration(days: 1)),
  ),
  _list(
    'g',
    name: 'Grillabend Samstag',
    value: '#FF9500',
    items: 9,
    open: 0,
    updated: _now.subtract(const Duration(days: 3)),
  ),
  _list(
    'wg',
    name: 'WG-Vorrat',
    owner: 'tom',
    shared: true,
    value: '#34C759',
    items: 6,
    open: 6,
    updated: _now.subtract(const Duration(hours: 5)),
  ),
];

const _members = {
  'w': [
    ListMember(userId: 'u1', name: 'Jannis', isOwner: true),
    ListMember(userId: 'lena', name: 'Lena'),
  ],
  'wg': [
    ListMember(userId: 'tom', name: 'Tom', isOwner: true),
    ListMember(userId: 'u1', name: 'Jannis'),
  ],
};

const _quick = [
  QuickAddSuggestion(name: 'Haferflocken'),
  QuickAddSuggestion(name: 'Zwiebeln'),
  QuickAddSuggestion(name: 'Kaffee'),
];

List<Override> _overrides({
  AsyncValue<List<ShoppingListModel>>? lists,
  List<QuickAddSuggestion> quick = _quick,
  bool offline = false,
  FakeListActions? actions,
}) => [
  allListsSourceProvider.overrideWithValue(lists ?? AsyncData(_lists)),
  authUserIdProvider.overrideWithValue('u1'),
  lastAccessedListProvider.overrideWith((ref) => LastAccessedListNotifier(null)),
  pinnedListProvider.overrideWith((ref) => PinnedListNotifier(null)),
  isOfflineProvider.overrideWithValue(offline),
  allListsQuickAddProvider.overrideWithValue(quick),
  listMembersProvider.overrideWith((ref, id) async => _members[id] ?? const []),
  listActionsProvider.overrideWithValue(actions ?? FakeListActions()),
];

Widget _content(BuildContext context, {List<ShoppingListModel>? lists}) {
  final all = lists ?? _lists;
  final hero = pickHeroList(all);
  final rest = [
    for (final l in all)
      if (l.id != hero?.id) l,
  ];
  return AllListsContent(
    phase: AllListsPhase.ready,
    lists: all,
    hero: hero,
    mine: [
      for (final l in rest)
        if (l.ownerId == 'u1') l,
    ],
    sharedWithMe: [
      for (final l in rest)
        if (l.ownerId != 'u1') l,
    ],
    currentUserId: 'u1',
    now: _now,
    members: _members,
    quickAdd: _quick,
    onOpen: (_) {},
    onMenu: (_, _) {},
    onCreate: () {},
    onJoin: () {},
    onQuickAdd: (_) {},
  );
}

Future<void> _pumpScreen(WidgetTester tester, List<Override> overrides) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        // Like the app: toasts live in the host around the navigator.
        const AvoToastHost(child: AllListsScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('data', () {
    test('big card: pinned, then last opened, then last used', () {
      expect(pickHeroList(_lists)!.id, 'w');
      expect(pickHeroList(_lists, lastOpenedId: 'r')!.id, 'r');
      expect(
        pickHeroList(_lists, pinnedId: 'g', lastOpenedId: 'r')!.id,
        'g',
      );
      expect(pickHeroList(_lists, pinnedId: 'gone')!.id, 'w');
      expect(pickHeroList(const []), isNull);
    });

    test('rows keep the order of the snapshot, new lists first', () {
      final snapshot = listOrderSnapshot(_lists);
      final changed = [
        _list('r', name: 'REWE', updated: _now), // changed since opening
        ..._lists.where((l) => l.id != 'r'),
        _list('new', name: 'Neu'),
      ];
      expect(sortBySnapshot(changed, snapshot).map((l) => l.id), [
        'new',
        'w',
        'wg',
        'r',
        'g',
      ]);
    });

    test('search is case-insensitive', () {
      expect(filterLists(_lists, 'rew').map((l) => l.id), ['r']);
      expect(filterLists(_lists, '  '), _lists);
      expect(openItemCount(_lists), 14);
    });

    test('palette: stored hex, variants, next free colour, no black', () {
      final blue = kListPalette.first;
      expect(blue.hex, '#007AFF');
      expect(paletteColorOfHex('#007aff')?.id, 'blue');
      expect(paletteColorOfHex('nope'), isNull);
      expect(nextFreePaletteColor(_lists).id, 'yellow');
      expect(
        fallbackPaletteColor('abc').id,
        fallbackPaletteColor('abc').id,
      );
    });
  });

  testWidgets('summary, card, quick add, other lists, shared with me', (
    tester,
  ) async {
    await _pumpScreen(tester, _overrides());
    // The harness runs in English.
    expect(find.text('Lists'), findsOneWidget);
    expect(find.text('4 lists · 14 open'), findsOneWidget);
    expect(find.byType(ListCard), findsOneWidget);
    expect(find.text('Wocheneinkauf'), findsOneWidget);
    expect(find.textContaining('12 items · 4 open · '), findsOneWidget);
    expect(find.text('with Lena'), findsOneWidget);
    expect(find.byType(QuickAddTile), findsNWidgets(3));
    expect(find.text('OTHER LISTS'), findsOneWidget);
    expect(find.text('SHARED WITH ME'), findsOneWidget);
    expect(find.text('6 open · by Tom'), findsOneWidget);
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('9/9'), findsOneWidget);
  });

  testWidgets('sets Avo\'s screen context to the lists', (tester) async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    await loadLayoutFonts();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: layoutHarness(
          const LayoutCase(width: 390, scale: 1),
          const AllListsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      container.read(avoScreenContextProvider),
      const AvoScreenContext(screen: 'lists'),
    );
  });

  testWidgets('empty: first list and join', (tester) async {
    await _pumpScreen(tester, _overrides(lists: const AsyncData([])));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No lists yet.'), findsOneWidget);
    expect(find.text('Create first list'), findsOneWidget);
    expect(find.text('Join a list'), findsOneWidget);
    expect(find.byType(ListCard), findsNothing);
  });

  testWidgets('first load without local data shows placeholders', (
    tester,
  ) async {
    await _pumpScreen(tester, _overrides(lists: const AsyncLoading()));
    expect(find.byType(SkeletonSection), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('offline shows the status row', (tester) async {
    await _pumpScreen(tester, _overrides(offline: true));
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('a quick add tile puts the item on the card\'s list, undo '
      'takes it back', (tester) async {
    final actions = FakeListActions();
    await _pumpScreen(tester, _overrides(actions: actions));
    await tester.tap(find.bySemanticsLabel('Add Kaffee again'));
    await tester.pump();
    expect(actions.added, ['w:Kaffee']);
    expect(find.byType(QuickAddTile), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Kaffee is on “Wocheneinkauf” now.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(actions.undone, ['token-1']);
    expect(find.byType(QuickAddTile), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed quick add brings the tile back', (tester) async {
    final actions = FakeListActions(failAdd: true);
    await _pumpScreen(tester, _overrides(actions: actions));
    await tester.tap(find.bySemanticsLabel('Add Kaffee again'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(QuickAddTile), findsNWidgets(3));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('search appears from seven lists and filters', (tester) async {
    final many = [
      for (var i = 0; i < 7; i++) _list('l$i', name: 'Liste $i', items: 1),
    ];
    await _pumpScreen(tester, _overrides(lists: AsyncData(many)));
    expect(find.text('Search lists'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Liste 3');
    await tester.pump();
    expect(find.byType(ListRow), findsOneWidget);
    expect(find.widgetWithText(ListRow, 'Liste 3'), findsOneWidget);
    expect(find.byType(ListCard), findsNothing);
  });

  layoutMatrix(
    'AllListsContent',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: _content(context),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'AllListsContent (long names)',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: _content(
        context,
        lists: [
          _list(
            'w',
            name: 'Wocheneinkauf fürs lange Wochenende mit Grillen',
            shared: true,
          ),
          _list(
            'wg',
            name: 'WG-Vorrat für die ganze Wohngemeinschaft',
            owner: 'tom',
            shared: true,
          ),
        ],
      ),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'AllListsContent (empty)',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: _content(context, lists: const []),
    ),
    scrollable: true,
  );
  layoutMatrix(
    'AllListsQuickAdd',
    (context) => ProviderScope(
      child: AllListsQuickAdd(
        listId: 'w',
        suggestions: const [
          QuickAddSuggestion(name: 'Laktosefreie Vollmilch'),
          ..._quick,
        ],
        onAdd: (_) {},
      ),
    ),
    scrollable: true,
  );
}
