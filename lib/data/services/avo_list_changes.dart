import 'package:flutter/foundation.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_models.dart';

/// What Avo's list changes and their "Widerrufen" need from the app. The
/// service backs it with the person's providers; tests use an in-memory fake.
abstract interface class AvoListWriter {
  /// The items of [listId] as the server has them now.
  Future<List<ShoppingItemModel>> itemsOf(String listId);

  /// The items of [listId] the app shows right after a write (optimistic
  /// state, may hold `pending-` rows while offline); null when unknown.
  List<ShoppingItemModel>? shownItems(String listId);

  /// Puts an item on the list the way the list screen does. An unchecked
  /// item with the same name and unit gets the quantity added instead.
  Future<void> addItem(
    String listId, {
    required String name,
    required double quantity,
    String? unit,
  });

  Future<void> deleteItem(String listId, String itemId);
  Future<void> updateItem(
    String listId,
    String itemId,
    Map<String, dynamic> updates,
  );
  Future<void> setChecked(String listId, String itemId, bool checked);

  /// Moves one item; throws when the person may not write the target.
  Future<void> moveItem(String fromListId, String toListId, String itemId);

  Future<void> deleteList(String listId);
  Future<void> renameList(String listId, String name);

  /// The person's lists as the server has them now.
  Future<List<ShoppingListModel>> lists();

  /// Refreshes the list overview and open lists after a change.
  void changed(Iterable<String> listIds);
}

/// Builds the answer cards of Avo's list changes and takes them back.
///
/// Every undo first checks that the data is still as Avo left it; if
/// someone changed it since, nothing is touched ("Inzwischen geändert").
/// An add that merged into an item that was already on the list is taken
/// back by restoring the old quantity, never by deleting that item.
class AvoListChanges {
  const AvoListChanges(this.writer);

  final AvoListWriter writer;

  Future<List<ShoppingItemModel>> _items(String listId) async {
    try {
      return await writer.itemsOf(listId);
    } catch (e) {
      debugPrint('⚠️ [AVO] Items not loaded: $e');
      return const [];
    }
  }

  Future<String> listName(String listId) async {
    try {
      for (final l in await writer.lists()) {
        if (l.id == listId) return l.name;
      }
    } catch (e) {
      debugPrint('⚠️ [AVO] List name not loaded: $e');
    }
    return '';
  }

  /// The newest saved (not pending) item called [name].
  @visibleForTesting
  static ShoppingItemModel? newestNamed(
    List<ShoppingItemModel>? items,
    String name,
  ) {
    ShoppingItemModel? best;
    final wanted = name.trim().toLowerCase();
    for (final item in items ?? const <ShoppingItemModel>[]) {
      if (item.id.startsWith('pending-')) continue;
      if (item.name.trim().toLowerCase() != wanted) continue;
      if (best == null || item.updatedAt.isAfter(best.updatedAt)) best = item;
    }
    return best;
  }

  // ------------------------------------------------------------------ add

  /// Puts one item on [listId] and describes it for the card.
  Future<AvoListChange> add({
    required String listId,
    required String name,
    double quantity = 1,
    String? unit,
  }) async {
    final before = await _items(listId);
    await writer.addItem(listId, name: name, quantity: quantity, unit: unit);
    final shown = writer.shownItems(listId);
    final saved =
        newestNamed(shown, name) ?? newestNamed(await _items(listId), name);
    final wanted = name.trim().toLowerCase();
    final pending =
        saved == null &&
        (shown ?? const <ShoppingItemModel>[]).any(
          (i) =>
              i.id.startsWith('pending-') &&
              i.name.trim().toLowerCase() == wanted,
        );
    final previous = saved == null
        ? null
        : before.where((i) => i.id == saved.id).firstOrNull;
    final now = DateTime.now();
    return AvoListChange(
      kind: AvoListChangeKind.added,
      listId: listId,
      listName: await listName(listId),
      count: 1,
      pendingOffline: pending,
      items: [
        saved ??
            ShoppingItemModel(
              id: '',
              listId: listId,
              name: name,
              quantity: quantity,
              unit: unit,
              createdAt: now,
              updatedAt: now,
            ),
      ],
      undo: saved == null
          ? null
          : previous != null
          ? () => undoMerged(listId, saved, previous.quantity)
          : () => undoAdded(listId, saved),
    );
  }

