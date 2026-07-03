import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/unread_service.dart';
import 'package:shoply/data/services/widget_service.dart';

/// Item repository provider
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository();
});

/// Provider for items in a specific list
final listItemsProvider = FutureProvider.family<List<ShoppingItemModel>, String>((ref, listId) async {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.getListItems(listId);
});

/// Provider for items grouped by category
final itemsByCategoryProvider =
    FutureProvider.family<Map<String, List<ShoppingItemModel>>, String>((ref, listId) async {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.getItemsByCategory(listId);
});

/// State notifier for managing items in a list
class ItemsNotifier extends StateNotifier<AsyncValue<List<ShoppingItemModel>>> {
  final ItemRepository _repository;
  final String listId;

  /// When true, incoming realtime events are ignored so an in-flight
  /// reorder batch-write does not get overwritten mid-way.
  bool _isReordering = false;

  ItemsNotifier(this._repository, this.listId) : super(const AsyncValue.loading()) {
    loadItems();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _repository.subscribeToItemChanges(listId, () async {
      if (_isReordering) return; // suppress reload while batch-writing
      await _loadItemsAndCheckForNew();
    });
  }

  Future<void> _loadItemsAndCheckForNew() async {
    try {
      final items = await _repository.getListItems(listId);
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> loadItems() async {
    if (state is! AsyncData) {
      state = const AsyncValue.loading();
    }
    try {
      // Sync any pending widget toggles first
      await _syncWidgetToggles();

      final items = await _repository.getListItems(listId);
      state = AsyncValue.data(items);

      // Cache for offline use
      OfflineCacheService.instance.cacheListItems(listId, items);

      // Update home screen widget with latest items
      _updateWidget(items);
    } catch (error, stackTrace) {
      // Try offline cache
      final cached = await OfflineCacheService.instance.getCachedListItems(listId);
      if (cached != null && cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else if (state is! AsyncData) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
  
  /// Update the home screen widget with current list items
  Future<void> _updateWidget(List<ShoppingItemModel> items) async {
    try {
      // Get list name
      final listName = await _repository.getListName(listId);
      
      final widgetItems = items.map((item) => WidgetItem(
        id: item.id,
        name: item.name,
        quantity: item.quantity.toInt(),
        isChecked: item.isChecked,
      )).toList();
      
      await WidgetService.updateShoppingListWidget(
        listId: listId,
        listName: listName ?? 'Shopping List',
        items: widgetItems,
      );
    } catch (e) {
      debugPrint('⚠️ [Widget] Failed to update widget: $e');
    }
  }
  
  /// Sync any pending toggles that happened in the iOS widget
  Future<void> _syncWidgetToggles() async {
    try {
      final pendingItemIds = await WidgetService.getPendingToggles();
      if (pendingItemIds.isEmpty) return;

      debugPrint('🔄 [Widget Sync] Processing ${pendingItemIds.length} widget toggles');

      // Get current items to determine their current state
      final currentItems = await _repository.getListItems(listId);
      final itemMap = {for (var item in currentItems) item.id: item};

      for (final itemId in pendingItemIds) {
        final item = itemMap[itemId];
        if (item != null) {
          // Toggle: if currently checked -> uncheck, if unchecked -> check
          await _repository.toggleItemChecked(itemId, !item.isChecked);
          debugPrint('✅ [Widget Sync] Toggled "${ item.name}" -> ${!item.isChecked}');
        }
      }

      await WidgetService.clearPendingToggles();
      debugPrint('✅ [Widget Sync] All widget toggles synced');
    } catch (e) {
      debugPrint('⚠️ [Widget Sync] Failed: $e');
    }
  }

  @override
  void dispose() {
    _repository.unsubscribeFromItemChanges(listId);
    super.dispose();
  }

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
    bool autoParse = true,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🛒 [ITEMS_PROVIDER] addItem called: "$name"');

      await _repository.addItem(
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
        autoParse: autoParse,
      );
      debugPrint('✅ [ITEMS_PROVIDER] Item added to database');
      
      final currentUserId = _repository.currentUserId;
      debugPrint('👤 [ITEMS_PROVIDER] Current user ID: $currentUserId');
      
      if (currentUserId != null) {
        debugPrint('📤 [ITEMS_PROVIDER] Sending notification to list members...');
        await _repository.sendItemAddedNotification(
          listId: listId, 
          itemName: name, 
          addedByUserId: currentUserId
        );
        debugPrint('✅ [ITEMS_PROVIDER] Notification sent successfully');
      } else {
        debugPrint('⚠️ [ITEMS_PROVIDER] No user ID - skipping notification');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      await loadItems();
      await UnreadService().markAsRead(listId);
    } catch (error) {
      debugPrint('❌ [ITEMS_PROVIDER] Error in addItem: $error');
      rethrow;
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateItem(itemId, updates);
      await loadItems();
      await UnreadService().markAsRead(listId);
    } catch (error) {
      rethrow;
    }
  }

  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    try {
      await _repository.toggleItemChecked(itemId, isChecked);
      await loadItems();
      await UnreadService().markAsRead(listId);
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _repository.deleteItem(itemId);
      await loadItems();
      await UnreadService().markAsRead(listId);
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateSortOrder(List<String> itemIds) async {
    try {
      await _repository.updateSortOrder(itemIds);
      await loadItems();
    } catch (error) {
      rethrow;
    }
  }

  /// Core helper used by all reorder operations.
  ///
  /// Stamps every item in [items] with its index as [orderIndex], pushes an
  /// optimistic state update, then writes ALL positions to the DB.
  ///
  /// Writing every item is important: items that have never been ordered
  /// before carry a null orderIndex (≙ 999999 in sorts). If we only write
  /// the moved items, unwritten neighbours stay at null and the next
  /// loadItems() sorts them all to the end, causing the snap-back.
  ///
  /// We do NOT call loadItems() afterwards – the optimistic state is already
  /// the correct target state. loadItems() would re-fetch and might briefly
  /// show a loading flash. The realtime flag prevents race-condition reloads
  /// during the write loop.
  Future<void> _applyReorder(List<ShoppingItemModel> reorderedItems) async {
    // Stamp every item with its new position.
    final stamped = [
      for (int i = 0; i < reorderedItems.length; i++)
        reorderedItems[i].copyWith(orderIndex: i),
    ];

    // Optimistic UI update – visible immediately, no flash.
    state = AsyncValue.data(stamped);

    // Suppress realtime reloads during the write burst.
    _isReordering = true;
    try {
      for (int i = 0; i < stamped.length; i++) {
        await _repository.updateItem(stamped[i].id, {'order_index': i});
      }
    } catch (_) {
      // On write failure roll back to a fresh DB load.
      _isReordering = false;
      await loadItems();
      return;
    }
    _isReordering = false;
    // No loadItems() here – the stamped optimistic state IS correct.
  }

  /// Move [fromItemId] just before [toItemId] in the global list.
  Future<void> reorderItemToPosition(String fromItemId, String toItemId) async {
    final currentState = state;
    if (!currentState.hasValue) return;
    final items = List<ShoppingItemModel>.from(currentState.value!);
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
    final currentState = state;
    if (!currentState.hasValue) return;
    final items = List<ShoppingItemModel>.from(currentState.value!);
    final fromIndex = items.indexWhere((i) => i.id == fromItemId);
    var afterIndex = items.indexWhere((i) => i.id == afterItemId);
    if (fromIndex == -1 || afterIndex == -1 || fromIndex == afterIndex) return;

    final item = items.removeAt(fromIndex);
    if (fromIndex < afterIndex) afterIndex -= 1;
    final insertAt = (afterIndex + 1).clamp(0, items.length);
    items.insert(insertAt, item);

    await _applyReorder(items);
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    final currentState = state;
    if (!currentState.hasValue) return;
    final items = List<ShoppingItemModel>.from(currentState.value!);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    await _applyReorder(items);
  }
}

/// Items state notifier provider factory
final itemsNotifierProvider = StateNotifierProvider.family<ItemsNotifier,
    AsyncValue<List<ShoppingItemModel>>, String>((ref, listId) {
  final repository = ref.watch(itemRepositoryProvider);
  return ItemsNotifier(repository, listId);
});
