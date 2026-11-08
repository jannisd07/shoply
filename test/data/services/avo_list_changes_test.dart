// Avo's list changes and their "Widerrufen" (W1 review, Important 2):
// a fresh add is deleted on undo, a merged add only gets its old quantity
// back, changed data is never touched, failures are reported.
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';
import 'package:shoply/data/services/avo_list_changes.dart';

final _t0 = DateTime(2026, 11, 8, 9);

/// Lists and items in memory; [addItem] merges like `ItemRepository.addItem`.
class _Writer implements AvoListWriter {
  final Map<String, List<ShoppingItemModel>> items = {};
  final Map<String, String> names = {'w': 'Wocheneinkauf', 'd': 'Drogerie'};
  final List<String> deleted = [];
  final List<String> deletedLists = [];
  bool failWrites = false;
  int _next = 0;
  int _clock = 0;
  Set<String> moveRefused = {};

  DateTime _tick() => _t0.add(Duration(minutes: ++_clock));

  ShoppingItemModel item(
    String id,
    String name, {
    String list = 'w',
    double quantity = 1,
    bool checked = false,
  }) {
    final i = ShoppingItemModel(
      id: id,
      listId: list,
      name: name,
      quantity: quantity,
      isChecked: checked,
      createdAt: _t0,
      updatedAt: _t0,
    );
    items.putIfAbsent(list, () => []).add(i);
    return i;
  }

  void _check() {
    if (failWrites) throw Exception('offline');
  }

  void _replace(String list, ShoppingItemModel next) {
    final l = items[list]!;
    l[l.indexWhere((i) => i.id == next.id)] = next;
  }

  @override
  Future<List<ShoppingItemModel>> itemsOf(String listId) async =>
      List.of(items[listId] ?? const []);

  @override
  List<ShoppingItemModel>? shownItems(String listId) => items[listId];

