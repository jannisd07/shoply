import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Today's remaining calorie budget, or null when calorie tracking is off,
/// unconfigured, or the user is signed out. autoDispose so a fresh home
/// visit always reflects the latest food log.
final remainingCaloriesTodayProvider = FutureProvider.autoDispose<int?>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return null;
  return CalorieRecipeNudgeService.instance.getRemainingCaloriesToday();
});

/// Up to 3 recipes that fit today's remaining calorie budget, for the home
/// screen's "dinner ideas" card. Empty when tracking is off, nothing is
/// configured, or no stored-nutrition recipe fits.
final calorieRecipeSuggestionsProvider =
    FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final remaining = await ref.watch(remainingCaloriesTodayProvider.future);
  if (remaining == null) return const [];
  final user = await ref.watch(currentUserProvider.future);
  return CalorieRecipeNudgeService.instance.getSuggestions(
    remainingCalories: remaining,
    dietPreferences: user?.dietPreferences ?? const [],
    allergies: user?.allergies ?? const [],
  );
});

/// Whether the user already dismissed today's dinner-ideas card.
final calorieNudgeDismissedProvider = FutureProvider.autoDispose<bool>((ref) async {
  return CalorieRecipeNudgeService.instance.isDismissedToday();
});
