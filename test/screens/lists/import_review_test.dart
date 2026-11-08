import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/presentation/screens/lists/item_editor_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_review_sheet.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../layout/layout_matrix.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ListImportResult _note() => ListImportResult(
  items: [
    ExtractedListItem(
      name: 'Kartoffeln',
      quantity: 1,
      unit: 'kg',
      confidence: 0.95,
    ),
    ExtractedListItem(
      name: 'Zwiebeln',
      quantity: 3,
      confidence: 0.9,
      categoryId: 'fruits_vegetables',
    ),
    ExtractedListItem(name: 'Milch', confidence: 0.9, categoryId: 'dairy'),
    ExtractedListItem(name: 'Schmand', confidence: 0.5),
  ],
  unparsedLines: const ['für Sonntag', 'Oma anrufen'],
);

ShoppingListModel _list(String id, String name) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'me',
  createdAt: _at,
  updatedAt: _at,
);

class _FakeRepo extends Fake implements ItemRepository {
  bool fail = false;
  final batches = <(String, List<NewItem>)>[];
  final undone = <String>[];

  @override
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    if (fail) throw Exception('offline');
    batches.add((listId, items));
    return const AddItemsResult(token: 'batch-1', items: []);
  }

  @override
  Future<void> undoAddItems(String token) async => undone.add(token);
}

class _FakeItems extends ItemsNotifier {
  _FakeItems(String listId, List<ShoppingItemModel> items)
    : super(_FakeRepo(), listId) {
    state = AsyncValue.data(items);
  }

  @override
  Future<void> loadItems() async {}
}

