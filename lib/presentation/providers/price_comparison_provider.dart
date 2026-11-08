/// The offer providers behind the list slots, the add field, Home and the
/// weekly offers (Kap. 12). Every one of them is empty, and asks the offers
/// source nothing, without a real region ([regionProvider]), while offers
/// are unavailable ([offersAvailableProvider]: module or kill switch) or
/// hidden on the list. Offers only ever come from one market, the list's
/// confirmed one ([storeForListProvider]): no market comparison, no basket
/// total, no ranking of stores (rule 2).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// A typed search asks the source only after this pause (Kap. 12, rule 10).
const Duration offerSearchDebounce = Duration(milliseconds: 300);

/// The offers source; override in tests.
final offerPriceServiceProvider = Provider<OfferPriceService>(
  (ref) => OfferPriceService.instance,
);

/// The 6-h offer snapshots of the lists; override in tests (clock).
final listOfferSyncProvider = Provider<ListOfferSync>(
  (ref) => ListOfferSync(ref.watch(offerPriceServiceProvider)),
);

/// The items of a list as the offer providers see them; override in tests.
final offerListItemsProvider = Provider.autoDispose
    .family<List<ShoppingItemModel>, String>(
      (ref, listId) =>
          ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? const [],
    );

// ---------------------------------------------------------------------------
// Typed search
// ---------------------------------------------------------------------------

/// Offers of every market for a typed search, in the order of the source
/// (relevance), for the weekly offers search, which groups them by market
/// and never sorts by price. From 2 characters, after [offerSearchDebounce];
/// nothing is asked when the search was left (typed on) meanwhile.
final offerSearchAllProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, String>((ref, query) async {
      final service = ref.watch(offerPriceServiceProvider);
      final region = ref.watch(regionProvider);
      final left = _watchLeft(ref);
      if (!ref.watch(offersAvailableProvider) || region == null)
        return const [];
      if (!await _debounce(query, left)) return const [];
      return service.searchOffers(query, zipCode: region.zip);
    });

/// What [offerSuggestionsProvider] is asked for.
typedef OfferSuggestionsRequest = ({String listId, String query});

/// Offers for the text typed in a list's add field: only the list's market,
/// in the order of the source; similar products of that market only when
/// it has no exact hit. Empty without a confirmed market,
/// without a region, or while offers are off or hidden on the list.
final offerSuggestionsProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, OfferSuggestionsRequest>((ref, request) async {
      final listId = request.listId;
      final service = ref.watch(offerPriceServiceProvider);
      final region = ref.watch(regionProvider);
      final chainId = ref.watch(storeForListProvider(listId))?.id;
      final left = _watchLeft(ref);
      final visible = _watchVisibleOn(ref, listId);
      if (region == null || chainId == null) return const [];
      if (!await visible) return const [];
      if (!await _debounce(request.query, left)) return const [];
      return service.searchOffers(
        request.query,
        zipCode: region.zip,
        chainId: chainId,
      );
    });

/// True once every listener left the provider (the person typed on).
ValueGetter<bool> _watchLeft(Ref ref) {
  var left = false;
  ref.onCancel(() => left = true);
  ref.onResume(() => left = false);
  return () => left;
}

/// Waits [offerSearchDebounce]; false when [query] is too short or the
/// search was [left] meanwhile.
Future<bool> _debounce(String query, ValueGetter<bool> left) async {
  if (query.trim().length < 2) return false;
  await Future<void>.delayed(offerSearchDebounce);
  return !left();
}

/// Whether offers may show on [listId]: available (module and kill switch)
/// and not hidden there. Waits for the saved "hide" choices, so a hidden
/// list never asks the source.
Future<bool> _watchVisibleOn(Ref ref, String listId) async {
  if (!ref.watch(offersAvailableProvider)) return false;
  final hidden = await _followHiddenLists(ref);
  return !hidden.contains(listId);
}

