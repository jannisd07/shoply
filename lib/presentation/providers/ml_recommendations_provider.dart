import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recommendation_item.dart';
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

  // The service scores against the names and categories already on the
  // list, so only a change to those re-runs it — ticking an item off, a
  // price or a reorder does not refetch stats and history. Null while the
  // items are loading: scoring before they arrive would exclude nothing and
  // could recommend items the user already has.
  final itemsKey = ref.watch(itemsNotifierProvider(listId).select((s) {
    final items = s.valueOrNull;
    if (items == null) return null;
    return ([
      for (final i in items) '${i.name.trim().toLowerCase()}|${i.categoryId ?? i.category}',
    ]..sort())
        .join('\n');
  }));
  if (itemsKey == null) return [];

  final currentItems = ref.read(itemsNotifierProvider(listId)).valueOrNull ?? const [];
  return service.getRecommendations(
    currentListItems: currentItems,
    listId: listId,
    limit: 5,
  );
});
