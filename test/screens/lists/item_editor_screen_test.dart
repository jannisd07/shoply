import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/item_editor_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_editor_parts.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

const _listId = 'l1';
final _now = DateTime.now();

ShoppingItemModel _item({
  String id = 'i1',
  String name = 'Avocados',
  double quantity = 3,
  String? unit,
  String? category = 'fruits_vegetables',
  String? notes,
  String? addedBy = 'lena',
}) => ShoppingItemModel(
  id: id,
  listId: _listId,
  name: name,
  quantity: quantity,
  unit: unit,
  categoryId: category,
  notes: notes,
  addedBy: addedBy,
  createdAt: _now,
  updatedAt: _now,
);

class _FakeItemRepository extends Fake implements ItemRepository {}

typedef _Added = ({
  String name,
  double quantity,
  String? unit,
  String? category,
  String? notes,
  bool autoParse,
});

/// Records writes instead of sending them; never loads from the server.
class _FakeItems extends ItemsNotifier {
  _FakeItems(List<ShoppingItemModel> items, {this.fail = false})
    : super(_FakeItemRepository(), _listId) {
    state = AsyncValue.data(items);
  }

  bool fail;
  final updates = <Map<String, dynamic>>[];
  final added = <_Added>[];
  final deleted = <String>[];

  @override
  Future<void> loadItems() async {}

  @override
  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    if (fail) throw Exception('offline');
    this.updates.add(updates);
  }

  @override
  Future<void> deleteItem(String itemId) async => deleted.add(itemId);

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
    if (fail) throw Exception('offline');
    added.add((
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      notes: notes,
      autoParse: autoParse,
    ));
  }
}

List<Override> _overrides(_FakeItems items, {bool offline = false}) => [
  itemsNotifierProvider.overrideWith((ref, id) => items),
  isOfflineProvider.overrideWithValue(offline),
  itemEditorListNameProvider.overrideWith((ref, id) => 'Wocheneinkauf'),
  itemAuthorNameProvider.overrideWith((ref, id) async => 'Lena'),
  itemEditorCustomCategoriesProvider.overrideWith((ref, id) async => []),
  authUserIdProvider.overrideWithValue('me'),
  currentUserProvider.overrideWith((ref) async => null),
];

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A screen with "open" that runs [open]; the editor is pushed from there.
Future<void> _pumpOpener(
  WidgetTester tester,
  List<Override> overrides,
  Future<void> Function(BuildContext context) open,
) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _frames(tester);
}

Future<void> _openEdit(
  WidgetTester tester,
  _FakeItems items,
  ShoppingItemModel item, {
  bool offline = false,
}) => _pumpOpener(
  tester,
  _overrides(items, offline: offline),
  (context) => openItemEditor(context, listId: _listId, item: item),
);

Finder get _editor => find.byType(ItemEditorScreen);