/// The ids of the lists with hidden offers, once the saved choices are
/// loaded. A later change rebuilds the provider; the first load does not,
/// so a pending answer is never thrown away mid-request.
Future<Set<String>> _followHiddenLists(Ref ref) {
  ref.listen<Set<String>?>(hiddenOfferListsProvider, (previous, next) {
    if (previous != null) ref.invalidateSelf();
  });
  final ids = ref.read(hiddenOfferListsProvider);
  if (ids != null) return Future.value(ids);
  return ref
      .read(hiddenOfferListsProvider.notifier)
      .stream
      .firstWhere((ids) => ids != null)
      .then((ids) => ids!);
}

// ---------------------------------------------------------------------------
// Offers of a list (6-h snapshot of the list's market)
// ---------------------------------------------------------------------------

/// The offers found for a list's items at its market around one zip code.
@immutable
class ListOfferSnapshot {
  const ListOfferSnapshot({
    required this.chainId,
    required this.zip,
    required this.fetchedAt,
    required this.offersByName,
    this.complete = true,
  });

  final String chainId;
  final String zip;
  final DateTime fetchedAt;

  /// Offer per item name (trimmed, lower case); names without one are
  /// missing.
  final Map<String, StoreOffer> offersByName;

  /// False when a search failed; such a snapshot is tried again sooner and
  /// never stored.
  final bool complete;

  /// The offer for an item called [name], if it was on offer.
  StoreOffer? offerFor(String name) => offersByName[offerNameKey(name)];

  Map<String, Object?> toJson() => {
    'chainId': chainId,
    'zip': zip,
    'fetchedAt': fetchedAt.toIso8601String(),
    'offers': {
      for (final entry in offersByName.entries)
        entry.key: {
          'offer': entry.value.toJson(),
          'broad': entry.value.isBroadMatch,
        },
    },
  };

  static ListOfferSnapshot? fromJson(Map<String, dynamic> json) {
    final chainId = json['chainId'] as String?;
    final zip = json['zip'] as String?;
    final fetchedAt = DateTime.tryParse(json['fetchedAt'] as String? ?? '');
    final offers = json['offers'] as Map<String, dynamic>?;
    if (chainId == null || zip == null || fetchedAt == null || offers == null) {
      return null;
    }
    final byName = <String, StoreOffer>{};
    for (final entry in offers.entries) {
      final value = entry.value as Map<String, dynamic>;
      final offer = StoreOffer.fromJson(value['offer'] as Map<String, dynamic>);
      if (offer == null) continue;
      byName[entry.key] = value['broad'] == true ? offer.asBroadMatch() : offer;
    }
    return ListOfferSnapshot(
      chainId: chainId,
      zip: zip,
      fetchedAt: fetchedAt,
      offersByName: byName,
    );
  }
}

/// The key of an item name in a [ListOfferSnapshot].
String offerNameKey(String name) => name.trim().toLowerCase();

/// Fetches the offers of a list's items at the list's market at most every
/// [maxAge] (Kap. 12, rule 10), keeps the result on the device across app
/// starts and shares one fetch between concurrent callers. Checking off and
/// adding items count locally from the snapshot, without a request.
class ListOfferSync {
  ListOfferSync(this._service, {DateTime Function() now = DateTime.now})
    : _now = now;

  final OfferPriceService _service;
  final DateTime Function() _now;

  /// How long a complete snapshot of a list stays current.
  static const maxAge = Duration(hours: 6);

  /// How long a snapshot with a failed search stays before the next try.
  static const retryAfter = Duration(minutes: 30);

  /// At most this many item names per list are looked up.
  static const maxItems = 25;

  /// The names of [itemNames] that are looked up: trimmed, at least two
  /// characters ("Ei" counts), each once (first spelling wins), pantry
  /// staples included, at most [maxItems], in list order.
  static List<String> namesToCheck(Iterable<String> itemNames) {
    final seen = <String>{};
    final names = <String>[];
    for (final name in itemNames) {
      final trimmed = name.trim();
      if (trimmed.length < 2 || !seen.add(offerNameKey(trimmed))) continue;
      names.add(trimmed);
      if (names.length == maxItems) break;
    }
    return names;
  }

  /// Snapshots kept in memory, least recently used out.
  static const _memorySize = 200;
  static const _prefsPrefix = 'offers_list_snapshot_v1:';

  final LinkedHashMap<String, ListOfferSnapshot> _memory = LinkedHashMap();
  final Map<String, Future<ListOfferSnapshot>> _inFlight = {};

