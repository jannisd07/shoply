part of 'avo_assistant_service.dart';

// Lists and items.
extension AvoListTools on AvoAssistantService {
  Future<Map<String, Object?>> _toolGetLists(
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final lists = await _fetchLists(ref);
    if (lists.isNotEmpty) {
      payloads.add(AvoWidgetPayload.lists(lists));
    }
    return {
      'found': lists.length,
      'lists': lists
          .map(
            (l) => {'id': l.id, 'name': l.name, 'item_count': l.itemCount ?? 0},
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolGetListContents(
    Map<String, Object?> args,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    var listId = args['list_id'] as String?;
    if (listId == null || listId.isEmpty) {
      final firstList = context?.lists?.isNotEmpty == true
          ? context!.lists!.first
          : null;
      if (firstList == null) return {'error': 'No lists available'};
      listId = firstList.id;
    }
    final items = await ItemRepository.instance.getListItems(listId);
    String name = 'Shopping list';
    if (context?.lists != null) {
      for (final l in context!.lists!) {
        if (l.id == listId) {
          name = l.name;
          break;
        }
      }
    }
    payloads.add(
      AvoWidgetPayload.listItems(listId: listId, listName: name, items: items),
    );
    return {
      'list_id': listId,
      'list_name': name,
      'item_count': items.length,
      'unchecked_count': items.where((i) => !i.isChecked).length,
      'items': items
          .map(
            (i) => {
              'id': i.id,
              'name': i.name,
              'quantity': i.quantity,
              'unit': i.unit,
              'checked': i.isChecked,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolAddItem(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    final name = args['name'] as String?;
    if (listId == null || name == null) {
      return {'error': 'list_id and name are required'};
    }
    final quantity = (args['quantity'] as num?)?.toDouble() ?? 1.0;
    final unit = args['unit'] as String?;
    final added = await addItemForAvo(
      ref,
      listId: listId,
      name: name,
      quantity: quantity,
      unit: unit,
    );
    payloads.add(AvoWidgetPayload.listChange(added));
    return {'success': true, 'list_id': listId, 'name': name};
  }

  /// Puts one item on [listId] the way the list screen does and describes
  /// the change for the answer card. "Widerrufen" deletes a new row, or sets
  /// a merged row back to its old quantity. Also used by the tab's own "Auf
  /// welche Liste?" card.
  Future<AvoListChange> addItemForAvo(
    WidgetRef ref, {
    required String listId,
    required String name,
    double quantity = 1,
    String? unit,
  }) => AvoAssistantService._changes(
    ref,
  ).add(listId: listId, name: name, quantity: quantity, unit: unit);

  /// Several items on [listId] in one batch, for the cards (photo note,
  /// "Alle wieder auf …"), with "Widerrufen".
  Future<AvoItemsRecord> addItemsForAvo(
    WidgetRef ref, {
    required String tool,
    required AvoItemsSource source,
    required String listId,
    required List<NewItem> items,
  }) async {
    final record = await AvoAssistantService._changes(
      ref,
    ).addBatch(tool: tool, source: source, listId: listId, items: items);
    await _afterBulkListChange(ref, listId);
    return record;
  }

  Future<Map<String, Object?>> _toolPickList(
    Map<String, Object?> args,
    List<AvoWidgetPayload> payloads,
  ) async {
    final name = args['name'] as String?;
    if (name == null) return {'error': 'name is required'};
    final quantity = (args['quantity'] as num?)?.toDouble() ?? 1.0;
    final unit = args['unit'] as String?;
    payloads.add(
      AvoWidgetPayload.pickList(itemName: name, quantity: quantity, unit: unit),
    );
    return {'prompted': true};
  }

  Future<Map<String, Object?>> _toolCheckItems(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    final itemIds = AvoAssistantService._stringList(args['item_ids']);
    final checked = args['checked'] as bool? ?? true;
    if (listId == null || itemIds.isEmpty) {
      return {'error': 'list_id and item_ids are required'};
    }
    final repository = ref.read(itemRepositoryProvider);
    final changes = AvoAssistantService._changes(ref);
    final before = await AvoAssistantService._itemsOrEmpty(repository, listId);
    await Future.wait(
      itemIds.map((id) => repository.toggleItemChecked(id, checked)),
    );
    ref.invalidate(itemsNotifierProvider(listId));
    await _afterBulkListChange(ref, listId);
    payloads.add(
      AvoWidgetPayload.listChange(
        await changes.checked(
          listId: listId,
          before: before,
          itemIds: itemIds,
          checked: checked,
        ),
      ),
    );
    return {'updated': itemIds.length, 'checked': checked};
  }

  /// `complete_list`: the same checkout as "Einkauf abschließen" (W10's
  /// `tripHistoryProvider`): the checked items go into the history as one
  /// trip and leave the list; no market and no amount (the person adds
  /// them in the trip detail, V5).
  Future<Map<String, Object?>> _toolCompleteList(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    if (listId == null) return {'error': 'list_id is required'};
    final repository = ref.read(itemRepositoryProvider);
    final all = await repository.getListItems(listId);
    final checked = all.where((i) => i.isChecked).toList();
    if (checked.isEmpty) {
      return {
        'error': 'nothing_checked',
        'hint': 'Nothing is checked off on this list yet; check items first.',
      };
    }
    final known = ref
        .read(listsNotifierProvider)
        .valueOrNull
        ?.where((l) => l.id == listId)
        .firstOrNull
        ?.name;
    final listName = known ?? await repository.getListName(listId) ?? '';
    final result = await ref
        .read(tripHistoryProvider.notifier)
        .checkout(
          CheckoutRequest(
            listId: listId,
            listName: listName,
            checkedItems: checked,
          ),
        );
    ref.invalidate(itemsNotifierProvider(listId));
    return switch (result) {
      CheckoutSaved(:final trip) => {
        'saved': true,
        'trip_id': trip.id,
        'items': checked.length,
      },
      CheckoutPending(:final localTripId, :final failed) => {
        'saved': !failed,
        'pending': true,
        'trip_id': localTripId,
        'items': checked.length,
      },
      CheckoutAlreadyCompleted() => {'error': 'already_completed'},
      CheckoutListGone() => {'error': 'list_gone'},
      CheckoutNothingChecked() => {'error': 'nothing_checked'},
    };
  }

  Future<Map<String, Object?>> _toolUpdateItem(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    final itemId = args['item_id'] as String?;
    if (listId == null || itemId == null) {
      return {'error': 'list_id and item_id are required'};
    }
    final newName = (args['new_name'] as String?)?.trim();
    final quantity = (args['quantity'] as num?)?.toDouble();
    final unit = args['unit'] as String?;
    final notes = args['notes'] as String?;

    // Same update keys the list detail screen's own edit sheet writes.
    final updates = <String, dynamic>{
      if (newName != null && newName.isNotEmpty) 'name': newName,
      if (quantity != null && quantity > 0) 'quantity': quantity,
      if (unit != null) 'unit': unit.trim().isEmpty ? null : unit.trim(),
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
    if (updates.isEmpty) {
      return {
        'error': 'Nothing to change — pass new_name, quantity, unit, or notes',
      };
    }
    final before = (await AvoAssistantService._itemsOrEmpty(
      ref.read(itemRepositoryProvider),
      listId,
    )).where((i) => i.id == itemId).firstOrNull;
    await ref
        .read(itemsNotifierProvider(listId).notifier)
        .updateItem(itemId, updates);
    ref.invalidate(listsNotifierProvider);
    final change = await AvoAssistantService._changes(
      ref,
    ).updated(listId: listId, before: before, updates: updates);
    if (change != null) payloads.add(AvoWidgetPayload.listChange(change));
    return {'success': true, 'updated_fields': updates.keys.toList()};
  }

  Future<Map<String, Object?>> _toolMoveItems(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final fromListId = args['from_list_id'] as String?;
    final toListId = args['to_list_id'] as String?;
    final itemIds = AvoAssistantService._stringList(args['item_ids']);
    if (fromListId == null || toListId == null || itemIds.isEmpty) {
      return {'error': 'from_list_id, to_list_id and item_ids are required'};
    }
    if (fromListId == toListId) {
      return {'error': 'Those items are already on that list'};
    }
    // Changing list_id keeps the item's id, checked state, category, and
    // price. RLS only permits this when the user is a member of BOTH lists
    // (the UPDATE policy's USING clause applies to old and new row alike),
    // so a move to a foreign list fails closed instead of silently leaking.
    final result = await AvoAssistantService._changes(
      ref,
    ).move(fromListId: fromListId, toListId: toListId, itemIds: itemIds);
    final moved = result.moved;
    final failure = result.failure;
    final change = result.change;
    if (change != null) payloads.add(AvoWidgetPayload.listChange(change));
    if (failure != null) {
      return {
        'error':
            'Move failed after $moved of ${itemIds.length} items: $failure',
        'moved_count': moved,
      };
    }
    return {'success': true, 'moved_count': moved, 'to_list_id': toListId};
  }

  Future<Map<String, Object?>> _toolCreateList(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final name = (args['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return {'error': 'name is required'};
    final newList = await ref
        .read(listsNotifierProvider.notifier)
        .createList(name);
    payloads.add(
      AvoWidgetPayload.listChange(
        AvoAssistantService._changes(ref).created(newList),
      ),
    );
    return {
      'success': true,
      'list_id': newList.id,
      'name': newList.name,
      'hint': 'Use this list_id with add_item_to_list to add items.',
    };
  }

  Future<Map<String, Object?>> _toolRenameList(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final listId = args['list_id'] as String?;
    final newName = (args['new_name'] as String?)?.trim();
    if (listId == null || newName == null || newName.isEmpty) {
      return {'error': 'list_id and new_name are required'};
    }
    final changes = AvoAssistantService._changes(ref);
    final previousName = await changes.listName(listId);
    await ref.read(listsNotifierProvider.notifier).updateList(listId, {
      'name': newName,
    });
    payloads.add(
      AvoWidgetPayload.listChange(
        changes.renamed(listId, previousName, newName),
      ),
    );
    return {'success': true, 'renamed_to': newName};
  }
}
