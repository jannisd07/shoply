import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/shopping_history_service.dart';

/// Shopping history service provider
final shoppingHistoryServiceProvider = Provider<ShoppingHistoryService>((ref) {
  return ShoppingHistoryService();
});

/// Provider for all shopping history
final shoppingHistoryProvider = FutureProvider<List<ShoppingHistory>>((ref) async {
  final service = ref.watch(shoppingHistoryServiceProvider);
  return service.getShoppingHistory();
});

/// Provider for recent shopping history (for homepage)
final recentHistoryProvider = FutureProvider<List<ShoppingHistory>>((ref) async {
  final service = ref.watch(shoppingHistoryServiceProvider);
  return service.getRecentHistory(limit: 5);
});

/// Provider for shopping history of a specific list
final listHistoryProvider = FutureProvider.family<List<ShoppingHistory>, String>((ref, listId) async {
  final service = ref.watch(shoppingHistoryServiceProvider);
  return service.getHistoryForList(listId);
});

/// State notifier for managing shopping history with mutations
class ShoppingHistoryNotifier extends StateNotifier<AsyncValue<List<ShoppingHistory>>> {
  final ShoppingHistoryService _service;

  ShoppingHistoryNotifier(this._service) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await _service.getShoppingHistory();
      state = AsyncValue.data(history);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    try {
      final history = await _service.getShoppingHistory();
      state = AsyncValue.data(history);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteHistory(String historyId) async {
    try {
      await _service.deleteHistory(historyId);
      // Remove from local state immediately for better UX
      state.whenData((history) {
        state = AsyncValue.data(
          history.where((h) => h.id != historyId).toList(),
        );
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _service.clearAllHistory();
      state = const AsyncValue.data([]);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Provider for the shopping history notifier
final shoppingHistoryNotifierProvider =
    StateNotifierProvider<ShoppingHistoryNotifier, AsyncValue<List<ShoppingHistory>>>((ref) {
  final service = ref.watch(shoppingHistoryServiceProvider);
  return ShoppingHistoryNotifier(service);
});
