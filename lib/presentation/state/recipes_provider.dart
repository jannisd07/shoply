import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to trigger recipe data refresh across screens.
/// Increment this to force all recipe screens to refresh.
final recipeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Helper to refresh all recipe data
void refreshRecipeData(WidgetRef ref) {
  ref.read(recipeRefreshTriggerProvider.notifier).state++;
}
