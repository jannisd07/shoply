import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/data/services/widget_service.dart';

/// Item repository provider
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository.instance;
});

/// State notifier for managing items in a list.
///
/// Mutations are optimistic: the change is visible immediately, the server
/// response then replaces the touched rows, and a failed write rolls back.
/// Remote changes arrive through a realtime channel that is only open while
/// something watches this list (see [itemsNotifierProvider]) and are
/// debounced into one reload.
class ItemsNotifier extends StateNotifier<AsyncValue<List<ShoppingItemModel>>> {
  final ItemRepository _repository;
  final String listId;

  /// Bumped by every load and every mutation; a load whose number is no
  /// longer current finished after newer data and is dropped.
  int _generation = 0;

  /// Writes in flight. Realtime echoes are held back until all of them
  /// landed, so a reload never shows a half-written state.
  int _pendingWrites = 0;
  bool _reloadWanted = false;

  bool _realtimeActive = false;
  Timer? _realtimeDebounce;
  DateTime? _lastSyncedAt;
  String? _listName;

  static const _realtimeDebounceDelay = Duration(milliseconds: 300);

  /// Seeds from the warmed in-memory cache when one exists, so the detail
  /// screen's very first frame is already populated instead of showing a
  /// spinner until Supabase answers (stale-while-revalidate). [loadItems]
  /// then reconciles with the server.
  ItemsNotifier(this._repository, this.listId) : super(_seed(listId)) {
    loadItems();
  }

