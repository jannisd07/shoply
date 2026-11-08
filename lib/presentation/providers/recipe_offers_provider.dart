/// Offers for a recipe's ingredients at the market of one list (S15,
/// `angebote.md`): the row in the recipe detail, the screen "Angebote für
/// {Rezept}" and the pills at the ingredient rows. Only the target list's
/// confirmed market counts (no store comparison), pantry staples never
/// count, and nothing is shown or asked while offers may not show on that
/// list (kill switch, module, hidden list, no real region, "Angebote an
/// Artikeln" off) or the list has no market.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

/// Where recipe offers come from; override in tests.
abstract interface class RecipeOfferSource {
  /// What the device has, without a request; null when nothing is cached.
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  });

  /// The offers, from the 6-h cache or the source.
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  });
}

class _ServiceSource implements RecipeOfferSource {
  const _ServiceSource();

  @override
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) => RecipeOfferService.instance.cachedOffers(
    recipeId: recipeId,
    ingredientNames: ingredientNames,
    zipCode: zipCode,
    chainId: chainId,
  );

  @override
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) => RecipeOfferService.instance.getOffers(
    recipeId: recipeId,
    ingredientNames: ingredientNames,
    zipCode: zipCode,
    chainId: chainId,
  );
}

final recipeOfferSourceProvider = Provider<RecipeOfferSource>(
  (ref) => const _ServiceSource(),
);

/// What the recipe offers are asked for: the recipe, its ingredient names
/// (joined with a line break, so the key compares by value) and the target
/// list.
typedef RecipeOfferKey = ({String recipeId, String names, String listId});

/// The key for [recipeId] with [ingredientNames] and the target [listId].
RecipeOfferKey recipeOfferKey(
  String recipeId,
  Iterable<String> ingredientNames,
  String listId,
) => (recipeId: recipeId, names: ingredientNames.join('\n'), listId: listId);

/// The offers of a recipe at the market of its target list.
@immutable
class RecipeListOffers {
  const RecipeListOffers({
    required this.chainId,
    required this.matches,
    required this.checked,
  });

  final String chainId;

  /// In the recipe's order; only current offers.
  final List<RecipeIngredientOffer> matches;

  /// How many ingredients were looked up ("von 9 Zutaten"): pantry staples
  /// and duplicates do not count.
  final int checked;
}

/// The market the offers of [listId] are for, once offers may show there
/// at all; null otherwise.
String? _gate(Ref ref, String listId) {
  final visible = ref.watch(
    offerSurfaceVisibleProvider((
      surface: OfferSurface.itemOffers,
      listId: listId,
    )),
  );
  if (!visible) return null;
  return ref.watch(storeForListProvider(listId))?.id;
}

RecipeListOffers? _valid(RecipeOffersResult? result, String chainId) {
  if (result == null) return null;
  return RecipeListOffers(
    chainId: chainId,
    matches: [
      for (final m in result.matches)
        if (m.isStillValid) m,
    ],
    checked: result.checkedIngredientCount,
  );
}

/// "3 Zutaten diese Woche bei Lidl im Angebot …" in the recipe detail: only
/// what the device already has when the detail opens, so the row never
/// pushes the instructions down. On a miss it asks the source in the
/// background, so the next opening has the answer; null meanwhile.
final recipeOffersCachedProvider = FutureProvider.autoDispose
    .family<RecipeListOffers?, RecipeOfferKey>((ref, key) async {
      final chainId = _gate(ref, key.listId);
      final region = ref.watch(regionProvider);
      if (chainId == null || region == null) return null;
      final names = key.names.isEmpty
          ? const <String>[]
          : key.names.split('\n');
      if (RecipeOfferService.eligibleIngredientNames(names).isEmpty) {
        return null;
      }
      final source = ref.watch(recipeOfferSourceProvider);
      final cached = await source.cachedOffers(
        recipeId: key.recipeId,
        ingredientNames: names,
        zipCode: region.zip,
        chainId: chainId,
      );
      if (cached == null) {
        // For the next opening; nothing shows from it now.
        source
            .getOffers(
              recipeId: key.recipeId,
              ingredientNames: names,
              zipCode: region.zip,
              chainId: chainId,
            )
            .ignore();
        return null;
      }
      return _valid(cached, chainId);
    });

/// The offers of the screen "Angebote für {Rezept}": from the 6-h cache or
/// the source. Null while offers may not show on the list or it has no
/// market. A failed search makes an incomplete (uncached) answer.
final recipeOffersProvider = FutureProvider.autoDispose
    .family<RecipeListOffers?, RecipeOfferKey>((ref, key) async {
      final chainId = _gate(ref, key.listId);
      final region = ref.watch(regionProvider);
      if (chainId == null || region == null) return null;
      final names = key.names.isEmpty
          ? const <String>[]
          : key.names.split('\n');
      final result = await ref
          .watch(recipeOfferSourceProvider)
          .getOffers(
            recipeId: key.recipeId,
            ingredientNames: names,
            zipCode: region.zip,
            chainId: chainId,
          );
      return _valid(result, chainId);
    });

/// The ingredient offers that the recipe row or screen found for each list
/// in this session, by list and ingredient name (lower case), for the pills
/// at the ingredient rows (`IngredientOfferBadge`).
class RecipeIngredientOffersNotifier
    extends StateNotifier<Map<String, Map<String, RecipeIngredientOffer>>> {
  RecipeIngredientOffersNotifier() : super(const {});

  /// Keeps [offers] of [listId]; the pills follow at once.
  void remember(String listId, RecipeListOffers offers) {
    final next = {
      ...?state[listId],
      for (final m in offers.matches) m.ingredientName.trim().toLowerCase(): m,
    };
    if (mapEquals(next, state[listId])) return;
    state = {...state, listId: next};
  }
}

final recipeIngredientOffersProvider =
    StateNotifierProvider<
      RecipeIngredientOffersNotifier,
      Map<String, Map<String, RecipeIngredientOffer>>
    >((ref) => RecipeIngredientOffersNotifier());

/// The current offer for the ingredient [name] at the market of [listId],
/// if the recipe row found one; null while offers may not show there.
final recipeIngredientOfferProvider = Provider.autoDispose
    .family<RecipeIngredientOffer?, ({String listId, String name})>((ref, key) {
      if (_gate(ref, key.listId) == null) return null;
      final offer = ref.watch(
        recipeIngredientOffersProvider.select(
          (m) => m[key.listId]?[key.name.trim().toLowerCase()],
        ),
      );
      return offer != null && offer.isStillValid ? offer : null;
    });
