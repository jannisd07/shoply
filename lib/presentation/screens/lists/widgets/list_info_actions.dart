import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Everything the list overview, Neue Liste, Teilen, Beitreten and
/// Listen-Info write, in one place so the screens stay testable
/// ([listActionsProvider] is overridden in tests). All writes go through
/// [ListsNotifier], [ListRepository] and [ItemRepository]; the only
/// exception is removing a member, for which the repository has no method
/// yet (reported in the A5 report).
class ListActions {
  ListActions(this._ref);

  final Ref _ref;

  ListsNotifier get _lists => _ref.read(listsNotifierProvider.notifier);

  /// Reloads the lists (pull to refresh).
  Future<void> refreshLists() => _lists.loadLists();

  /// Creates a list and gives it [colorHex] (`#RRGGBB`). The colour is
  /// best effort: a failure there keeps the new list.
  Future<ShoppingListModel> createList(String name, {String? colorHex}) async {
    final list = await _lists.createList(name);
    if (colorHex == null) return list;
    try {
      await _lists.saveBackground(list.id, 'color', colorHex, null);
    } catch (e) {
      debugPrint('⚠️ [LIST_ACTIONS] Colour of the new list not saved: $e');
    }
    return list;
  }

  Future<void> rename(String listId, String name) =>
      _lists.updateList(listId, {'name': name});

  /// Gives the list a palette colour; the photo, if any, is dropped.
  Future<void> setColor(String listId, String colorHex) =>
      _lists.saveBackground(listId, 'color', colorHex, null);

  Future<void> deleteList(String listId) => _lists.deleteList(listId);

  Future<void> leaveList(String listId) async {
    await _ref.read(listRepositoryProvider).leaveList(listId);
    await _lists.loadLists();
  }

  Future<void> removeMember(String listId, String userId) async {
    await SupabaseService.instance
        .from('list_members')
        .delete()
        .eq('list_id', listId)
        .eq('user_id', userId);
  }

  /// A new share code (the old code and links stop working).
  Future<String> generateShareCode(String listId) =>
      _lists.generateShareCode(listId);

  /// Joins by code; null when no list has it.
  Future<ShoppingListModel?> joinWithCode(String code) =>
      _lists.joinListWithCode(code);

  /// Puts a quick re-add item on [listId]; returns the undo token.
  Future<String> addItem(String listId, QuickAddSuggestion suggestion) async {
    final result = await _ref.read(itemRepositoryProvider).addItems(listId, [
      NewItem(
        name: suggestion.name,
        quantity: suggestion.quantity,
        category: suggestion.categoryId,
      ),
    ]);
    unawaited(_lists.loadLists());
    return result.token;
  }

  Future<void> undoAdd(String token) async {
    await _ref.read(itemRepositoryProvider).undoAddItems(token);
    unawaited(_lists.loadLists());
  }
}

/// The writes of the list screens; overridden in tests.
final listActionsProvider = Provider<ListActions>((ref) => ListActions(ref));
