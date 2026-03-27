import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recommendation_item.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/ml_recommendation_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// ML-powered recommendations provider
final mlRecommendationServiceProvider = Provider<MLRecommendationService>((ref) {
  return MLRecommendationService();
});

/// ML recommendations for current list
final mlRecommendationsProvider = FutureProvider.autoDispose
    .family<List<RecommendationItem>, String?>((ref, listId) async {
  if (listId == null) return [];

  final service = ref.watch(mlRecommendationServiceProvider);
  final currentItemsAsync = ref.watch(itemsNotifierProvider(listId));

  // Handle AsyncValue - return empty if loading or error
  final currentItems = currentItemsAsync.when(
    data: (items) => items,
    loading: () => <ShoppingItemModel>[],
    error: (_, __) => <ShoppingItemModel>[],
  );

  return await service.getRecommendations(
    currentListItems: currentItems,
    listId: listId,
    limit: 5,
  );
});

/// Loading state for recommendations
final mlRecommendationsLoadingProvider = StateProvider<bool>((ref) => false);
