import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';

/// Matches items already on a user's shopping lists against current
/// supermarket offers (Feature 8: the home screen's "Angebote" entry point —
/// previously a decorative, non-tappable strip with no real data behind it).
///
/// Unlike [RecipeOfferService] (which skips pantry staples nobody buys for a
/// single recipe), every open item here is skipped for none — if it's
/// already on the user's list, an offer on it is always worth surfacing.
/// Reuses [RecipeOfferService.pickBestOffer]/[RecipeOfferService.isRelevantMatch]
/// for the actual product-relevance rule, since that logic isn't
/// recipe-specific.
class PersonalizedDealsService {
  PersonalizedDealsService._();
  static final PersonalizedDealsService instance = PersonalizedDealsService._();

  /// Bounds API cost per home-screen visit, same rationale as
  /// [RecipeOfferService.maxCheckedIngredients].
  static const maxCheckedItems = 10;

  /// Distinct, worth-checking item names from [openItems]: trimmed, ≥2 chars
  /// (matches [OfferPriceService.searchOffers]'s own minimum), de-duplicated
  /// case-insensitively (first spelling wins — callers should pass
  /// most-recently-updated items first), capped at [maxCheckedItems].
  static List<String> selectCandidateNames(List<ShoppingItemModel> openItems) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in openItems) {
      final trimmed = item.name.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.length < 2) continue;
      if (!seen.add(normalized)) continue;
      result.add(trimmed);
      if (result.length == maxCheckedItems) break;
    }
    return result;
  }

  /// Current offers for [names] around [zipCode], best deal first (highest
  /// discount, then cheapest). Never throws — a failed search for one name
  /// simply yields no match for it.
  Future<List<RecipeIngredientOffer>> getMatches({
    required List<String> names,
    required String zipCode,
  }) async {
    if (names.isEmpty) return const [];

    final fetched = await Future.wait(names.map((name) async {
      final offers =
          await OfferPriceService.instance.searchOffers(name, zipCode: zipCode);
      return MapEntry(name, RecipeOfferService.pickBestOffer(name, offers));
    }));

    final matches = <RecipeIngredientOffer>[
      for (final entry in fetched)
        if (entry.value != null)
          RecipeIngredientOffer.fromStoreOffer(entry.key, entry.value!),
    ]..sort((a, b) {
        final aDiscount = a.discountPercent ?? -1;
        final bDiscount = b.discountPercent ?? -1;
        if (aDiscount != bDiscount) return bDiscount - aDiscount;
        return a.price.compareTo(b.price);
      });
    return matches;
  }
}