  /// Deletes a row Avo created, if it is unchanged.
  Future<AvoUndoResult> undoAdded(
    String listId,
    ShoppingItemModel added,
  ) async {
    try {
      final current = (await writer.itemsOf(
        listId,
      )).where((i) => i.id == added.id).firstOrNull;
      if (current == null ||
          current.isChecked ||
          current.quantity != added.quantity ||
          current.name != added.name) {
        return AvoUndoResult.changedSince;
      }
      await writer.deleteItem(listId, added.id);
      writer.changed([listId]);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo add failed: $e');
      return AvoUndoResult.failed;
    }
  }

  /// Sets a merged row back to the quantity it had before Avo's add.
  Future<AvoUndoResult> undoMerged(
    String listId,
    ShoppingItemModel merged,
    double previousQuantity,
  ) async {
    try {
      final current = (await writer.itemsOf(
        listId,
      )).where((i) => i.id == merged.id).firstOrNull;
      if (current == null ||
          current.isChecked ||
          current.quantity != merged.quantity) {
        return AvoUndoResult.changedSince;
      }
      await writer.updateItem(listId, merged.id, {
        'quantity': previousQuantity,
      });
      writer.changed([listId]);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo merge failed: $e');
      return AvoUndoResult.failed;
    }
  }

  // --------------------------------------------------------------- check

  /// The card for [itemIds] set to [checked]; [before] are the items as they
  /// were before the change.
  Future<AvoListChange> checked({
    required String listId,
    required List<ShoppingItemModel> before,
    required List<String> itemIds,
    required bool checked,
  }) async {
    final byId = {for (final i in before) i.id: i};
    final previous = {
      for (final id in itemIds)
        if (byId[id] != null) id: byId[id]!.isChecked,
    };
    return AvoListChange(
      kind: checked ? AvoListChangeKind.checked : AvoListChangeKind.unchecked,
      listId: listId,
      listName: await listName(listId),
      count: itemIds.length,
      items: [
        for (final id in itemIds)
          if (byId[id] != null) byId[id]!.copyWith(isChecked: checked),
      ],
      undo: previous.isEmpty
          ? null
          : () => undoChecked(listId, previous, checked),
    );
  }

  /// Sets every item in [previous] (id → checked before Avo) back, if each
  /// one still has the state [setTo] Avo gave it.
  Future<AvoUndoResult> undoChecked(
    String listId,
    Map<String, bool> previous,
    bool setTo,
  ) async {
    try {
      final byId = {for (final i in await writer.itemsOf(listId)) i.id: i};
      for (final id in previous.keys) {
        final current = byId[id];
        if (current == null || current.isChecked != setTo) {
          return AvoUndoResult.changedSince;
        }
      }
      await Future.wait([
        for (final e in previous.entries)
          if (e.value != setTo) writer.setChecked(listId, e.key, e.value),
      ]);
      writer.changed([listId]);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo check failed: $e');
      return AvoUndoResult.failed;
    }
  }

  // -------------------------------------------------------------- update

  Future<AvoListChange?> updated({
    required String listId,
    required ShoppingItemModel? before,
    required Map<String, dynamic> updates,
  }) async {
    if (before == null) return null;
    final old = before.toJson();
    final previous = {for (final k in updates.keys) k: old[k]};
    final after = before.copyWith(
      name: updates['name'] as String? ?? before.name,
      quantity: (updates['quantity'] as num?)?.toDouble() ?? before.quantity,
      unit: updates.containsKey('unit')
          ? updates['unit'] as String?
          : before.unit,
      notes: updates.containsKey('notes')
          ? updates['notes'] as String?
          : before.notes,
    );
    final quantity = updates.containsKey('quantity');
    return AvoListChange(
      kind: AvoListChangeKind.updated,
      listId: listId,
      listName: await listName(listId),
      count: 1,
      items: [after],
      itemName: after.name,
      previousQuantity: quantity ? before.quantity : null,
      newQuantity: quantity ? after.quantity : null,
      undo: () => undoUpdated(listId, before.id, updates, previous),
    );
  }

  Future<AvoUndoResult> undoUpdated(
    String listId,
    String itemId,
    Map<String, dynamic> applied,
    Map<String, dynamic> previous,
  ) async {
    try {
      final current = (await writer.itemsOf(
        listId,
      )).where((i) => i.id == itemId).firstOrNull;
      if (current == null) return AvoUndoResult.changedSince;
      final json = current.toJson();
      for (final e in applied.entries) {
        if (!_same(json[e.key], e.value)) return AvoUndoResult.changedSince;
      }
      await writer.updateItem(listId, itemId, previous);
      writer.changed([listId]);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo update failed: $e');
      return AvoUndoResult.failed;
    }
  }