  /// The snapshot of [listId] at [chainId] around [zip] for [itemNames];
  /// fetched only when there is none for that market and region or it is
  /// older than [maxAge].
  Future<ListOfferSnapshot> sync({
    required String listId,
    required String chainId,
    required String zip,
    required List<String> itemNames,
  }) async {
    final cached = _memory.remove(listId) ?? await _load(listId);
    if (cached != null) {
      _remember(listId, cached);
      if (_isCurrent(cached, chainId, zip)) return cached;
    }
    final key = '$listId|$chainId|$zip';
    // Block body: an arrow would return the removed future, i.e. this very
    // future, and whenComplete would wait on itself forever.
    return _inFlight[key] ??= _fetch(listId, chainId, zip, itemNames)
        .whenComplete(() {
          _inFlight.remove(key);
        });
  }

  /// The snapshot of [listId] already in memory, without any wait.
  ListOfferSnapshot? peek(String listId) => _memory[listId];

  /// The last snapshot of [listId] on this device (memory, then storage),
  /// however old, without asking the offers source. For surfaces that may
  /// only show what is cached (list cards, the offer detail).
  Future<ListOfferSnapshot?> cached(String listId) async {
    final known = _memory[listId];
    if (known != null) return known;
    final loaded = await _load(listId);
    if (loaded != null && !_memory.containsKey(listId)) {
      _remember(listId, loaded);
    }
    return _memory[listId] ?? loaded;
  }

  bool _isCurrent(ListOfferSnapshot snapshot, String chainId, String zip) {
    if (snapshot.chainId != chainId || snapshot.zip != zip) return false;
    final age = _now().difference(snapshot.fetchedAt);
    return age < (snapshot.complete ? maxAge : retryAfter);
  }

  Future<ListOfferSnapshot> _fetch(
    String listId,
    String chainId,
    String zip,
    List<String> itemNames,
  ) async {
    final names = namesToCheck(itemNames);
    var complete = true;
    final found = await Future.wait(
      names.map((name) async {
        final offers = await _service.trySearchOffers(
          name,
          zipCode: zip,
          chainId: chainId,
        );
        if (offers == null) complete = false;
        final offer = RecipeOfferService.pickRelevantOffer(
          name,
          offers ?? const [],
          chainId: chainId,
        );
        return MapEntry(offerNameKey(name), offer);
      }),
    );
    final snapshot = ListOfferSnapshot(
      chainId: chainId,
      zip: zip,
      fetchedAt: _now(),
      offersByName: {
        for (final entry in found)
          if (entry.value != null) entry.key: entry.value!,
      },
      complete: complete,
    );
    debugPrint(
      '✅ [OFFERS] List offers: ${snapshot.offersByName.length}/'
      '${names.length} items on offer at $chainId',
    );
    _remember(listId, snapshot);
    if (complete) await _save(listId, snapshot);
    return snapshot;
  }

  void _remember(String listId, ListOfferSnapshot snapshot) {
    _memory.remove(listId);
    _memory[listId] = snapshot;
    while (_memory.length > _memorySize) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<ListOfferSnapshot?> _load(String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$listId');
      if (raw == null) return null;
      return ListOfferSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('⚠️ [OFFERS] List offers not read: $e');
      return null;
    }
  }

  Future<void> _save(String listId, ListOfferSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsPrefix$listId',
        jsonEncode(snapshot.toJson()),
      );
    } catch (e) {
      debugPrint('⚠️ [OFFERS] List offers not saved: $e');
    }
  }
}

/// The 6-h offer snapshot of [listId] at its confirmed market; null without
/// a market, a region, open items, or while offers are off or hidden on the
/// list. Follows item changes without a request while the snapshot is
/// current: new offers come with the next sync, when the list is opened
/// again (K12-02).
final listOfferSnapshotProvider = FutureProvider.autoDispose
    .family<ListOfferSnapshot?, String>((ref, listId) async {
      final sync = ref.watch(listOfferSyncProvider);
      final region = ref.watch(regionProvider);
      final chainId = ref.watch(storeForListProvider(listId))?.id;
      final namesKey = ref.watch(
        offerListItemsProvider(listId).select(_openNamesKey),
      );
      final visible = _watchVisibleOn(ref, listId);
      if (region == null || chainId == null || namesKey.isEmpty) return null;
      if (!await visible) return null;
      return sync.sync(
        listId: listId,
        chainId: chainId,
        zip: region.zip,
        itemNames: namesKey.split('\n'),
      );
    });

