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

  // The service uses currentListItems to exclude items already on the list
  // from its suggestions, so scoring before that data has arrived (loading
  // or error) would exclude nothing and could recommend items the user
  // already has. Wait for a real value instead of falling back to [].
  final List<ShoppingItemModel>? currentItems = currentItemsAsync.valueOrNull;
  if (currentItems == null) return [];

  return await service.getRecommendations(
    currentListItems: currentItems,
    listId: listId,
    limit: 5,
  );
});
