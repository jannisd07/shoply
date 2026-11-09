import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/list_detail_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_maybe_also.dart';
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

const _listId = 'l1';
final _at = DateTime(2026, 1, 1);

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

ShoppingItemModel _item(
  String id,
  String name, {
  String category = 'other',
  double quantity = 1,
  String? unit,
  bool checked = false,
  double? price,
  String? notes,
  int? order,
  DateTime? checkedAt,
}) => ShoppingItemModel(
  id: id,
  listId: _listId,
  name: name,
  quantity: quantity,
  unit: unit,
  category: category,
  categoryId: category,
  isChecked: checked,
  price: price,
  notes: notes,
  orderIndex: order,
  createdAt: _at,
  checkedAt: checked ? (checkedAt ?? _at) : null,
  updatedAt: _at,
);

final _items = [
  _item(
    'a',
    'Avocados',
    category: 'fruits_vegetables',
    quantity: 3,
    price: 0.99,
    order: 0,
  ),
  _item('b', 'Bananen', category: 'fruits_vegetables', unit: 'bunch', order: 1),
  _item(
    'm',
    'Hafermilch',
    category: 'dairy',
    quantity: 2,
    unit: 'l',
    price: 1.29,
    notes: 'ungesüßt',
    order: 2,
  ),
  _item('f', 'Feta', category: 'dairy', quantity: 200, unit: 'g', order: 3),
  _item(
    'e',
    'Eier',
    category: 'dairy',
    checked: true,
    order: 4,
    checkedAt: DateTime(2026, 1, 2),
  ),
  _item('n', 'Nudeln', category: 'staples', checked: true, order: 5),
];

ShoppingListModel _list({bool shared = true, String owner = 'u1'}) =>
    ShoppingListModel(
      id: _listId,
      name: 'Wocheneinkauf',
      ownerId: owner,
      isShared: shared,
      createdAt: _at,
      updatedAt: _at,
    );

class _FakeRepository extends Fake implements ItemRepository {
  final batches = <List<NewItem>>[];
  final undone = <String>[];

  @override
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    batches.add(items);
    return AddItemsResult(token: 'token-${batches.length}', items: const []);
  }

  @override
  Future<void> undoAddItems(String token) async => undone.add(token);
}

typedef _Added = ({String name, double quantity, String? unit, bool autoParse});

/// Applies toggles and deletes to its state; records adds; never loads.
class _FakeItems extends ItemsNotifier {
  _FakeItems(
    ItemRepository repository,
    AsyncValue<List<ShoppingItemModel>> start,
  ) : super(repository, _listId) {
    state = start;
  }

  final toggles = <(String, bool)>[];
  final deleted = <String>[];
  final added = <_Added>[];
  int loads = 0;

  List<ShoppingItemModel> get _current => state.valueOrNull ?? const [];

  @override
  Future<void> loadItems() async => loads++;

  @override
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    toggles.add((itemId, isChecked));
    state = AsyncData([
      for (final i in _current)
        i.id == itemId
            ? i.copyWith(isChecked: isChecked, checkedAt: DateTime.now())
            : i,
    ]);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    deleted.add(itemId);
    state = AsyncData([
      for (final i in _current)
        if (i.id != itemId) i,
    ]);
  }

  @override
  Future<void> addItem({
    required String name,
    double quantity = 1.0,
    String? unit,
    String? category,
    String? notes,
    bool isDietWarning = false,
    String? barcode,
    double? price,
    String? priceCurrency,
    String? priceRetailer,
    String? priceUnit,
    double? priceOldValue,
    bool autoParse = true,
  }) async {
    added.add((
      name: name,
      quantity: quantity,
      unit: unit,
      autoParse: autoParse,
    ));
  }
}

/// Records what the screen opens instead of navigating.
class _Actions extends ListDetailActions {
  final calls = <String>[];

  @override
  Future<void> openItem(
    BuildContext context, {
    required String listId,
    required ShoppingItemModel item,
  }) async => calls.add('item:${item.id}');

  @override
  Future<void> openShopping(BuildContext context, String listId) async =>
      calls.add('shopping:$listId');