String _openNamesKey(List<ShoppingItemModel> items) => [
  for (final item in items)
    if (!item.isChecked && item.name.trim().length >= 2) item.name.trim(),
].join('\n');

/// The current offer of the list's market per open item id of [listId];
/// empty while offers may not show there. An offer the person hid for an
/// item ("Nicht dieses Angebot") is left out until it ends.
final listItemOffersProvider = Provider.autoDispose
    .family<Map<String, StoreOffer>, String>((ref, listId) {
      final snapshot = ref.watch(listOfferSnapshotProvider(listId)).valueOrNull;
      final chainId = ref.watch(storeForListProvider(listId))?.id;
      if (!ref.watch(offersVisibleForListProvider(listId)) ||
          ref.watch(regionProvider) == null ||
          snapshot == null ||
          snapshot.chainId != chainId) {
        return const {};
      }
      final items = ref.watch(offerListItemsProvider(listId));
      final prefs = ref.watch(offerDisplayPrefsProvider);
      final now = ref.watch(offerClockProvider)();
      return {
        for (final item in items)
          if (!item.isChecked)
            if (snapshot.offerFor(item.name) case final offer?)
              if (offer.isValidNow &&
                  !(prefs?.isDeclined(item.id, offer.id, now) ?? false))
                item.id: offer,
      };
    });

/// The key of [itemOfferProvider].
typedef ItemOfferKey = ({String listId, String itemId});

/// The current offer of the list's market for one item (`ItemOfferBadge`,
/// `ItemOfferCard`); null for a checked item or without one.
final itemOfferProvider = Provider.autoDispose
    .family<StoreOffer?, ItemOfferKey>(
      (ref, key) => ref.watch(
        listItemOffersProvider(
          key.listId,
        ).select((offers) => offers[key.itemId]),
      ),
    );

/// "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart,
/// in deiner Region" for [listId] (`ListOfferSummary`); null when nothing
/// is on offer or offers may not show.
final listOfferSummaryProvider = Provider.autoDispose
    .family<OfferSummary?, String>((ref, listId) {
      final offers = ref.watch(listItemOffersProvider(listId));
      final store = ref.watch(storeForListProvider(listId));
      if (offers.isEmpty || store == null) return null;
      return summarizeListOffers(
        chainId: store.id,
        openItems: ref.watch(offerListItemsProvider(listId)),
        offersByItemId: offers,
        realRegion: ref.watch(regionProvider) != null,
      );
    });

/// "2 Angebote" on the cover of a list card (`ListOfferCountBadge`).
final listOfferCountProvider = Provider.autoDispose.family<int, String>(
  (ref, listId) => ref.watch(listOfferSummaryProvider(listId))?.matched ?? 0,
);

// ---------------------------------------------------------------------------
// Deals of the lists (Home, weekly offers "Deine Listen")
// ---------------------------------------------------------------------------

/// How many of the most recently changed lists with open items the deals
/// look at, so a Home visit never fans out to every list.
const _dealsMaxLists = 2;

/// The ids of the [_dealsMaxLists] most recently changed lists with open
/// items; override in tests.
final offerDealListIdsProvider = Provider.autoDispose<List<String>>(
  (ref) => [
    for (final list in _recentListsWithOpenItems(
      ref,
      minOpenItems: 1,
    ).take(_dealsMaxLists))
      list.id,
  ],
);

/// The open items of the lists in [listIds] ('|'-joined), in one query;
/// override in tests. Plain repository reads, not `itemsNotifierProvider`,
/// which would keep a realtime subscription alive per list scanned.
final offerDealItemsProvider = FutureProvider.autoDispose
    .family<List<ShoppingItemModel>, String>((ref, listIds) async {
      final items = await ref
          .read(itemRepositoryProvider)
          .getItemsForLists(listIds.split('|'));
      return [
        for (final item in items)
          if (!item.isChecked) item,
      ];
    });