List<Override> _overrides({
  required _FakeRepo repo,
  bool offline = false,
  List<ShoppingItemModel> onList = const [],
}) => [
  itemRepositoryProvider.overrideWithValue(repo),
  itemsNotifierProvider.overrideWith((ref, id) => _FakeItems(id, onList)),
  isOfflineProvider.overrideWithValue(offline),
  itemEditorListNameProvider.overrideWith(
    (ref, id) => id == 'l2' ? 'REWE' : 'Wocheneinkauf',
  ),
  importTargetListsProvider.overrideWith(
    (ref) => [_list('l1', 'Wocheneinkauf'), _list('l2', 'REWE')],
  ),
  itemEditorCustomCategoriesProvider.overrideWith((ref, id) async => []),
  itemAuthorNameProvider.overrideWith((ref, id) async => null),
  authUserIdProvider.overrideWithValue('me'),
  currentUserProvider.overrideWith((ref) async => null),
];

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the review of [result]; [results] collects what it resolved with.
Future<List<List<ExtractedListItem>?>> _open(
  WidgetTester tester, {
  ListImportResult? result,
  String? listId,
  _FakeRepo? repo,
  bool offline = false,
  List<ShoppingItemModel> onList = const [],
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <List<ExtractedListItem>?>[];
  final note = result ?? _note();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        repo: repo ?? _FakeRepo(),
        offline: offline,
        onList: onList,
      ),
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () async => results.add(
                await showImportReviewSheet(
                  context,
                  result: note,
                  listId: listId,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _frames(tester);
  return results;
}

Finder get _review => find.byType(ImportReviewScreen);

AppButton _addButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byType(AppButton).last);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('title, rows, unsure hint, not recognized, photo note', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('4 items recognized'), findsOneWidget);
    expect(find.text('RECOGNIZED'), findsOneWidget);
    expect(find.text('Kartoffeln'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Fruits & Vegetables'), findsOneWidget);
    expect(find.text('Please check'), findsOneWidget);
    expect(find.text('NOT RECOGNIZED (2)'), findsOneWidget);
    expect(find.text('für Sonntag'), findsOneWidget);
    expect(
      find.text('The photo is only sent for reading and isn\'t saved.'),
      findsOneWidget,
    );
    expect(find.text('Add 4 items'), findsOneWidget);
    expect(
      tester.widget<FullScreenEditor>(find.byType(FullScreenEditor)).leading,
      EditorLeading.close,
    );
    // Without a list nothing is added here.
    expect(find.text('To list'), findsNothing);
  });

  testWidgets('deselecting counts down; the kept items come back', (
    tester,
  ) async {
    final results = await _open(tester);
    await tester.tap(find.byType(CheckCircle).at(2)); // Milch
    await _frames(tester, 3);
    expect(find.text('Add 3 items'), findsOneWidget);
    await tester.tap(find.text('Add 3 items'));
    await _frames(tester);
    expect(_review, findsNothing);
    expect(results.single!.map((i) => i.name), [
      'Kartoffeln',
      'Zwiebeln',
      'Schmand',
    ]);
    expect(results.single!.first.unit, 'kg');
  });

  testWidgets('nothing selected disables adding', (tester) async {
    await _open(
      tester,
      result: ListImportResult(
        items: [ExtractedListItem(name: 'Brot')],
        unparsedLines: const [],
      ),
    );
    expect(find.text('1 item recognized'), findsOneWidget);
    expect(find.text('Add 1 item'), findsOneWidget);
    await tester.tap(find.byType(CheckCircle));
    await _frames(tester, 3);
    expect(find.text('Add 0 items'), findsOneWidget);
    expect(_addButton(tester).onPressed, isNull);
  });

  testWidgets('a row opens the item full screen and takes its changes', (
    tester,
  ) async {
    final results = await _open(tester);
    await tester.tap(find.text('Schmand'));
    await _frames(tester);
    expect(find.byType(ItemEditorScreen), findsOneWidget);
    await tester.enterText(find.text('Schmand').last, 'Saure Sahne');
    await _frames(tester, 2);
    await tester.tap(find.text('Done'));
    await _frames(tester);
    expect(find.byType(ItemEditorScreen), findsNothing);
    expect(find.text('Saure Sahne'), findsOneWidget);

    await tester.tap(find.text('Add 4 items'));
    await _frames(tester);
    expect(results.single!.last.name, 'Saure Sahne');
  });

  testWidgets('a line that was not recognized can be taken over', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('für Sonntag'));
    await _frames(tester);
    expect(find.byType(ItemEditorScreen), findsOneWidget);
    await tester.tap(find.text('Done'));
    await _frames(tester);
    expect(find.text('NOT RECOGNIZED (1)'), findsOneWidget);
    expect(find.text('Add 5 items'), findsOneWidget);
  });

  testWidgets('closing after changes asks first', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    await tester.tap(find.byType(CheckCircle).first);
    await _frames(tester, 3);
    await tester.tap(find.bySemanticsLabel('Close'));
    await _frames(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    handle.dispose();
  });

  group('with a list', () {
    testWidgets('adds in one batch, says so, and undoes', (tester) async {
      final repo = _FakeRepo();
      final milk = ShoppingItemModel(
        id: 'm',
        listId: 'l1',
        name: 'milch',
        createdAt: _at,
        updatedAt: _at,
      );
      final results = await _open(
        tester,
        listId: 'l1',
        repo: repo,
        onList: [milk],
      );
      expect(find.text('To list'), findsOneWidget);
      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(
        find.text('Dairy Products · Already on the list, quantity is added'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add 4 items'));
      await _frames(tester);
      expect(_review, findsNothing);
      final (listId, items) = repo.batches.single;
      expect(listId, 'l1');
      expect(items.map((i) => i.name), [
        'Kartoffeln',
        'Zwiebeln',
        'Milch',
        'Schmand',
      ]);
      expect(items.first.quantity, 1);
      expect(items.first.unit, 'kg');
      expect(items[1].category, 'fruits_vegetables');
      expect(results.single, hasLength(4));

      expect(find.text('4 items added'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await _frames(tester);
      expect(repo.undone, ['batch-1']);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('the target list can be changed', (tester) async {
      final repo = _FakeRepo();
      await _open(tester, listId: 'l1', repo: repo);
      await tester.tap(find.text('To list'));
      await _frames(tester);
      await tester.tap(find.text('REWE'));
      await _frames(tester);
      await tester.tap(find.text('Add 4 items'));
      await _frames(tester);
      expect(repo.batches.single.$1, 'l2');
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('a failed add stays open with retry', (tester) async {
      final repo = _FakeRepo()..fail = true;
      await _open(tester, listId: 'l1', repo: repo);
      await tester.tap(find.text('Add 4 items'));
      await _frames(tester);
      expect(_review, findsOneWidget);
      final status = tester.widget<StatusRow>(find.byType(StatusRow));
      expect(status.kind, StatusKind.failed);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await _frames(tester);
      expect(repo.batches, hasLength(1));
      expect(_review, findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('offline says that adding needs a connection', (tester) async {
      await _open(tester, listId: 'l1', offline: true);
      expect(find.text('Offline. Adding needs a connection.'), findsOneWidget);
    });
  });

  group('layout', () {
    Widget host(Widget child) => ProviderScope(
      overrides: _overrides(repo: _FakeRepo()),
      child: SizedBox.expand(child: child),
    );
    final long = ListImportResult(
      items: [
        ExtractedListItem(
          name: 'Laktosefreie Bio-Vollmilch aus der Region',
          quantity: 1.5,
          unit: 'l',
          confidence: 0.5,
          categoryId: 'dairy',
        ),
        ExtractedListItem(name: 'Hackfleisch', quantity: 500, unit: 'g'),
        ExtractedListItem(name: 'Äpfel', quantity: 6),
      ],
      unparsedLines: const ['für Sonntag, wenn Oma kommt'],
    );
    layoutMatrix(
      'ImportReviewScreen',
      (context) => host(ImportReviewScreen(result: long)),
    );
    layoutMatrix(
      'ImportReviewScreen with a list',
      (context) => host(ImportReviewScreen(result: long, listId: 'l1')),
    );
  });
}
