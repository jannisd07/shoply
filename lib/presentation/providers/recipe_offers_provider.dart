import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

/// Family key for [recipeOffersProvider]: a recipe plus the exact ingredient
/// names to check. Value equality (not identity) so rebuilding the detail
/// screen with the same recipe reuses the same provider instance.
class RecipeOffersRequest {
  final String recipeId;
  final List<String> ingredientNames;

  const RecipeOffersRequest({
    required this.recipeId,
    required this.ingredientNames,
  });

  String get _key => '$recipeId|${ingredientNames.join(',')}';

  @override
  bool operator ==(Object other) =>
      other is RecipeOffersRequest && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// Current offers for a recipe's ingredients (Feature 8's "this recipe is
/// cheaper this week" surface). Null when the user has no real zip code
/// (GPS or manual) — like the home price highlight, this is a proactive
/// claim, and nationwide-fallback offers may simply not exist at the user's
/// actual local stores. Expired matches (cached past an offer's end date)
/// are filtered out at read time.
final recipeOffersProvider = FutureProvider.autoDispose
    .family<RecipeOffersResult?, RecipeOffersRequest>((ref, request) async {
  final zipInfo = await ref.watch(effectiveZipProvider.future);
  if (!zipInfo.isReal) return null;

  final result = await RecipeOfferService.instance.getOffers(
    recipeId: request.recipeId,
    ingredientNames: request.ingredientNames,
    zipCode: zipInfo.zipCode,
  );

  final valid = result.matches.where((m) => m.isStillValid).toList();
  return valid.length == result.matches.length
      ? result
      : result.copyWithMatches(valid);
});
