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

  ItemsNotifier(this._repository, this.listId) : super(const AsyncValue.loading()) {
    loadItems();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _repository.subscribeToItemChanges(listId, () async {
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

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    final currentState = state;
    if (!currentState.hasValue) return;
    
    final items = List<ShoppingItemModel>.from(currentState.value!);
    
    // Adjust newIndex if moving down
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // Move the item
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    
    // Update state immediately for smooth UI
    state = AsyncValue.data(items);
    
    // Update order in database
    try {
      for (int i = 0; i < items.length; i++) {
        await _repository.updateItem(items[i].id, {'order_index': i});
      }
    } catch (error) {
      // Reload if update fails
      await loadItems();
      rethrow;
    }
  }
}

/// Items state notifier provider factory
final itemsNotifierProvider = StateNotifierProvider.family<ItemsNotifier,
    AsyncValue<List<ShoppingItemModel>>, String>((ref, listId) {
  final repository = ref.watch(itemRepositoryProvider);
  return ItemsNotifier(repository, listId);
});
