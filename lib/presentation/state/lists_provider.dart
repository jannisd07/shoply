import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/widget_service.dart';

/// List repository provider
final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository();
});

/// Provider for all user lists
final userListsProvider = FutureProvider<List<ShoppingListModel>>((ref) async {
  final repository = ref.watch(listRepositoryProvider);
  return repository.getUserLists();
});

/// Provider for a single list by ID
final listByIdProvider = FutureProvider.family<ShoppingListModel?, String>((ref, listId) async {
  final repository = ref.watch(listRepositoryProvider);
  return repository.getListById(listId);
});

/// State notifier for managing lists
class ListsNotifier extends StateNotifier<AsyncValue<List<ShoppingListModel>>> {
  final ListRepository _repository;
  final PurchaseTrackingService _trackingService = PurchaseTrackingService();

  ListsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadLists();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    // Subscribe to shopping_items changes to refresh lists when items change
    _repository.subscribeToItemChanges(() {
      loadLists();
    });
  }

  Future<void> loadLists() async {
    // Only show loading spinner on first load (when no data exists yet)
    if (state is! AsyncData<List<ShoppingListModel>>) {
      state = const AsyncValue.loading();
    }
    try {
      final lists = await _repository.getUserLists();
      state = AsyncValue.data(lists);
      // Cache for offline use
      OfflineCacheService.instance.cacheLists(lists);
      // Update widget with available lists for configuration
      _updateWidgetAvailableLists(lists);
      // Refresh the Quick-Add widget's frequently-bought-item suggestions
      unawaited(_updateWidgetRecentItems());
    } catch (error, stackTrace) {
      // Try offline cache
      final cached = await OfflineCacheService.instance.getCachedLists();
      if (cached != null && cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else if (state is! AsyncData<List<ShoppingListModel>>) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }
  
  void _updateWidgetAvailableLists(List<ShoppingListModel> lists) {
    final widgetLists = lists.map((l) => {'id': l.id, 'name': l.name}).toList();
    WidgetService.updateAvailableLists(widgetLists);
  }

  /// Pushes the user's most frequently bought items to the App Group so the
  /// Quick-Add widget can offer one-tap suggestions. Best-effort: purchase
  /// stats are a nice-to-have for the widget, never worth failing list load
  /// over.
  Future<void> _updateWidgetRecentItems() async {
    try {
      final stats = await _trackingService.getFrequentItems(limit: 8);
      final items = stats
          .map((s) => WidgetRecentItem(
                name: _titleCase(s.itemName),
                category: s.preferredCategory,
                quantity: s.preferredQuantity ?? 1.0,
              ))
          .toList();
      await WidgetService.updateRecentItems(items);
    } catch (e) {
      debugPrint('⚠️ [Widget] Failed to refresh recent-items suggestions: $e');
    }
  }

  String _titleCase(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  void dispose() {
    _repository.unsubscribeFromItemChanges();
    super.dispose();
  }

  Future<ShoppingListModel> createList(String name) async {
    try {
      final newList = await _repository.createList(name);
      await loadLists();
      return newList;
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateList(String listId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateList(listId, updates);
      await loadLists();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      await _repository.deleteList(listId);
      await loadLists();
    } catch (error) {
      rethrow;
    }
  }

  Future<String> generateShareCode(String listId) async {
    try {
      final code = await _repository.generateShareCode(listId);
      await loadLists();
      return code;
    } catch (error) {
      rethrow;
    }
  }

  Future<ShoppingListModel?> joinListWithCode(String shareCode) async {
    try {
      final list = await _repository.joinListWithCode(shareCode);
      await loadLists();
      return list;
    } catch (error) {
      rethrow;
    }
  }

  Future<ShoppingListModel?> joinListWithLink(String shareLink) async {
    try {
      final list = await _repository.joinListWithLink(shareLink);
      await loadLists();
      return list;
    } catch (error) {
      rethrow;
    }
  }

  Future<String?> getShareLink(String listId) async {
    try {
      return await _repository.getShareLink(listId);
    } catch (error) {
      rethrow;
    }
  }

  /// Save background for a list (Prompt 5 - unified method)
  Future<void> saveBackground(
    String listId,
    String backgroundType,
    String? backgroundValue,
    String? imageUrl,
  ) async {
    try {
      await _repository.saveBackground(
        listId,
        backgroundType,
        backgroundValue,
        imageUrl,
      );
      await loadLists();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> reorderLists(int oldIndex, int newIndex) async {
    final currentState = state;
    if (!currentState.hasValue) return;
    
    final lists = List<ShoppingListModel>.from(currentState.value!);
    
    // Adjust newIndex if moving down
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // Move the item
    final item = lists.removeAt(oldIndex);
    lists.insert(newIndex, item);
    
    // Update state immediately for smooth UI
    state = AsyncValue.data(lists);
    
    // Update order in database
    try {
      for (int i = 0; i < lists.length; i++) {
        await _repository.updateList(lists[i].id, {'order_index': i});
      }
    } catch (error) {
      // Reload if update fails
      await loadLists();
      rethrow;
    }
  }
}

/// Lists state notifier provider
final listsNotifierProvider =
    StateNotifierProvider<ListsNotifier, AsyncValue<List<ShoppingListModel>>>((ref) {
  final repository = ref.watch(listRepositoryProvider);
  return ListsNotifier(repository);
});