  @override
  Future<void> addItem(
    String listId, {
    required String name,
    required double quantity,
    String? unit,
  }) async {
    _check();
    final list = items.putIfAbsent(listId, () => []);
    final same = list
        .where((i) => !i.isChecked && i.name == name && i.unit == unit)
        .firstOrNull;
    if (same != null) {
      _replace(
        listId,
        same.copyWith(quantity: same.quantity + quantity, updatedAt: _tick()),
      );
      return;
    }
    final now = _tick();
    list.add(
      ShoppingItemModel(
        id: 'n${_next++}',
        listId: listId,
        name: name,
        quantity: quantity,
        unit: unit,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<void> deleteItem(String listId, String itemId) async {
    _check();
    deleted.add(itemId);
    items[listId]!.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<void> updateItem(
    String listId,
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    _check();
    final i = items[listId]!.firstWhere((i) => i.id == itemId);
    _replace(
      listId,
      i.copyWith(
        quantity: (updates['quantity'] as num?)?.toDouble() ?? i.quantity,
        name: updates['name'] as String? ?? i.name,
        updatedAt: _tick(),
      ),
    );
  }

  @override
  Future<void> setChecked(String listId, String itemId, bool checked) async {
    _check();
    final i = items[listId]!.firstWhere((i) => i.id == itemId);
    _replace(listId, i.copyWith(isChecked: checked));
  }

  @override
  Future<void> moveItem(
    String fromListId,
    String toListId,
    String itemId,
  ) async {
    _check();
    if (moveRefused.contains(itemId)) throw Exception('no rights');
    final i = items[fromListId]!.firstWhere((i) => i.id == itemId);
    items[fromListId]!.remove(i);
    items.putIfAbsent(toListId, () => []).add(i.copyWith(listId: toListId));
  }

  @override
  Future<void> deleteList(String listId) async {
    _check();
    deletedLists.add(listId);
  }

  @override
  Future<void> renameList(String listId, String name) async {
    _check();
    names[listId] = name;
  }

  @override
  Future<List<ShoppingListModel>> lists() async => [
    for (final e in names.entries)
      ShoppingListModel(
        id: e.key,
        name: e.value,
        ownerId: 'u1',
        createdAt: _t0,
        updatedAt: _t0,
      ),
  ];

  @override
  void changed(Iterable<String> listIds) {}
}

void main() {
  late _Writer writer;
  late AvoListChanges changes;

  setUp(() {
    writer = _Writer();
    changes = AvoListChanges(writer);
  });

  group('add', () {
    test('a fresh add is deleted on undo', () async {
      writer.item('a', 'Brot');
      final change = await changes.add(listId: 'w', name: 'Milch', quantity: 2);
      expect(change.listName, 'Wocheneinkauf');
      expect(change.items.single.name, 'Milch');
      expect(await change.undo!(), AvoUndoResult.undone);
      expect(writer.deleted, [change.items.single.id]);
      expect(writer.items['w']!.map((i) => i.name), ['Brot']);
    });

    test('a merged add restores the old quantity and never deletes', () async {
      writer.item('m', 'Milch', quantity: 1);
      final change = await changes.add(listId: 'w', name: 'Milch', quantity: 2);
      expect(change.items.single.id, 'm');
      expect(change.items.single.quantity, 3);
      expect(await change.undo!(), AvoUndoResult.undone);
      expect(writer.deleted, isEmpty);
      final milk = writer.items['w']!.single;
      expect(milk.id, 'm');
      expect(milk.quantity, 1);
    });

    test('changed since: nothing is touched', () async {
      writer.item('m', 'Milch', quantity: 1);
      final merged = await changes.add(listId: 'w', name: 'Milch');
      final fresh = await changes.add(listId: 'w', name: 'Eier');
      await writer.updateItem('w', 'm', {'quantity': 5});
      await writer.setChecked('w', fresh.items.single.id, true);
      expect(await merged.undo!(), AvoUndoResult.changedSince);
      expect(await fresh.undo!(), AvoUndoResult.changedSince);
      expect(writer.deleted, isEmpty);
      expect(writer.items['w']!.firstWhere((i) => i.id == 'm').quantity, 5);
    });

    test('a failing undo reports failed', () async {
      final change = await changes.add(listId: 'w', name: 'Milch');
      writer.failWrites = true;
      expect(await change.undo!(), AvoUndoResult.failed);
    });

    test('a pending (offline) row has no undo and says so', () async {
      final offline = _PendingWriter();
      final change = await AvoListChanges(
        offline,
      ).add(listId: 'w', name: 'Milch');
      expect(change.pendingOffline, isTrue);
      expect(change.undo, isNull);
    });
  });

  group('check, update, move, create, rename', () {
    test('check: undo sets the previous state back', () async {
      writer
        ..item('a', 'Milch')
        ..item('b', 'Brot', checked: true);
      final before = await writer.itemsOf('w');
      await writer.setChecked('w', 'a', true);
      final change = await changes.checked(
        listId: 'w',
        before: before,
        itemIds: ['a', 'b'],
        checked: true,
      );
      expect(change.count, 2);
      expect(await change.undo!(), AvoUndoResult.undone);
      final byId = {for (final i in writer.items['w']!) i.id: i.isChecked};
      expect(byId, {'a': false, 'b': true});
    });

    test('update: undo restores the old quantity', () async {
      final milk = writer.item('a', 'Milch', quantity: 2);
      await writer.updateItem('w', 'a', {'quantity': 3});
      final change = (await changes.updated(
        listId: 'w',
        before: milk,
        updates: {'quantity': 3.0},
      ))!;
      expect(change.previousQuantity, 2);
      expect(change.newQuantity, 3);
      expect(await change.undo!(), AvoUndoResult.undone);
      expect(writer.items['w']!.single.quantity, 2);
    });

    test('move: a refused item is counted and can be tried again', () async {
      writer
        ..item('a', 'Zahnpasta')
        ..item('b', 'Seife');
      writer.moveRefused = {'b'};
      final result = await changes.move(
        fromListId: 'w',
        toListId: 'd',
        itemIds: ['a', 'b'],
      );
      final change = result.change!;
      expect(result.moved, 1);
      expect(change.count, 1);
      expect(change.failedCount, 1);
      expect(change.fromListName, 'Wocheneinkauf');

      writer.moveRefused = {};
      final retried = (await change.retryFailed!())!;
      expect(retried.count, 2);
      expect(retried.failedCount, 0);
      expect(await retried.undo!(), AvoUndoResult.undone);
      expect(writer.items['w']!.map((i) => i.id).toSet(), {'a', 'b'});
    });

    test('create: undo only while the list is empty', () async {
      final list = ShoppingListModel(
        id: 'p',
        name: 'Party',
        ownerId: 'u1',
        createdAt: _t0,
        updatedAt: _t0,
      );
      final change = changes.created(list);
      writer.item('x', 'Chips', list: 'p');
      expect(await change.undo!(), AvoUndoResult.changedSince);
      writer.items['p']!.clear();
      expect(await change.undo!(), AvoUndoResult.undone);
      expect(writer.deletedLists, ['p']);
    });

    test('rename: undo restores the old name unless renamed again', () async {
      writer.names['w'] = 'Grillabend';
      final change = changes.renamed('w', 'Party', 'Grillabend');
      expect(await change.undo!(), AvoUndoResult.undone);
      expect(writer.names['w'], 'Party');

      writer.names['w'] = 'Etwas anderes';
      final again = changes.renamed('w', 'Party', 'Grillabend');
      expect(await again.undo!(), AvoUndoResult.changedSince);
    });
  });
}

/// Offline: the add only shows a pending row.
class _PendingWriter extends _Writer {
  @override
  Future<void> addItem(
    String listId, {
    required String name,
    required double quantity,
    String? unit,
  }) async {
    items
        .putIfAbsent(listId, () => [])
        .add(
          ShoppingItemModel(
            id: 'pending-1',
            listId: listId,
            name: name,
            quantity: quantity,
            createdAt: _t0,
            updatedAt: _t0,
          ),
        );
  }

  @override
  Future<List<ShoppingItemModel>> itemsOf(String listId) async => const [];
}