Future<void> _tapDone(WidgetTester tester, [String label = 'Done']) async {
  await tester.tap(find.text(label));
  await _frames(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ItemEditorScreen edit', () {
    testWidgets('D2 frame: back, title, Done, name, subtitle, rows', (
      tester,
    ) async {
      final item = _item();
      await _openEdit(tester, _FakeItems([item]), item);

      expect(find.text('Item'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Avocados'), findsOneWidget);
      expect(
        find.text('Fruits & Vegetables · in Wocheneinkauf'),
        findsOneWidget,
      );
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.textContaining('Lena · today'), findsOneWidget);
      expect(find.text('Delete item'), findsOneWidget);

      final editor = tester.widget<FullScreenEditor>(
        find.byType(FullScreenEditor),
      );
      expect(editor.leading, EditorLeading.back);
      expect(editor.leadingLabel, 'Back to Wocheneinkauf');
      expect(editor.dirty, isFalse);

      final image = tester.widget<ArticleImage>(find.byType(ArticleImage));
      expect(image.size, 88);
      expect(image.radius, 20);
      expect(find.byType(ItemOfferCard), findsOneWidget);
    });

    testWidgets('Done without changes closes without writing', (tester) async {
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await _tapDone(tester);
      expect(_editor, findsNothing);
      expect(items.updates, isEmpty);
    });

    testWidgets('stepper changes the quantity, Done saves only that', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.tap(find.bySemanticsLabel('Increase'));
      await _frames(tester, 3);
      expect(
        tester.widget<FullScreenEditor>(find.byType(FullScreenEditor)).dirty,
        isTrue,
      );
      await _tapDone(tester);
      expect(items.updates, [
        {'quantity': 4.0},
      ]);
      expect(_editor, findsNothing);
      handle.dispose();
    });

    testWidgets('g steps by 50', (tester) async {
      final handle = tester.ensureSemantics();
      final item = _item(name: 'Mehl', quantity: 500, unit: 'g');
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.tap(find.bySemanticsLabel('Increase'));
      await _frames(tester, 3);
      await _tapDone(tester);
      expect(items.updates.single['quantity'], 550);
      handle.dispose();
    });

    testWidgets('a fractional amount is a number field with comma', (
      tester,
    ) async {
      final item = _item(name: 'Kartoffeln', quantity: 1.5, unit: 'kg');
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      expect(find.text('1.5'), findsOneWidget);
      await tester.enterText(find.text('1.5'), '2,5');
      await _frames(tester, 2);
      await _tapDone(tester);
      expect(items.updates.single['quantity'], 2.5);
    });

    testWidgets('unit segments and the "More" menu', (tester) async {
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      expect(find.text('pc.'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      await tester.tap(find.text('More'));
      await _frames(tester);
      expect(find.text('Bottle'), findsOneWidget);
      await tester.tap(find.text('Pack'));
      await _frames(tester);
      expect(find.text('More'), findsNothing);
      expect(find.text('pack'), findsOneWidget);

      // Tapping the selected fourth segment opens the menu again.
      await tester.tap(find.text('pack'));
      await _frames(tester);
      expect(find.text('Bottle'), findsOneWidget);
      await tester.tap(find.text('Bottle'));
      await _frames(tester);

      await tester.tap(find.text('g'));
      await _frames(tester);
      await tester.tap(find.text('kg'));
      await _frames(tester);
      await _tapDone(tester);
      expect(items.updates.single['unit'], 'kg');
    });

    testWidgets('category menu marks the current one and saves the id', (
      tester,
    ) async {
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.tap(find.text('Category'));
      await _frames(tester);
      expect(find.text('Dairy Products'), findsOneWidget);
      await tester.tap(find.text('Dairy Products'));
      await _frames(tester);
      expect(find.text('Dairy Products · in Wocheneinkauf'), findsOneWidget);
      await _tapDone(tester);
      expect(items.updates, [
        {'category_id': 'dairy'},
      ]);
    });

    testWidgets('name and note are saved trimmed', (tester) async {
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.enterText(find.text('Avocados'), 'Avocados reif ');
      await tester.enterText(
        find.byType(CupertinoTextField).last,
        ' für Guacamole',
      );
      await _frames(tester, 2);
      await _tapDone(tester);
      expect(items.updates.single, {
        'name': 'Avocados reif',
        'notes': 'für Guacamole',
      });
    });

    testWidgets('an empty name disables Done', (tester) async {
      final item = _item();
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.enterText(find.text('Avocados'), '  ');
      await _frames(tester, 2);
      expect(
        tester
            .widget<FullScreenEditor>(find.byType(FullScreenEditor))
            .doneEnabled,
        isFalse,
      );
      await tester.tap(find.text('Done'));
      await _frames(tester, 2);
      expect(_editor, findsOneWidget);
      expect(items.updates, isEmpty);
    });

    testWidgets('back with changes asks before discarding', (tester) async {
      final handle = tester.ensureSemantics();
      final item = _item();
      await _openEdit(tester, _FakeItems([item]), item);
      await tester.enterText(find.text('Avocados'), 'Avocado');
      await _frames(tester, 2);
      await tester.tap(find.bySemanticsLabel('Back to Wocheneinkauf'));
      await _frames(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await _frames(tester);
      expect(_editor, findsNothing);
      handle.dispose();
    });

    testWidgets('a failed save stays open with a status and retry', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final item = _item();
      final items = _FakeItems([item], fail: true);
      await _openEdit(tester, items, item);
      await tester.tap(find.bySemanticsLabel('Increase'));
      await _frames(tester, 3);
      await _tapDone(tester);
      expect(_editor, findsOneWidget);
      final status = tester.widget<StatusRow>(find.byType(StatusRow));
      expect(status.kind, StatusKind.failed);
      expect(status.text, 'Not saved. Check your connection.');

      items.fail = false;
      await tester.tap(find.text('Try again'));
      await _frames(tester);
      expect(items.updates, [
        {'quantity': 4.0},
      ]);
      expect(_editor, findsNothing);
      handle.dispose();
    });

    testWidgets('offline shows the status, editing stays possible', (
      tester,
    ) async {
      final item = _item();
      await _openEdit(tester, _FakeItems([item]), item, offline: true);
      final status = tester.widget<StatusRow>(find.byType(StatusRow));
      expect(status.kind, StatusKind.offline);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('deleted by someone else: status and "Add again"', (
      tester,
    ) async {
      final item = _item();
      final items = _FakeItems(const []);
      await _openEdit(tester, items, item);
      expect(find.text('This item was deleted.'), findsOneWidget);
      expect(find.text('Delete item'), findsNothing);
      await _tapDone(tester, 'Add again');
      expect(items.added.single.name, 'Avocados');
      expect(items.added.single.autoParse, isFalse);
      expect(_editor, findsNothing);
    });

    testWidgets('delete closes at once and offers undo', (tester) async {
      final item = _item(notes: 'reif');
      final items = _FakeItems([item]);
      await _openEdit(tester, items, item);
      await tester.tap(find.text('Delete item'));
      await _frames(tester);
      expect(_editor, findsNothing);
      expect(items.deleted, ['i1']);
      expect(find.text('Avocados deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await _frames(tester);
      expect(items.added.single.name, 'Avocados');
      expect(items.added.single.quantity, 3);
      expect(items.added.single.notes, 'reif');
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('added by me reads "You"', (tester) async {
      final item = _item(addedBy: 'me');
      await _openEdit(tester, _FakeItems([item]), item);
      expect(find.textContaining('You · today'), findsOneWidget);
    });
  });

  group('ItemEditorScreen add', () {
    testWidgets('prefill is parsed like the add field', (tester) async {
      final items = _FakeItems(const []);
      await _pumpOpener(
        tester,
        _overrides(items),
        (context) =>
            openItemEditor(context, listId: _listId, prefill: '2 Milch'),
      );
      final editor = tester.widget<FullScreenEditor>(
        find.byType(FullScreenEditor),
      );
      expect(editor.leading, EditorLeading.close);
      expect(find.text('New item'), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Delete item'), findsNothing);
      expect(find.textContaining('Added by'), findsNothing);
      expect(find.text('Automatic'), findsOneWidget);

      await _tapDone(tester, 'Add');
      expect(items.added.single.name, 'Milch');
      expect(items.added.single.quantity, 2);
      expect(items.added.single.category, isNull);
      expect(items.added.single.autoParse, isFalse);
      expect(_editor, findsNothing);
    });

    testWidgets('an empty new item cannot be added', (tester) async {
      final items = _FakeItems(const []);
      await _pumpOpener(
        tester,
        _overrides(items),
        (context) => openItemEditor(context, listId: _listId),
      );
      expect(
        tester
            .widget<FullScreenEditor>(find.byType(FullScreenEditor))
            .doneEnabled,
        isFalse,
      );
    });
  });

  group('ItemEditorScreen draft', () {
    testWidgets('returns the edited draft without writing', (tester) async {
      final items = _FakeItems(const []);
      ItemDraft? result;
      await _pumpOpener(tester, _overrides(items), (context) async {
        result = await openItemDraftEditor(
          context,
          listId: _listId,
          draft: const ItemDraft(name: 'Schmand', quantity: 2, unit: 'pack'),
        );
      });
      expect(find.text('Note'), findsNothing);
      expect(find.text('Delete item'), findsNothing);
      expect(find.text('pack'), findsOneWidget);
      await tester.enterText(find.text('Schmand'), 'Saure Sahne');
      await _frames(tester, 2);
      await _tapDone(tester);
      expect(result?.name, 'Saure Sahne');
      expect(result?.quantity, 2);
      expect(result?.unit, 'pack');
      expect(items.added, isEmpty);
    });
  });

  group('helpers', () {
    test('numbers with comma', () {
      expect(formatItemNumber(2, 'de'), '2');
      expect(formatItemNumber(1.5, 'de'), '1,5');
      expect(formatItemNumber(1.25, 'en'), '1.25');
      expect(parseItemNumber('1,5'), 1.5);
      expect(parseItemNumber('0'), isNull);
      expect(parseItemNumber('x'), isNull);
    });

    test('units', () {
      expect(ItemUnits.normalize('pcs'), isNull);
      expect(ItemUnits.normalize(' KG '), 'kg');
      expect(ItemUnits.stepOf('g'), 50);
      expect(ItemUnits.stepOf('ml'), 50);
      expect(ItemUnits.stepOf(null), 1);
    });

    testWidgets('added when', (tester) async {
      final now = DateTime(2026, 11, 7, 10, 42); // a Saturday
      final texts = <String>[];
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('de'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              texts
                ..clear()
                ..addAll([
                  itemAddedWhen(
                    context,
                    DateTime(2026, 11, 7, 9, 15),
                    now: now,
                  ),
                  itemAddedWhen(context, DateTime(2026, 11, 6, 20), now: now),
                  itemAddedWhen(context, DateTime(2026, 11, 3, 8), now: now),
                  itemAddedWhen(context, DateTime(2026, 10, 20), now: now),
                ]);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(texts, ['heute, 9:15', 'gestern', 'Dienstag', '20.10.']);
    });
  });

  group('layout', () {
    Widget host(Widget child, _FakeItems items, {bool offline = false}) =>
        ProviderScope(
          overrides: _overrides(items, offline: offline),
          child: SizedBox.expand(child: child),
        );

    final long = _item(
      name: 'Laktosefreie Bio-Vollmilch 3,8 % Fett aus der Region',
      notes: 'die mit dem grünen Deckel, nicht die H-Milch',
    );
    layoutMatrix(
      'ItemEditorScreen edit',
      (context) => host(
        ItemEditorScreen(listId: _listId, item: long),
        _FakeItems([long]),
      ),
    );
    final other = _item(name: 'Mineralwasser', quantity: 6, unit: 'bottle');
    layoutMatrix(
      'ItemEditorScreen other unit, offline',
      (context) => host(
        ItemEditorScreen(listId: _listId, item: other),
        _FakeItems([other]),
        offline: true,
      ),
    );
    layoutMatrix(
      'ItemEditorScreen add',
      (context) => host(
        const ItemEditorScreen(listId: _listId, prefill: '500 g Mehl'),
        _FakeItems(const []),
      ),
    );
    final fraction = _item(name: 'Kartoffeln', quantity: 1.5, unit: 'kg');
    layoutMatrix(
      'ItemEditorScreen fractional, gone',
      (context) => host(
        ItemEditorScreen(listId: _listId, item: fraction),
        _FakeItems(const []),
      ),
    );
  });
}
