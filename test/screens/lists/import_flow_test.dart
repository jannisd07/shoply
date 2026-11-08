import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
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
import 'package:shoply/presentation/screens/lists/widgets/attachment_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_review_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_status_capsule.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../layout/layout_matrix.dart';

final _pick = ImportPick(Uint8List.fromList(const [1, 2, 3]));

ListImportResult _result(List<String> names) => ListImportResult(
  items: [for (final n in names) ExtractedListItem(name: n, confidence: 0.9)],
  unparsedLines: const [],
);

/// Device and Avo without platform channels or network.
class _FakePort extends ListImportPort {
  _FakePort({this.picked, this.clipboard});

  ImportPick? picked;
  Object? pickError;
  String? clipboard;
  final reads = <Future<ListImportResult> Function(CancelToken token)>[];
  final sources = <ListImportSource>[];
  var readCount = 0;
  var settingsOpened = false;

  @override
  Future<ImportPick?> pick(ListImportSource source) async {
    sources.add(source);
    final error = pickError;
    if (error != null) throw error;
    return picked;
  }

  @override
  Future<String?> readClipboard() async => clipboard;

  @override
  Future<ListImportResult> read(ImportPick pick, CancelToken cancelToken) =>
      reads[readCount++](cancelToken);

  @override
  Future<void> openSettings() async => settingsOpened = true;
}

/// A read that waits until [complete] or the token is cancelled.
class _PendingRead {
  final completer = Completer<ListImportResult>();

  Future<ListImportResult> call(CancelToken token) {
    token.whenCancel.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(const ListImportException('cancelled'));
      }
    });
    return completer.future;
  }
}

class _FakeRepo extends Fake implements ItemRepository {
  final batches = <List<NewItem>>[];

  @override
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    batches.add(items);
    return const AddItemsResult(token: 't1', items: []);
  }
}

class _FakeItems extends ItemsNotifier {
  _FakeItems(String listId) : super(_FakeRepo(), listId) {
    state = const AsyncValue.data(<ShoppingItemModel>[]);
  }

  @override
  Future<void> loadItems() async {}
}

