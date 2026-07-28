import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/home_price_highlight.dart';
import 'package:shoply/data/models/nearby_store.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/home_price_comparison_cache_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/personalized_deals_service.dart';
import 'package:shoply/data/services/store_locator_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// The user's real zip code (GPS or manual override), or null if unknown.
final userZipCodeProvider = FutureProvider<String?>((ref) async {
  return UserLocationService.instance.getZipCode();
});

/// Always-usable zip: real location when known, else a nationwide fallback
/// so search suggestions still work on the simulator / without permission.
final effectiveZipProvider = FutureProvider<ZipInfo>((ref) async {
  return UserLocationService.instance.getZipInfo();
});

/// Raw GPS coordinates, or null when unavailable (permission denied, GPS
/// off, or a manual-zip-only user). Unlike the zip there's no fallback —
/// distance info is simply omitted when this is null.
final userCoordinatesProvider = FutureProvider<UserCoordinates?>((ref) async {
  return UserLocationService.instance.getCoordinates();
});

/// Real nearby supermarket branches (OpenStreetMap), for showing an actual
/// distance next to each store in the comparison sheet. Empty when location
/// is unavailable or the lookup fails — never blocks the price comparison,
/// which works from the zip code alone.
final nearbyStoresProvider = FutureProvider.autoDispose<List<NearbyStore>>((ref) async {
  final coords = await ref.watch(userCoordinatesProvider.future);
  if (coords == null) return const [];
  return StoreLocatorService.instance.findNearbyStores(
    latitude: coords.latitude,
    longitude: coords.longitude,
  );
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

/// Minimum open items a list needs before a home-screen comparison is worth
/// computing at all — avoids a weak claim based on 1-2 items.
const _homeHighlightMinItems = 3;

/// Minimum comparable (matched) items and savings before the highlight is
/// worth surfacing on the home screen — a stricter bar than the in-list
/// comparison sheet, since this is a proactive claim, not something the
/// user asked to see.
const _homeHighlightMinMatched = 3;
const _homeHighlightMinSavings = 1.5;

/// "This list is €X cheaper at [store] than [store]" — Feature 8's home
/// screen surface for Feature 1's price-comparison infra. Checks up to 5
/// recently-updated lists cheaply (unchecked-item count, then real item
/// names — both local reads), but only ever runs the expensive live
/// [basketComparisonProvider] computation for the first one that both
/// qualifies and has no fresh cache entry — so a home-screen visit costs at
/// most one basket comparison, not one per list. Cached per exact
/// (list, items, zip) signature for [HomePriceComparisonCacheService.cacheTtl]
/// so repeat visits with an unchanged list don't re-trigger it at all.
/// Renders nothing (null) when there's no candidate list, no real zip, or no
/// comparison worth showing.
final homePriceHighlightProvider =
    FutureProvider.autoDispose<HomePriceHighlight?>((ref) async {
  final zipInfo = await ref.watch(effectiveZipProvider.future);
  if (!zipInfo.isReal) return null;

  final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
  if (lists.isEmpty) return null;
  final sorted = [...lists]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // Plain repository reads for the candidate scan (not `itemsNotifierProvider`
  // — that creates a persistent StateNotifier with a realtime subscription,
  // which would otherwise leak an open subscription for every candidate list
  // this scans past, not just the one it ends up comparing).
  final itemRepository = ref.watch(itemRepositoryProvider);

  for (final list in sorted.take(5)) {
    if ((list.uncheckedCount ?? 0) < _homeHighlightMinItems) continue;

    final items = await itemRepository.getListItems(list.id);
    final openNames = <String>{
      for (final i in items)
        if (!i.isChecked && i.name.trim().length >= 2) i.name.trim(),
    }.toList()
      ..sort();
    if (openNames.length < _homeHighlightMinItems) continue;

    final signature = '${list.id}|${zipInfo.zipCode}|${openNames.join(',')}';
    final cached = await HomePriceComparisonCacheService.instance.load(signature);
    final highlight = cached.isHit
        ? cached.highlight
        : await _computeAndCacheHighlight(
            ref,
            listId: list.id,
            listName: list.name,
            signature: signature,
            totalItemCount: openNames.length,
          );

    if (highlight == null) return null;
    final dismissed =
        await HomePriceComparisonCacheService.instance.isDismissed(signature);
    return dismissed ? null : highlight;
  }
  return null;
});

Future<HomePriceHighlight?> _computeAndCacheHighlight(
  Ref ref, {
  required String listId,
  required String listName,
  required String signature,
  required int totalItemCount,
}) async {
  final comparison = await ref.watch(basketComparisonProvider(listId).future);
  final highlight = _deriveHomeHighlight(
    comparison,
    listId: listId,
    listName: listName,
    signature: signature,
    totalItemCount: totalItemCount,
  );
  await HomePriceComparisonCacheService.instance.save(signature, highlight);
  return highlight;
}

HomePriceHighlight? _deriveHomeHighlight(
  BasketComparison? comparison, {
  required String listId,
  required String listName,
  required String signature,
  required int totalItemCount,
}) {
  if (comparison == null) return null;
  if (comparison.comparableItemCount < _homeHighlightMinMatched) return null;

  final ranked = comparison.ranked.where((s) => s.matchedCount > 0).toList();
  if (ranked.length < 2) return null;

  final cheapest = ranked.first;
  // Compare against the next-best real alternative, not the priciest
  // outlier — a fair "X cheaper here than there" claim, not a cherry-picked
  // worst case.
  final pricier = ranked[1];
  final savings = pricier.comparableTotal - cheapest.comparableTotal;
  if (savings < _homeHighlightMinSavings) return null;

  return HomePriceHighlight(
    listId: listId,
    listName: listName,
    cheaperRetailerName: cheapest.retailerName,
    pricierRetailerName: pricier.retailerName,
    cheaperTotal: cheapest.comparableTotal,
    savings: savings,
    matchedItemCount: comparison.comparableItemCount,
    totalItemCount: totalItemCount,
    signature: signature,
  );
}

/// How many of the user's most-recently-updated lists to pool open items
/// from for the personalized deals screen — bounded so a home-screen visit
/// never fans out to every list the user has.
const _dealsMaxListsScanned = 2;

/// Real current offers matching items already on the user's shopping lists —
/// the data behind the home screen's "Angebote" entry point and the deals
/// screen's default (no-search) view. Empty (never null) when there are no
/// lists, no open items, or nothing currently on offer. Uses plain repository
/// reads to scan candidate lists (not `itemsNotifierProvider`, which would
/// leak a live realtime subscription per list scanned past — same reasoning
/// as [homePriceHighlightProvider]).
final personalizedDealsProvider =
    FutureProvider.autoDispose<List<RecipeIngredientOffer>>((ref) async {
  final zipInfo = await ref.watch(effectiveZipProvider.future);
  final lists = ref.watch(listsNotifierProvider).valueOrNull ?? const [];
  if (lists.isEmpty) return const [];

  final sorted = [...lists]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final itemRepository = ref.watch(itemRepositoryProvider);

  final pooled = <ShoppingItemModel>[];
  var scannedLists = 0;
  for (final list in sorted) {
    if ((list.uncheckedCount ?? 0) < 1) continue;
    final items = await itemRepository.getListItems(list.id);
    pooled.addAll(items.where((i) => !i.isChecked));
    scannedLists++;
    if (scannedLists == _dealsMaxListsScanned) break;
  }

  final names = PersonalizedDealsService.selectCandidateNames(pooled);
  if (names.isEmpty) return const [];

  return PersonalizedDealsService.instance
      .getMatches(names: names, zipCode: zipInfo.zipCode);
});
