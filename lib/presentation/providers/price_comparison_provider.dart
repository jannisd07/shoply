import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// The user's zip code for nearby-offer lookups (GPS or manual override).
final userZipCodeProvider = FutureProvider<String?>((ref) async {
  return UserLocationService.instance.getZipCode();
});

/// All current offers for a live search query, cheapest first, unfiltered by
/// retailer (used both for the top-3 suggestions and for savings stats).
final offerSearchAllProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  final zip = await ref.watch(userZipCodeProvider.future);
  if (zip == null || zip.isEmpty) return const [];

  return OfferPriceService.instance.searchOffers(query, zipCode: zip);
});

/// Top offers for a live search query (used by the add-bar suggestions).
final offerSuggestionsProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, String>((ref, query) async {
  final offers = await ref.watch(offerSearchAllProvider(query).future);

  // Top 3, preferring distinct retailers so the user sees real alternatives.
  final result = <StoreOffer>[];
  final seenRetailers = <String>{};
  for (final offer in offers) {
    if (seenRetailers.add(offer.retailerUniqueName)) {
      result.add(offer);
      if (result.length == 3) return result;
    }
  }
  for (final offer in offers) {
    if (result.length == 3) break;
    if (!result.contains(offer)) result.add(offer);
  }
  return result;
});

/// Compares the open items of a list across all nearby stores.
final basketComparisonProvider = FutureProvider.autoDispose
    .family<BasketComparison?, String>((ref, listId) async {
  final zip = await ref.watch(userZipCodeProvider.future);
  if (zip == null || zip.isEmpty) return null;

  final items = ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? [];
  final names = items
      .where((i) => !i.isChecked)
      .map((i) => i.name.trim())
      .where((n) => n.length >= 2)
      .take(25) // keep request volume sane for very long lists
      .toList();

  if (names.isEmpty) {
    return BasketComparison(zipCode: zip, itemCount: 0, stores: const []);
  }

  // item name → cheapest offer per retailer
  final perItem = <String, Map<String, StoreOffer>>{};
  for (final name in names) {
    perItem[name] =
        await OfferPriceService.instance.cheapestPerRetailer(name, zipCode: zip);
  }

  final retailerNames = <String, String>{};
  for (final matches in perItem.values) {
    for (final offer in matches.values) {
      retailerNames[offer.retailerUniqueName] = offer.retailerName;
    }
  }

  final stores = retailerNames.entries.map((retailer) {
    final matches = names
        .map((name) => BasketItemMatch(
              itemName: name,
              offer: perItem[name]?[retailer.key],
            ))
        .toList();
    return StoreBasketResult(
      retailerName: retailer.value,
      retailerUniqueName: retailer.key,
      matches: matches,
    );
  }).toList()
    ..sort((a, b) {
      final byCount = b.matchedCount.compareTo(a.matchedCount);
      if (byCount != 0) return byCount;
      return a.total.compareTo(b.total);
    });

  return BasketComparison(
    zipCode: zip,
    itemCount: names.length,
    stores: stores,
  );
});