final _anchor = GlobalKey();

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A list screen with an "import" button; [results] collects what
/// [showAttachmentSheet] resolved with.
Future<List<ListImportResult?>> _pump(
  WidgetTester tester,
  _FakePort port, {
  bool offline = false,
  List<Override> extra = const [],
  Future<void> Function(BuildContext context)? open,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final results = <ListImportResult?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        listImportPortProvider.overrideWithValue(port),
        isOfflineProvider.overrideWithValue(offline),
        ...extra,
      ],
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (context) => Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: GestureDetector(
                key: _anchor,
                onTap: () async {
                  if (open != null) return open(context);
                  results.add(
                    await showAttachmentSheet(context, plusButtonKey: _anchor),
                  );
                },
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Text('import')),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('import'));
  await _frames(tester);
  return results;
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await _frames(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('menu with four sources, no sheet', (tester) async {
    await _pump(tester, _FakePort());
    for (final label in [
      'Take photo',
      'Choose photo',
      'Choose file',
      'Paste text',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('reading shows the capsule, then resolves with the result', (
    tester,
  ) async {
    final port = _FakePort(picked: _pick);
    final read = _PendingRead();
    port.reads.add(read.call);
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose photo');

    expect(port.sources, [ListImportSource.photos]);
    expect(find.text('Reading your list …'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Taking a little longer …'), findsOneWidget);

    read.completer.complete(_result(['Milch', 'Eier']));
    await _frames(tester, 2);
    expect(find.byType(ImportStatusView), findsNothing);
    expect(results.single?.items.map((i) => i.name), ['Milch', 'Eier']);
  });

  testWidgets('cancel stops reading and resolves with null', (tester) async {
    final port = _FakePort(picked: _pick);
    port.reads.add(_PendingRead().call);
    final results = await _pump(tester, port);
    await _choose(tester, 'Take photo');
    await tester.tap(find.text('Cancel'));
    await _frames(tester, 2);
    expect(find.byType(ImportStatusView), findsNothing);
    expect(results, [null]);
  });

  testWidgets('no list found: "Other picture" opens the menu again', (
    tester,
  ) async {
    final port = _FakePort(picked: _pick, clipboard: 'Brot');
    port.reads.add(
      (_) async => throw const ListImportException('no_items_found'),
    );
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose photo');

    final status = tester.widget<StatusRow>(find.byType(StatusRow));
    expect(status.text, 'No list found in this picture.');
    await tester.tap(find.text('Other picture'));
    await _frames(tester);
    expect(find.text('Paste text'), findsOneWidget);
    await _choose(tester, 'Paste text');
    expect(results.single?.items.single.name, 'Brot');
  });

  testWidgets('network trouble: "Try again" reads the same picture', (
    tester,
  ) async {
    final port = _FakePort(picked: _pick);
    port.reads
      ..add((_) async => throw const ListImportException('network_error'))
      ..add((_) async => _result(['Milch']));
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose file');
    expect(find.text('That didn\'t work.'), findsOneWidget);
    expect(
      tester.widget<StatusRow>(find.byType(StatusRow)).kind,
      StatusKind.failed,
    );
    await tester.tap(find.text('Try again'));
    await _frames(tester);
    expect(port.readCount, 2);
    expect(port.sources, [ListImportSource.files]);
    expect(results.single?.items.single.name, 'Milch');
  });

  testWidgets('a problem goes away after a few seconds', (tester) async {
    final port = _FakePort(picked: _pick);
    port.reads.add(
      (_) async => throw const ListImportException('rate_limited'),
    );
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose photo');
    expect(
      find.text('Too many in a row. Try again in a minute.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
    await _frames(tester, 2);
    expect(find.byType(ImportStatusView), findsNothing);
    expect(results, [null]);
  });

  testWidgets('camera off: link to Settings', (tester) async {
    final port = _FakePort()..pickError = const ImportPermissionDenied();
    final results = await _pump(tester, port);
    await _choose(tester, 'Take photo');
    final status = tester.widget<StatusRow>(find.byType(StatusRow));
    expect(status.kind, StatusKind.permission);
    expect(status.text, 'Camera is off.');
    await tester.tap(find.text('Allow in Settings'));
    await _frames(tester);
    expect(port.settingsOpened, isTrue);
    expect(results, [null]);
  });

  testWidgets('a broken picker ends in a message, never a hang', (
    tester,
  ) async {
    final port = _FakePort()..pickError = StateError('picker');
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose photo');
    expect(find.text('This file can\'t be read.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await _frames(tester, 2);
    expect(results, [null]);
  });

  testWidgets('closing the picker ends quietly', (tester) async {
    final port = _FakePort();
    final results = await _pump(tester, port);
    await _choose(tester, 'Choose photo');
    expect(find.byType(ImportStatusView), findsNothing);
    expect(results, [null]);
  });

  testWidgets('pasted text is parsed locally', (tester) async {
    final port = _FakePort(clipboard: '2 Milch, Eier\nButter (laktosefrei)');
    final results = await _pump(tester, port);
    await _choose(tester, 'Paste text');
    final items = results.single!.items;
    expect(items.map((i) => i.name), ['Milch', 'Eier', 'Butter (laktosefrei)']);
    expect(items.first.quantity, 2);
    expect(items[1].quantity, isNull);
    expect(port.readCount, 0);
  });

  testWidgets('an empty clipboard says so', (tester) async {
    final results = await _pump(tester, _FakePort(clipboard: '  '));
    await _choose(tester, 'Paste text');
    expect(
      find.text('Nothing to paste. Copy your list first.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
    await _frames(tester, 2);
    expect(results, [null]);
  });

  testWidgets('offline: pictures need a connection, pasting works', (
    tester,
  ) async {
    final port = _FakePort(picked: _pick, clipboard: 'Brot');
    final results = await _pump(tester, port, offline: true);
    expect(find.text('Needs a connection'), findsNWidgets(3));
    await tester.tap(find.text('Take photo'));
    await _frames(tester);
    expect(port.sources, isEmpty);
    expect(find.text('Paste text'), findsOneWidget);
    await _choose(tester, 'Paste text');
    expect(results.single?.items.single.name, 'Brot');
  });

  testWidgets('openListImport: menu, review, batch add with undo', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final port = _FakePort(clipboard: 'Brot, Butter');
    await _pump(
      tester,
      port,
      extra: [
        itemRepositoryProvider.overrideWithValue(repo),
        itemsNotifierProvider.overrideWith((ref, id) => _FakeItems(id)),
        itemEditorListNameProvider.overrideWith((ref, id) => 'Wocheneinkauf'),
        importTargetListsProvider.overrideWith(
          (ref) => const <ShoppingListModel>[],
        ),
      ],
      open: (context) =>
          openListImport(context, listId: 'l1', anchorKey: _anchor),
    );
    await _choose(tester, 'Paste text');
    expect(find.text('2 items recognized'), findsOneWidget);
    expect(find.text('Wocheneinkauf'), findsOneWidget);
    // Pasted text, so no word about a photo.
    expect(
      find.text('The photo is only sent for reading and isn\'t saved.'),
      findsNothing,
    );
    await tester.tap(find.text('Add 2 items'));
    await _frames(tester);
    expect(repo.batches.single.map((i) => i.name), ['Brot', 'Butter']);
    expect(find.text('2 items added'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  group('capsule layout', () {
    layoutMatrix(
      'ImportStatusView busy',
      (context) => Padding(
        padding: const EdgeInsets.all(12),
        child: ImportStatusView(
          status: ImportStatus.busy(
            text: 'Taking a little longer …',
            actionLabel: 'Cancel',
            onAction: () {},
          ),
        ),
      ),
    );
    layoutMatrix(
      'ImportStatusView message',
      (context) => Padding(
        padding: const EdgeInsets.all(12),
        child: ImportStatusView(
          status: ImportStatus.message(
            kind: StatusKind.sectionError,
            text: 'Auf dem Bild wurde keine Liste erkannt.',
            actionLabel: 'Anderes Bild',
            onAction: () {},
          ),
        ),
      ),
    );
  });
}
