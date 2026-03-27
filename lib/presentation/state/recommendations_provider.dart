import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recommendation_item.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/recommendation_service.dart';

/// Provider for recommendation service
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService();
});

/// Provider for recommendations based on current list items
final recommendationsProvider = FutureProvider.family<List<RecommendationItem>, List<ShoppingItemModel>>(
  (ref, currentItems) async {
    final service = ref.watch(recommendationServiceProvider);
    return await service.getRecommendations(
      currentListItems: currentItems,
      limit: 8,
    );
  },
);

/// State notifier for managing recommendation visibility
class RecommendationsVisibilityNotifier extends StateNotifier<bool> {
  RecommendationsVisibilityNotifier() : super(true); // Expanded by default

  void toggle() {
    state = !state;
  }

  void expand() {
    state = true;
  }

  void collapse() {
    state = false;
  }
}

/// Provider for recommendation section visibility
final recommendationsVisibilityProvider =
    StateNotifierProvider<RecommendationsVisibilityNotifier, bool>((ref) {
  return RecommendationsVisibilityNotifier();
});
