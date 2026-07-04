import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';

/// The user's real zip code (GPS or manual override), or null if unknown.
final userZipCodeProvider = FutureProvider<String?>((ref) async {
  return UserLocationService.instance.getZipCode();
});

/// Always-usable zip: real location when known, else a nationwide fallback
/// so search suggestions still work on the simulator / without permission.
final effectiveZipProvider = FutureProvider<ZipInfo>((ref) async {
  return UserLocationService.instance.getZipInfo();
});

/// All current offers for a live search query, unfiltered by retailer
/// (used both for the top-3 suggestions and for savings stats).
final offerSearchAllProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  final zipInfo = await ref.watch(effectiveZipProvider.future);
  final zip = zipInfo.zipCode;

  return OfferPriceService.instance.searchOffers(query, zipCode: zip);
});

/// Top offers for a live search query (used by the add-bar suggestions).
final offerSuggestionsProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, String>((ref, query) async {
  final offers = await ref.watch(offerSearchAllProvider(query).future);

  // Relevance: offers whose product name actually contains the query rank
  // above loose matches (so "Milch" doesn't surface "Sahne Joghurt" first),
  // then cheapest first.
  final q = query.trim().toLowerCase();
  final sorted = List<StoreOffer>.from(offers)
    ..sort((a, b) {
      final aMatch = a.productName.toLowerCase().contains(q) ? 0 : 1;
      final bMatch = b.productName.toLowerCase().contains(q) ? 0 : 1;
      if (aMatch != bMatch) return aMatch - bMatch;
      return a.price.compareTo(b.price);
    });

  // Top 3, preferring distinct retailers so the user sees real alternatives.
  final result = <StoreOffer>[];
  final seenRetailers = <String>{};
  for (final offer in sorted) {
    if (seenRetailers.add(offer.retailerUniqueName)) {
      result.add(offer);
      if (result.length == 3) return result;
    }
  }
  for (final offer in sorted) {
    if (result.length == 3) break;
    if (!result.contains(offer)) result.add(offer);
  }
  return result;
});

/// Compares the open items of a list across all nearby stores.
final basketComparisonProvider = FutureProvider.autoDispose
    .family<BasketComparison?, String>((ref, listId) async {
  final zipInfo = await ref.watch(effectiveZipProvider.future);
  final zip = zipInfo.zipCode;

  final items = ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? [];
  final names = items
      .where((i) => !i.isChecked)
      .map((i) => i.name.trim())
      .where((n) => n.length >= 2)
      .take(25) // keep request volume sane for very long lists
      .toList();

  if (names.isEmpty) {
    return BasketComparison(
        zipCode: zip, comparableItemCount: 0, stores: const []);
  }

  // item name → cheapest offer per retailer. Fetched concurrently (the
  // service's internal throttle still spaces out actual request starts) —
  // sequential awaits here would mean ~1s per item, i.e. 20+ seconds for a
  // full basket before showing any comparison at all.
  final fetched = await Future.wait(names.map((name) async {
    final result =
        await OfferPriceService.instance.cheapestPerRetailer(name, zipCode: zip);
    return MapEntry(name, result);
  }));
  final perItem = <String, Map<String, StoreOffer>>{
    for (final entry in fetched) entry.key: entry.value,
  };

  // Items that at least one store offers form the comparable basket; for each
  // such item remember the cheapest price anywhere (the "fill" price used when
  // a store doesn't carry it, so every store's total covers the same basket).
  final comparableItems = names.where((n) {
    final m = perItem[n];
    return m != null && m.isNotEmpty;
  }).toList();

  final fillPrice = <String, double>{};
  for (final name in comparableItems) {
    fillPrice[name] = perItem[name]!
        .values
        .map((o) => o.price)
        .reduce((a, b) => a < b ? a : b);
  }

  final retailerNames = <String, String>{};
  for (final matches in perItem.values) {
    for (final offer in matches.values) {
      retailerNames[offer.retailerUniqueName] = offer.retailerName;
    }
  }

  final stores = retailerNames.entries.map((retailer) {
    final matches = comparableItems
        .map((name) => BasketItemMatch(
              itemName: name,
              offer: perItem[name]?[retailer.key],
            ))
        .toList();
    // Comparable total: own offer where available, else cheapest-anywhere fill.
    final comparableTotal = comparableItems.fold<double>(0, (sum, name) {
      final own = perItem[name]?[retailer.key];
      return sum + (own?.price ?? fillPrice[name] ?? 0);
    });
    return StoreBasketResult(
      retailerName: retailer.value,
      retailerUniqueName: retailer.key,
      matches: matches,
      comparableTotal: comparableTotal,
    );
  }).toList();

  return BasketComparison(
    zipCode: zip,
    comparableItemCount: comparableItems.length,
    stores: stores,
  );
});