  static AsyncValue<List<ShoppingItemModel>> _seed(String listId) {
    final cached = OfflineCacheService.instance.getCachedListItemsSync(listId);
    if (cached == null) return const AsyncValue.loading();
    return AsyncValue.data(cached);
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Opens the realtime channel (idempotent). Catches up with a reload when
  /// the data may have gone stale while nobody was listening.
  void startRealtime() {
    if (_realtimeActive || !mounted) return;
    _realtimeActive = true;
    _repository.subscribeToItemChanges(listId, _onRemoteChange);
    final lastSync = _lastSyncedAt;
    if (lastSync != null &&
        DateTime.now().difference(lastSync) > const Duration(seconds: 2)) {
      loadItems();
    }
  }

  void stopRealtime() {
    if (!_realtimeActive) return;
    _realtimeActive = false;
    _realtimeDebounce?.cancel();
    _repository.unsubscribeFromItemChanges(listId);
  }

  void _onRemoteChange() {
    if (_pendingWrites > 0) {
      _reloadWanted = true;
      return;
    }
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(_realtimeDebounceDelay, () {
      if (mounted) loadItems();
    });
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> loadItems() async {
    final generation = ++_generation;
    if (state is! AsyncData) {
      state = const AsyncValue.loading();
    }
    try {
      final items = await _repository.getListItems(listId);
      if (!mounted || generation != _generation) return;
      _lastSyncedAt = DateTime.now();
      _commit(items);
    } catch (error, stackTrace) {
      if (!mounted || generation != _generation) return;
      debugPrint('⚠️ [ITEMS_PROVIDER] Reload failed, keeping current items: $error');
      // Keep whatever is on screen; only an empty screen falls back to the
      // offline cache or shows the error.
      if (state is AsyncData) return;
      final cached = await OfflineCacheService.instance.getCachedListItems(listId);
      if (!mounted) return;
      state = cached != null && cached.isNotEmpty
          ? AsyncValue.data(cached)
          : AsyncValue.error(error, stackTrace);
    }
  }

  /// Publishes [items] and mirrors them to the offline cache and the home
  /// screen widget.
  void _commit(List<ShoppingItemModel> items) {
    state = AsyncValue.data(items);
    OfflineCacheService.instance.cacheListItems(listId, items);
    unawaited(_updateWidget(items));
  }

  /// Update the home screen widget with current list items
  Future<void> _updateWidget(List<ShoppingItemModel> items) async {
    try {
      _listName ??= await _repository.getListName(listId);
      await WidgetService.updateShoppingListWidget(
        listId: listId,
        listName: _listName ?? 'Shopping List',
        items: [
          for (final item in items)
            WidgetItem(
              id: item.id,
              name: item.name,
              quantity: item.quantity.toInt(),
              isChecked: item.isChecked,
            ),
        ],
      );
    } catch (e) {
      debugPrint('⚠️ [Widget] Failed to update widget: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Runs one optimistic mutation: applies [optimistic] to the current items
  /// right away, awaits [write], then applies [reconcile] with the server
  /// result. On failure the pre-mutation items come back, a reload
  /// reconciles with the server and the error is rethrown.
  Future<T> _mutate<T>({
    required List<ShoppingItemModel> Function(List<ShoppingItemModel> items) optimistic,
    required Future<T> Function() write,
    List<ShoppingItemModel> Function(List<ShoppingItemModel> items, T result)? reconcile,
  }) async {
    final before = state.valueOrNull;
    _generation++; // A load started before this change must not undo it.
    if (before != null) state = AsyncValue.data(optimistic(before));

    _pendingWrites++;
    try {
      final result = await write();
      final current = state.valueOrNull;
      if (mounted) {
        if (current == null) {
          await loadItems();
        } else {
          _commit(reconcile == null ? current : reconcile(current, result));
        }
      }
      unawaited(UnreadService().markAsRead(listId));
      return result;
    } catch (error) {
      debugPrint('❌ [ITEMS_PROVIDER] Write failed, rolling back: $error');
      if (mounted) {
        if (before != null) state = AsyncValue.data(before);
        unawaited(loadItems());
      }
      rethrow;
    } finally {
      _pendingWrites--;
      if (_pendingWrites == 0 && _reloadWanted && mounted) {
        _reloadWanted = false;
        _onRemoteChange();
      }
    }
  }

  /// [item] with the column [updates] applied (same keys as the DB row).
  static ShoppingItemModel _patched(
    ShoppingItemModel item,
    Map<String, dynamic> updates,
  ) {
    try {
      return ShoppingItemModel.fromJson({...item.toJson(), ...updates});
    } catch (_) {
      return item; // Unusual value types: wait for the server row instead.
    }
  }

  /// Replace the row with [updated]'s id, or drop it when it moved to
  /// another list.
  List<ShoppingItemModel> _replace(List<ShoppingItemModel> items, ShoppingItemModel updated) => [
        for (final i in items)
          if (i.id != updated.id)
            i
          else if (updated.listId == listId)
            updated,
      ];

  /// [_replace] when [saved] is already listed, otherwise append it.
  List<ShoppingItemModel> _upsert(
    List<ShoppingItemModel> items,
    ShoppingItemModel saved,
  ) =>
      items.any((i) => i.id == saved.id) ? _replace(items, saved) : [...items, saved];

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
    final now = DateTime.now();
    final pendingId = 'pending-${now.microsecondsSinceEpoch}';

    await _mutate<ShoppingItemModel>(
      optimistic: (items) => [
        ...items,
        ShoppingItemModel(
          id: pendingId,
          listId: listId,
          name: name,
          quantity: quantity,
          unit: unit,
          category: category,
          categoryId: category,
          notes: notes,
          isDietWarning: isDietWarning,
          barcode: barcode,
          price: price,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      write: () => _repository.addItem(
        listId: listId,
        name: name,
        quantity: quantity,
        unit: unit,
        category: category,
        notes: notes,
        isDietWarning: isDietWarning,
        barcode: barcode,
        price: price,
        priceCurrency: priceCurrency,
        priceRetailer: priceRetailer,
        priceUnit: priceUnit,
        priceOldValue: priceOldValue,
        autoParse: autoParse,
      ),
      // The saved row replaces the placeholder (a merge returns an existing
      // row instead, which is then updated in place).
      reconcile: (items, saved) =>
          _upsert(items.where((i) => i.id != pendingId).toList(), saved),
    );

    _repository.sendItemAddedNotification(listId: listId, itemName: name);
  }

  /// Batch-import extracted items (photo-import flow) with an optimistic
  /// insert: the items appear in the list immediately, then reconcile with
  /// the Supabase writes. On any write failure the optimistic state is
  /// rolled back and the error rethrown so the caller can offer a retry.
  Future<void> importItems(
    List<({String name, double quantity, String? unit})> items,
  ) async {
    if (items.isEmpty) return;
    final now = DateTime.now();
    final pendingPrefix = 'pending-import-${now.microsecondsSinceEpoch}-';

    await _mutate<List<ShoppingItemModel>>(
      optimistic: (current) => [
        ...current,
        for (var i = 0; i < items.length; i++)
          ShoppingItemModel(
            id: '$pendingPrefix$i',
            listId: listId,
            name: items[i].name,
            quantity: items[i].quantity,
            unit: items[i].unit,
            createdAt: now,
            updatedAt: now,
          ),
      ],
      // Sequential on purpose: each add may merge into a row an earlier one
      // created. autoParse off — quantity/unit were reviewed explicitly.
      write: () async => [
        for (final item in items)
          await _repository.addItem(
            listId: listId,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            autoParse: false,
          ),
      ],
      reconcile: (current, saved) => saved.fold(
        current.where((i) => !i.id.startsWith(pendingPrefix)).toList(),
        _upsert,
      ),
    );
  }

  /// Applies column [updates] to one row; a changed `list_id` (moving the
  /// item to another list) removes it from this one.
  Future<void> updateItem(String itemId, Map<String, dynamic> updates) {
    return _mutate<ShoppingItemModel>(
      optimistic: (items) => [
        for (final i in items) i.id == itemId ? _patched(i, updates) : i,
      ].where((i) => i.listId == listId).toList(),
      write: () => _repository.updateItem(itemId, updates),
      reconcile: _replace,
    );
  }

  Future<void> toggleItemChecked(String itemId, bool isChecked) {
    final updates = {
      'is_checked': isChecked,
      'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
    };
    return _mutate<ShoppingItemModel>(
      optimistic: (items) => [
        for (final i in items) i.id == itemId ? _patched(i, updates) : i,
      ],
      write: () => _repository.toggleItemChecked(itemId, isChecked),
      reconcile: _replace,
    );
  }

  Future<void> deleteItem(String itemId) {
    return _mutate<void>(
      optimistic: (items) => items.where((i) => i.id != itemId).toList(),
      write: () => _repository.deleteItem(itemId),
    );
  }

  /// Core helper used by all reorder operations.
  ///
  /// Stamps every item in [reorderedItems] with its index as `orderIndex`,
  /// shows that order immediately, then persists the indexes that changed.
  ///
  /// Every row gets an index (not just the moved one): never-ordered items
  /// carry a null `order_index` and sort after all ordered ones, so leaving
  /// them unwritten would snap them to the end on the next reload.
  Future<void> _applyReorder(List<ShoppingItemModel> reorderedItems) async {
    final previousIndex = {
      for (final i in state.valueOrNull ?? const <ShoppingItemModel>[])
        i.id: i.orderIndex,
    };
    final stamped = [
      for (int i = 0; i < reorderedItems.length; i++)
        reorderedItems[i].copyWith(orderIndex: i),
    ];
    final changed = {
      for (final item in stamped)
        if (previousIndex[item.id] != item.orderIndex) item.id: item.orderIndex!,
    };

    try {
      await _mutate<void>(
        optimistic: (_) => stamped,
        write: () => _repository.updateOrderIndexes(listId, changed),
      );
    } catch (e) {
      // Already rolled back and reloading; a failed reorder is not worth
      // surfacing to the drag gesture.
      debugPrint('⚠️ [ITEMS_PROVIDER] Reorder failed: $e');
    }
  }

  /// Move [fromItemId] just before [toItemId] in the global list.
  Future<void> reorderItemToPosition(String fromItemId, String toItemId) async {
    final items = List<ShoppingItemModel>.of(state.valueOrNull ?? const []);
    final fromIndex = items.indexWhere((i) => i.id == fromItemId);
    var toIndex = items.indexWhere((i) => i.id == toItemId);
    if (fromIndex == -1 || toIndex == -1 || fromIndex == toIndex) return;

    final item = items.removeAt(fromIndex);
    if (fromIndex < toIndex) toIndex -= 1;
    items.insert(toIndex, item);

    await _applyReorder(items);
  }

  /// Move [fromItemId] right AFTER [afterItemId] in the global list.
  Future<void> reorderItemAfter(String fromItemId, String afterItemId) async {
    final items = List<ShoppingItemModel>.of(state.valueOrNull ?? const []);
    final fromIndex = items.indexWhere((i) => i.id == fromItemId);
    var afterIndex = items.indexWhere((i) => i.id == afterItemId);
    if (fromIndex == -1 || afterIndex == -1 || fromIndex == afterIndex) return;

    final item = items.removeAt(fromIndex);
    if (fromIndex < afterIndex) afterIndex -= 1;
    items.insert((afterIndex + 1).clamp(0, items.length), item);

    await _applyReorder(items);
  }
}

/// Items state notifier provider factory.
///
/// Not autoDispose: Avo, Siri and the scanner borrow notifiers through
/// `ref.read(...notifier)` and await long writes on them. Instead, the
/// realtime channel is tied to listeners — open while something watches the
/// items (the list screen, a dependent provider), closed when the last
/// watcher leaves — so visiting many lists no longer keeps one live channel
/// per list for the whole session.
final itemsNotifierProvider =
    StateNotifierProvider.family<ItemsNotifier, AsyncValue<List<ShoppingItemModel>>, String>(
        (ref, listId) {
  final notifier = ItemsNotifier(ref.watch(itemRepositoryProvider), listId);
  ref.onAddListener(notifier.startRealtime);
  ref.onCancel(notifier.stopRealtime);
  return notifier;
});