  @override
  Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required String listId,
    required String listName,
  }) async => calls.add('share:$listName');

  @override
  Future<void> openInfo(
    BuildContext context, {
    required String listId,
    required String listName,
    String? ownerId,
  }) async => calls.add('info');

  @override
  Future<bool> openStoreOrder(
    BuildContext context, {
    required String listId,
    required String listName,
  }) async {
    calls.add('order');
    return false;
  }

  @override
  Future<void> importNote(
    BuildContext context, {
    required String listId,
    required GlobalKey anchorKey,
  }) async => calls.add('import:$listId');

  /// What Teil B's checkout returns (`true`: trip saved).
  bool checkoutResult = false;

  @override
  Future<bool> checkout(BuildContext context, String listId) async {
    calls.add('checkout');
    return checkoutResult;
  }

  @override
  Future<void> openListOffers(BuildContext context, String listId) async =>
      calls.add('offers:$listId');

  @override
  Future<void> renameList(WidgetRef ref, String listId, String name) async =>
      calls.add('rename:$name');

  @override
  Future<void> deleteList(WidgetRef ref, String listId) async =>
      calls.add('delete');

  @override
  Future<void> leaveList(WidgetRef ref, String listId) async =>
      calls.add('leave');

  @override
  Future<void> refreshLists(WidgetRef ref) async => calls.add('refresh');

  @override
  void back(BuildContext context) => calls.add('back');

  @override
  void openAllLists(BuildContext context) => calls.add('all');
}

class _Setup {
  _Setup({
    AsyncValue<List<ShoppingItemModel>>? items,
    this.list,
    this.offers = false,
    this.offline = false,
    this.arrival,
    this.maybeAlso = const [],
    this.prefs = const ListPreferences(),
  }) : repository = _FakeRepository() {
    notifier = _FakeItems(repository, items ?? AsyncData(_items));
  }

  final _FakeRepository repository;
  late final _FakeItems notifier;
  final actions = _Actions();
  final ShoppingListModel? list;
  final bool offers;
  final bool offline;
  final OnboardingArrival? arrival;
  final List<MaybeAlsoSuggestion> maybeAlso;
  final ListPreferences prefs;
  final List<String> members = const ['Lena'];

  List<Override> get overrides => [
    itemsNotifierProvider.overrideWith((ref, id) => notifier),
    itemRepositoryProvider.overrideWithValue(repository),
    listDetailListProvider.overrideWith((ref, id) => list ?? _list()),
    listDetailMembersProvider.overrideWith((ref, id) async => members),
    authUserIdProvider.overrideWithValue('u1'),
    currentUserProvider.overrideWith((ref) async => null),
    isOfflineProvider.overrideWithValue(offline),
    offersAvailableProvider.overrideWithValue(offers),
    listDetailActionsProvider.overrideWithValue(actions),
    maybeAlsoSourceProvider.overrideWithValue(maybeAlso),
    listPreferencesProvider.overrideWith(
      (ref) => ListPreferencesNotifier(null)..state = prefs,
    ),
  ];

  Widget screen({bool focusAdd = false}) => ListDetailScreen(
    listId: _listId,
    listName: 'Wocheneinkauf',
    focusAdd: focusAdd,
    arrival: arrival,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Setup setup, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
  bool focusAdd = false,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: setup.overrides,
      child: layoutHarness(layout, setup.screen(focusAdd: focusAdd)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(ListDetailScreen)),
  );
}

/// Lets toasts, the row pause and pending deletes run out.
Future<void> _settleTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 1));
}

Finder _row(String name) => find.widgetWithText(ItemRow, name);