/// Offers on items of the user's lists, each from its list's market, in the
/// order of the lists and their items (never by discount or price). Shares
/// the 6-h snapshots with the list screen. Empty without a region, while
/// offers are off, and for lists without a confirmed market or with hidden
/// offers.
final personalizedDealsProvider =
    FutureProvider.autoDispose<List<RecipeIngredientOffer>>((ref) async {
      final sync = ref.watch(listOfferSyncProvider);
      final region = ref.watch(regionProvider);
      if (!ref.watch(offersAvailableProvider) || region == null)
        return const [];
      final markets = <String, String>{
        for (final listId in ref.watch(offerDealListIdsProvider))
          if (ref.watch(storeForListProvider(listId))?.id case final chainId?)
            listId: chainId,
      };
      if (markets.isEmpty) return const [];
      final hiddenLists = _followHiddenLists(ref);
      final itemsOfLists = ref.watch(
        offerDealItemsProvider(markets.keys.join('|')).future,
      );
      final hidden = await hiddenLists;
      final items = await itemsOfLists;

      final deals = <RecipeIngredientOffer>[];
      final seen = <String>{};
      for (final MapEntry(key: listId, value: chainId) in markets.entries) {
        if (hidden.contains(listId)) continue;
        final openItems = [
          for (final item in items)
            if (item.listId == listId) item,
        ];
        if (openItems.isEmpty) continue;
        final snapshot = await sync.sync(
          listId: listId,
          chainId: chainId,
          zip: region.zip,
          itemNames: [for (final item in openItems) item.name],
        );
        for (final item in openItems) {
          final offer = snapshot.offerFor(item.name);
          if (offer == null || !offer.isValidNow) continue;
          if (!seen.add(offerNameKey(item.name))) continue;
          deals.add(
            RecipeIngredientOffer.fromStoreOffer(item.name.trim(), offer),
          );
        }
      }
      return deals;
    });

/// The user's lists, most recently updated first, with at least
/// [minOpenItems] unchecked items.
///
/// Watches only that selection (ids and open counts), not the whole lists
/// value, so a realtime reload that changes nothing relevant does not re-run
/// the deals.
List<ShoppingListModel> _recentListsWithOpenItems(
  Ref ref, {
  required int minOpenItems,
}) {
  List<ShoppingListModel> pick(List<ShoppingListModel>? lists) {
    final sorted = [...?lists]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      for (final list in sorted)
        if ((list.uncheckedCount ?? 0) >= minOpenItems) list,
    ];
  }

  final key = ref.watch(
    listsNotifierProvider.select(
      (s) => pick(
        s.valueOrNull,
      ).map((l) => '${l.id}:${l.uncheckedCount}').join('|'),
    ),
  );
  if (key.isEmpty) return const [];
  return pick(ref.read(listsNotifierProvider).valueOrNull);
}

// ---------------------------------------------------------------------------
// Transition for callers outside this package (delete once they switched)
// ---------------------------------------------------------------------------

/// The offer of the list's market per item name, for the item rows of
/// `list_category_section.dart` (Teil A) until they use `ItemOfferBadge`.
/// There is no basket comparison any more.
@Deprecated('Use ItemOfferBadge or itemOfferProvider')
final basketComparisonProvider = FutureProvider.autoDispose
    .family<ListMarketOffers, String>((ref, listId) {
      final offers = ref.watch(listItemOffersProvider(listId));
      final items = ref.watch(offerListItemsProvider(listId));
      return ListMarketOffers._({
        for (final item in items)
          if (offers[item.id] case final offer?) item.name.trim(): offer,
      });
    });

/// See [basketComparisonProvider].
@Deprecated('Use ItemOfferBadge or itemOfferProvider')
class ListMarketOffers {
  const ListMarketOffers._(this._byName);

  final Map<String, StoreOffer> _byName;

  /// The offer of the list's market for the open item called [name]. The
  /// name is the old call of Teil A; nothing is compared.
  StoreOffer? cheapestOfferFor(String name) => _byName[name];
}