  static bool _same(Object? a, Object? b) {
    if (a is num && b is num) return a.toDouble() == b.toDouble();
    return a == b;
  }

  // ---------------------------------------------------------------- move

  /// Moves [itemIds] one by one and describes the result. Items that could
  /// not be moved are counted ([AvoListChange.failedCount]) and can be tried
  /// again from the card; the undo covers every moved item.
  Future<({AvoListChange? change, int moved, String? failure})> move({
    required String fromListId,
    required String toListId,
    required List<String> itemIds,
    List<ShoppingItemModel>? before,
    List<String> alreadyMoved = const [],
    List<ShoppingItemModel> alreadyMovedItems = const [],
  }) async {
    final known = before ?? await _items(fromListId);
    final byId = {for (final i in known) i.id: i};
    final moved = <String>[];
    String? failure;
    for (final id in itemIds) {
      try {
        await writer.moveItem(fromListId, toListId, id);
        moved.add(id);
      } catch (e) {
        failure = e.toString();
        break;
      }
    }
    writer.changed([fromListId, toListId]);
    final allMoved = [...alreadyMoved, ...moved];
    final failed = itemIds.skip(moved.length).toList();
    if (allMoved.isEmpty) return (change: null, moved: 0, failure: failure);
    final items = [
      ...alreadyMovedItems,
      for (final id in moved)
        if (byId[id] != null) byId[id]!.copyWith(listId: toListId),
    ];
    final change = AvoListChange(
      kind: AvoListChangeKind.moved,
      listId: toListId,
      listName: await listName(toListId),
      fromListName: await listName(fromListId),
      count: allMoved.length,
      items: items,
      failedCount: failed.length,
      retryFailed: failed.isEmpty
          ? null
          : () async {
              final again = await move(
                fromListId: fromListId,
                toListId: toListId,
                itemIds: failed,
                before: known,
                alreadyMoved: allMoved,
                alreadyMovedItems: items,
              );
              return again.change;
            },
      undo: () => undoMoved(fromListId, toListId, allMoved),
    );
    return (change: change, moved: moved.length, failure: failure);
  }

  Future<AvoUndoResult> undoMoved(
    String fromListId,
    String toListId,
    List<String> itemIds,
  ) async {
    try {
      final ids = {for (final i in await writer.itemsOf(toListId)) i.id};
      if (!itemIds.every(ids.contains)) return AvoUndoResult.changedSince;
      for (final id in itemIds) {
        await writer.moveItem(toListId, fromListId, id);
      }
      writer.changed([fromListId, toListId]);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo move failed: $e');
      return AvoUndoResult.failed;
    }
  }

  // --------------------------------------------------------- create, rename

  AvoListChange created(ShoppingListModel list) => AvoListChange(
    kind: AvoListChangeKind.created,
    listId: list.id,
    listName: list.name,
    undo: () => undoCreated(list.id),
  );

  /// A new list goes again only while it is still empty.
  Future<AvoUndoResult> undoCreated(String listId) async {
    try {
      if ((await writer.itemsOf(listId)).isNotEmpty) {
        return AvoUndoResult.changedSince;
      }
      await writer.deleteList(listId);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo create failed: $e');
      return AvoUndoResult.failed;
    }
  }

  AvoListChange renamed(String listId, String previousName, String newName) =>
      AvoListChange(
        kind: AvoListChangeKind.renamed,
        listId: listId,
        listName: newName,
        previousName: previousName.isEmpty ? null : previousName,
        undo: previousName.isEmpty
            ? null
            : () => undoRenamed(listId, previousName, newName),
      );

  Future<AvoUndoResult> undoRenamed(
    String listId,
    String previousName,
    String newName,
  ) async {
    try {
      final current = (await writer.lists())
          .where((l) => l.id == listId)
          .firstOrNull;
      if (current == null || current.name != newName) {
        return AvoUndoResult.changedSince;
      }
      await writer.renameList(listId, previousName);
      return AvoUndoResult.undone;
    } catch (e) {
      debugPrint('❌ [AVO] Undo rename failed: $e');
      return AvoUndoResult.failed;
    }
  }
}