/// A full swipe to the left, then the slide and the collapse run out.
Future<void> _swipeAway(WidgetTester tester, String name) async {
  await tester.drag(_row(name), const Offset(-500, 0));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapCircle(WidgetTester tester, String name) async {
  final rect = tester.getRect(_row(name));
  await tester.tapAt(Offset(rect.left + 30, rect.center.dy));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder get _more => find.byWidgetPredicate(
  (w) => w is AvoIcon && identical(w.icon, AvoIcons.more),
);

Finder get _cart => find.byWidgetPredicate(
  (w) => w is AvoIcon && identical(w.icon, AvoIcons.cart),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('header and aisles', () {
    testWidgets('title, members, progress, aisles with counts', (tester) async {
      await _pump(tester, _Setup());
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(
        find.text(_en('common_progress', {'done': '2', 'total': '6'})),
        findsOneWidget,
      );
      expect(_row('Avocados'), findsOneWidget);
      expect(_row('Feta'), findsOneWidget);
      // "3 pcs", "2 L · ungesüßt": quantity, unit and note.
      expect(find.text('3 pcs'), findsOneWidget);
      expect(find.text('2 L · ungesüßt'), findsOneWidget);
      expect(find.text('1 bunch'), findsOneWidget);
      // Avatar stack of the other member.
      expect(find.text('L'), findsOneWidget);
    });

    testWidgets('cart only while open items exist; starts shopping mode', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      expect(_cart, findsOneWidget);
      await tester.tap(_cart);
      await tester.pump();
      expect(setup.actions.calls, contains('shopping:$_listId'));
    });

    testWidgets('back and share go through the actions', (tester) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AvoIcon && identical(w.icon, AvoIcons.chevronBack),
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AvoIcon && identical(w.icon, AvoIcons.people),
        ),
      );
      await tester.pump();
      expect(setup.actions.calls, ['back', 'share:Wocheneinkauf']);
    });

    testWidgets('"Erledigt" collapsed to one row; tapping it expands', (
      tester,
    ) async {
      await _pump(tester, _Setup());
      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('Eier, Nudeln'), findsOneWidget);
      expect(_row('Eier'), findsNothing);
      await tester.ensureVisible(find.text('DONE'));
      await tester.pump();
      await tester.tap(find.text('DONE'));
      await tester.pump();
      expect(_row('Eier'), findsOneWidget);
      expect(_row('Nudeln'), findsOneWidget);
      // Remembered for this list.
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('list_done_expanded_$_listId'), isTrue);
    });

    testWidgets('tapping a row opens the item full screen', (tester) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await tester.tap(find.text('Feta'));
      await tester.pump();
      expect(setup.actions.calls, ['item:f']);
    });

    testWidgets('images off: no picture and no gap', (tester) async {
      SharedPreferences.setMockInitialValues({'show_article_images': false});
      await _pump(tester, _Setup());
      expect(find.byType(ArticleImage), findsNothing);
      final row = tester.widget<ItemRow>(_row('Avocados'));
      expect(row.thumb, isNull);
    });

    testWidgets('"Artikelbilder anzeigen" off in Listen: no picture', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'show_article_images': true});
      await _pump(
        tester,
        _Setup(prefs: const ListPreferences(showItemImages: false)),
      );
      await tester.pump();
      expect(tester.widget<ItemRow>(_row('Avocados')).thumb, isNull);
    });

    testWidgets('images on: Teil B picture in the row', (tester) async {
      SharedPreferences.setMockInitialValues({'show_article_images': true});
      await _pump(tester, _Setup());
      await tester.pump();
      expect(
        tester.widget<ItemRow>(_row('Avocados')).thumb,
        isA<ArticleImage>(),
      );
    });
  });

  group('check off and delete', () {
    testWidgets('check off: undo toast, row moves to "Erledigt" after 0.6 s', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await _tapCircle(tester, 'Bananen');
      expect(setup.notifier.toggles, [('b', true)]);
      expect(
        find.text(_en('list_detail_checked', {'name': 'Bananen'})),
        findsOneWidget,
      );
      // Still in its aisle for a moment.
      expect(_row('Bananen'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_row('Bananen'), findsNothing);
      expect(find.text('Bananen, Eier, Nudeln'), findsOneWidget);

      await tester.tap(find.text(_en('common_undo')));
      await tester.pump();
      expect(setup.notifier.toggles.last, ('b', false));
      expect(_row('Bananen'), findsOneWidget);
      await _settleTimers(tester);
    });

    testWidgets('full swipe hides the row; it is deleted after the undo time', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await _swipeAway(tester, 'Feta');
      expect(_row('Feta'), findsNothing);
      expect(
        find.text(_en('list_detail_deleted', {'name': 'Feta'})),
        findsOneWidget,
      );
      expect(setup.notifier.deleted, isEmpty, reason: 'undo is still possible');
      await _settleTimers(tester);
      expect(setup.notifier.deleted, ['f']);
    });

    testWidgets('"Widerrufen" brings a deleted row back unchanged', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await _swipeAway(tester, 'Feta');
      await tester.tap(find.text(_en('common_undo')));
      await tester.pump();
      expect(_row('Feta'), findsOneWidget);
      await _settleTimers(tester);
      expect(setup.notifier.deleted, isEmpty);
    });

    testWidgets('leaving the list deletes a row still waiting for undo', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await _swipeAway(tester, 'Feta');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(setup.notifier.deleted, ['f']);
      await _settleTimers(tester);
    });

    testWidgets('long press without moving opens Bearbeiten / Löschen', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hafermilch')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_en('common_edit_item')), findsOneWidget);
      await tester.tap(find.text(_en('list_detail_delete_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_row('Hafermilch'), findsNothing);
      await _settleTimers(tester);
      expect(setup.notifier.deleted, ['m']);
    });
  });

  group('add field', () {
    testWidgets('"2 Milch" adds one item with quantity 2, parsed locally', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await tester.enterText(find.byType(EditableText), '2 Milch');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(setup.notifier.added, [
        (name: 'Milch', quantity: 2.0, unit: null, autoParse: false),
      ]);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
    });

    testWidgets('"500 g Mehl" keeps the unit', (tester) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await tester.enterText(find.byType(EditableText), '500 g Mehl');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(setup.notifier.added.single.unit, 'g');
      expect(setup.notifier.added.single.quantity, 500);
    });

    testWidgets('"Milch, 6 Eier" goes in one batch with undo', (tester) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await tester.enterText(find.byType(EditableText), 'Milch, 6 Eier');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final batch = setup.repository.batches.single;
      expect(batch.map((i) => i.name), ['Milch', 'Eier']);
      expect(batch.last.quantity, 6);
      expect(setup.notifier.added, isEmpty);
      expect(
        find.text(_en('list_detail_added_many', {'count': '2'})),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(_en('common_undo')));
      await tester.pump();
      expect(setup.repository.undone, ['token-1']);
      await _settleTimers(tester);
    });

    testWidgets('sum of saved prices only with the offers module', (
      tester,
    ) async {
      await _pump(tester, _Setup(offers: true));
      // 3 × 0,99 + 1,29 (2 l count once) = 4,26.
      expect(find.text('≈ €4.26'), findsOneWidget);
    });

    testWidgets('no sum without the offers module', (tester) async {
      await _pump(tester, _Setup());
      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('focusAdd focuses the field', (tester) async {
      await _pump(tester, _Setup(), focusAdd: true);
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('no mic (owner: only with B speech service)', (tester) async {
      await _pump(tester, _Setup());
      expect(
        tester
            .widget<AddItemAccessory>(find.byType(AddItemAccessory))
            .onDictate,
        isNull,
      );
    });
  });

  group('menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(_more);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('entries for the creator, offers entry only with the module', (
      tester,
    ) async {
      await _pump(tester, _Setup());
      await openMenu(tester);
      for (final key in [
        'list_detail_menu_shop',
        'list_detail_menu_checkout',
        'list_detail_share',
        'list_detail_menu_info',
        'list_detail_menu_rename',
        'list_detail_menu_order',
        'list_detail_menu_import',
        'list_detail_menu_delete',
      ]) {
        expect(find.text(_en(key)), findsOneWidget, reason: key);
      }
      expect(find.text(_en('list_detail_menu_hide_offers')), findsNothing);
      expect(find.text(_en('list_detail_menu_leave')), findsNothing);
    });

    testWidgets('member sees "Leave list"; hide offers with the module', (
      tester,
    ) async {
      await _pump(tester, _Setup(list: _list(owner: 'u2'), offers: true));
      await openMenu(tester);
      expect(find.text(_en('list_detail_menu_leave')), findsOneWidget);
      expect(find.text(_en('list_detail_menu_delete')), findsNothing);
      await tester.tap(find.text(_en('list_detail_menu_hide_offers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListDetailScreen)),
      );
      expect(container.read(offersHiddenForListProvider(_listId)), isTrue);
    });

    testWidgets('"Angebote dieser Liste" with the module, not while hidden', (
      tester,
    ) async {
      final setup = _Setup(offers: true);
      await _pump(tester, setup);
      await openMenu(tester);
      await tester.tap(find.text(_en('list_detail_menu_offers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(setup.actions.calls, ['offers:$_listId']);

      await openMenu(tester);
      await tester.tap(find.text(_en('list_detail_menu_hide_offers')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await openMenu(tester);
      expect(find.text(_en('list_detail_menu_offers')), findsNothing);
      expect(find.text(_en('list_detail_menu_show_offers')), findsOneWidget);
    });

    testWidgets('delete list asks first, then goes to all lists', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      await openMenu(tester);
      await tester.tap(find.text(_en('list_detail_menu_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(_en('list_detail_delete_title', {'name': 'Wocheneinkauf'})),
        findsOneWidget,
      );
      await tester.tap(find.text(_en('list_detail_delete_confirm')).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(setup.actions.calls, ['delete', 'all']);
    });

    testWidgets('shopping mode, store order and info from the menu', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      for (final key in [
        'list_detail_menu_shop',
        'list_detail_menu_order',
        'list_detail_menu_info',
      ]) {
        await openMenu(tester);
        await tester.tap(find.text(_en(key)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(setup.actions.calls, ['shopping:$_listId', 'order', 'info']);
    });

    testWidgets('import runs Teil "item" for this list, then reloads', (
      tester,
    ) async {
      final setup = _Setup();
      await _pump(tester, setup);
      final loads = setup.notifier.loads;
      await openMenu(tester);
      await tester.tap(find.text(_en('list_detail_menu_import')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(setup.actions.calls, ['import:$_listId']);
      expect(setup.notifier.loads, loads + 1);
    });
  });

  group('states', () {
    testWidgets('empty list: empty state with import', (tester) async {
      final setup = _Setup(items: const AsyncData([]));
      await _pump(tester, setup);
      expect(find.text(_en('list_detail_empty_title')), findsOneWidget);
      expect(_cart, findsNothing);
      await tester.tap(find.text(_en('list_detail_menu_import')));
      await tester.pump();
      expect(setup.actions.calls, ['import:$_listId']);
    });

    testWidgets('empty after the onboarding: no empty state next to T1', (
      tester,
    ) async {
      await _pump(
        tester,
        _Setup(items: const AsyncData([]), arrival: OnboardingArrival.created),
      );
      expect(find.text(_en('list_detail_empty_title')), findsNothing);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('"Vielleicht auch": rhythm items, a tap adds with undo', (
      tester,
    ) async {
      final setup = _Setup(
        maybeAlso: const [
          MaybeAlsoSuggestion(name: 'Kaffee', everyDays: 14),
          // Open on the list already: left out.
          MaybeAlsoSuggestion(name: 'Feta', everyDays: 7),
        ],
      );
      await _pump(tester, setup);
      final row = find.text('Kaffee');
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text(_en('list_detail_maybe_also_rhythm', {'n': '14'})),
        findsOneWidget,
      );
      expect(
        find.text(_en('list_detail_maybe_also').toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(setup.repository.batches.single.single.name, 'Kaffee');
      expect(
        find.text(_en('list_detail_added_one', {'name': 'Kaffee'})),
        findsOneWidget,
      );
      await _settleTimers(tester);
    });

    testWidgets('"Vielleicht auch" off in Listen: no section', (tester) async {
      await _pump(
        tester,
        _Setup(
          maybeAlso: const [MaybeAlsoSuggestion(name: 'Kaffee', everyDays: 14)],
          prefs: const ListPreferences(suggestions: false),
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(find.text('Kaffee'), findsNothing);
    });

    testWidgets('all done: empty state with checkout, then "Erledigt"', (
      tester,
    ) async {
      final setup = _Setup(
        items: AsyncData([
          _item('e', 'Eier', checked: true, checkedAt: DateTime(2026, 1, 2)),
          _item('n', 'Nudeln', checked: true),
        ]),
      );
      await _pump(tester, setup);
      expect(find.text(_en('list_detail_all_done_title')), findsOneWidget);
      expect(
        find.text(_en('list_detail_all_done_message', {'count': '2'})),
        findsOneWidget,
      );
      expect(find.text('DONE'), findsOneWidget);
      expect(_cart, findsNothing);
      await tester.tap(find.text(_en('list_detail_menu_checkout')));
      await tester.pump();
      expect(setup.actions.calls, ['checkout']);
    });

    // A-V9: Teil B's checkout flow shows the success moment, not the list.
    testWidgets('a saved trip shows no second success moment', (tester) async {
      final setup = _Setup(
        items: AsyncData([
          _item('e', 'Eier', checked: true, checkedAt: DateTime(2026, 1, 2)),
          _item('n', 'Nudeln', checked: true),
        ]),
      );
      setup.actions.checkoutResult = true;
      await _pump(tester, setup);
      await tester.tap(find.text(_en('list_detail_menu_checkout')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_en('list_shop_saved_title')), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('first load without local data: calm placeholders', (
      tester,
    ) async {
      await _pump(tester, _Setup(items: const AsyncLoading()));
      expect(find.byType(SkeletonSection), findsNWidgets(2));
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('load error without local data: status row with retry', (
      tester,
    ) async {
      final setup = _Setup(
        items: AsyncError(Exception('offline'), StackTrace.empty),
      );
      await _pump(tester, setup);
      expect(find.text(_en('list_detail_load_error')), findsOneWidget);
      final loads = setup.notifier.loads;
      await tester.tap(find.text(_en('common_try_again')));
      await tester.pump();
      expect(setup.notifier.loads, loads + 1);
    });

    testWidgets('offline: status row, list stays usable', (tester) async {
      await _pump(tester, _Setup(offline: true));
      final status = tester.widget<StatusRow>(find.byType(StatusRow));
      expect(status.kind, StatusKind.offline);
      expect(_row('Feta'), findsOneWidget);
    });
  });

  group('Avo context', () {
    testWidgets('set to the list while open, cleared when it is left', (
      tester,
    ) async {
      final container = await _pump(tester, _Setup());
      await tester.pump();
      expect(
        container.read(avoScreenContextProvider),
        const AvoScreenContext(
          screen: 'list',
          listId: _listId,
          listName: 'Wocheneinkauf',
        ),
      );
    });

    testWidgets('cleared after leaving', (tester) async {
      final setup = _Setup();
      final container = ProviderContainer(overrides: setup.overrides);
      addTearDown(container.dispose);
      await loadLayoutFonts();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: layoutHarness(
            const LayoutCase(width: 390, scale: 1),
            setup.screen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(container.read(avoScreenContextProvider)?.screen, 'list');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      expect(container.read(avoScreenContextProvider), isNull);
    });
  });

  layoutMatrix('ListDetailScreen with aisles and "Erledigt"', (context) {
    final setup = _Setup(offers: true);
    return ProviderScope(
      overrides: setup.overrides,
      child: SizedBox(height: kLayoutHeight, child: setup.screen()),
    );
  }, checkTapTargets: true);

  layoutMatrix('ListDetailScreen empty', (context) {
    final setup = _Setup(items: const AsyncData([]));
    return ProviderScope(
      overrides: setup.overrides,
      child: SizedBox(height: kLayoutHeight, child: setup.screen()),
    );
  });

  layoutMatrix('ListDetailScreen all done, "Erledigt" open', (context) {
    final setup = _Setup(
      items: AsyncData([
        _item('e', 'Eier', checked: true),
        _item(
          'n',
          'Nudeln mit einem sehr langen Namen für die Probe',
          checked: true,
        ),
      ]),
    );
    return ProviderScope(
      overrides: setup.overrides,
      child: SizedBox(height: kLayoutHeight, child: setup.screen()),
    );
  });
}
