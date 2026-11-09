/// The data of "Angebote bei {Markt}" (S9) and "Angebote der Woche" (S10):
/// the offers of the person's lists at their markets, the things they buy
/// often that are on offer, and the free search grouped by market.
///
/// Every provider here is empty, and asks the offers source nothing, while
/// the kill switch is unknown or on, the module is off or there is no real
/// region (`angebote.md` 3.1, 3.15). Markets only filter; they are never
/// played off against each other: no sorting by price or discount, no
/// "günstigster" (3.3).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

/// Offers may be asked for at all: kill switch known on, module on, a real
/// region. Read first, so nothing else is touched while it is false.
bool _offersOpen(Ref ref) =>
    ref.watch(offersRemoteEnabledProvider) &&
    ref.watch(offersAvailableProvider) &&
    ref.watch(regionProvider) != null;

// ---------------------------------------------------------------------------
// "Deine Listen" (S10)
// ---------------------------------------------------------------------------

/// One offer on an open item of a list.
@immutable
class ListOfferEntry {
  const ListOfferEntry({required this.item, required this.offer});

  final ShoppingItemModel item;
  final StoreOffer offer;
}

/// The offers of one list at its market ("Wocheneinkauf · Lidl").
@immutable
class WeeklyListSection {
  const WeeklyListSection({
    required this.listId,
    required this.listName,
    required this.chainId,
    required this.entries,
    required this.complete,
    required this.fetchedAt,
    required this.itemNames,
  });

  final String listId;
  final String listName;
  final String chainId;

  /// In the order of the list's items, never by discount.
  final List<ListOfferEntry> entries;

  /// False when a search of the snapshot failed: an empty section is then
  /// "konnten gerade nicht geladen werden", not "nichts im Angebot".
  final bool complete;

  /// When the offers were fetched ("Angebote vom Stand …" offline).
  final DateTime fetchedAt;

  /// The open items' names the offers were looked up for (pull to refresh).
  final List<String> itemNames;
}

/// The two most recently changed lists with open items and a confirmed
/// market, each with the offers of its market (the 6-h snapshots the list
/// screen shares), in list order. Hidden lists and declined offers stay
/// out; until the hidden lists are known nothing is fetched at all (a cold
/// deep link must not ask for a list whose offers are hidden). Lists
/// without a market have no offers here (no market comparison; the
/// favourites rule K12-03 is not built yet).
final weeklyListSectionsProvider =
    FutureProvider.autoDispose<List<WeeklyListSection>>((ref) async {
      if (!_offersOpen(ref)) return const [];
      // Not loaded yet means "unknown", never "nothing hidden".
      final hidden = ref.watch(hiddenOfferListsProvider);
      if (hidden == null) return const [];
      final region = ref.watch(regionProvider)!;
      final sync = ref.watch(listOfferSyncProvider);
      final markets = <String, String>{
        for (final listId in ref.watch(offerDealListIdsProvider))
          if (!hidden.contains(listId))
            if (ref.watch(storeForListProvider(listId))?.id case final chainId?)
              listId: chainId,
      };
      if (markets.isEmpty) return const [];
      final names = {
        for (final listId in markets.keys)
          listId: ref.watch(offerListNameProvider(listId)) ?? '',
      };
      final prefs = ref.watch(offerDisplayPrefsProvider);
      final now = ref.watch(offerClockProvider)();
      final items = await ref.watch(
        offerDealItemsProvider(markets.keys.join('|')).future,
      );

      final sections = <WeeklyListSection>[];
      for (final MapEntry(key: listId, value: chainId) in markets.entries) {
        // Hidden meanwhile (another screen): no request for it.
        final hiddenNow = ref.read(hiddenOfferListsProvider);
        if (hiddenNow == null || hiddenNow.contains(listId)) continue;
        final open = [
          for (final item in items)
            if (item.listId == listId && !item.isChecked) item,
        ];
        if (open.isEmpty) continue;
        final snapshot = await sync.sync(
          listId: listId,
          chainId: chainId,
          zip: region.zip,
          itemNames: [for (final item in open) item.name],
        );
        final entries = <ListOfferEntry>[
          for (final item in open)
            if (snapshot.offerFor(item.name) case final offer?)
              if (offer.isValidNow &&
                  !(prefs?.isDeclined(item.id, offer.id, now) ?? false))
                ListOfferEntry(item: item, offer: offer),
        ];
        sections.add(
          WeeklyListSection(
            listId: listId,
            listName: names[listId]!,
            chainId: chainId,
            entries: entries,
            complete: snapshot.complete,
            fetchedAt: snapshot.fetchedAt,
            itemNames: [for (final item in open) item.name],
          ),
        );
      }
      return sections;
    });

/// Fetches the offers of the lists in [sections] again (pull to refresh in
/// S10, a person's action) and shows them.
Future<void> refreshWeeklyListOffers(
  WidgetRef ref,
  List<WeeklyListSection> sections,
) async {
  final region = ref.read(regionProvider);
  if (region == null) return;
  final sync = ref.read(listOfferSyncProvider);
  await Future.wait([
    for (final s in sections)
      sync.sync(
        listId: s.listId,
        chainId: s.chainId,
        zip: region.zip,
        itemNames: s.itemNames,
        force: true,
      ),
  ]);
  ref.invalidate(weeklyListSectionsProvider);
}

// ---------------------------------------------------------------------------
// "Oft gekauft" (S9 section, S10 segment)
// ---------------------------------------------------------------------------

/// The person's purchase statistics; override in tests.
final offerPurchaseStatsProvider =
    FutureProvider.autoDispose<List<ItemPurchaseStats>>(
      (ref) => PurchaseTrackingService().getAllStats(),
    );

/// The names (lower case) of open items on all lists; override in tests.
final offerOpenItemNamesProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => AvoNudgeService.openItemNamesLower(),
);

/// Something the person buys often that is on offer this week, at the
/// market they usually buy it at (else their first favourite market).
@immutable
class RegularOffer {
  const RegularOffer({
    required this.name,
    required this.offer,
    required this.chainId,
    required this.averageDays,
    this.quantity,
    this.categoryId,
  });

  /// The item as the person writes it ("Haferflocken").
  final String name;
  final StoreOffer offer;
  final String chainId;

  /// "Kaufst du etwa alle 10 Tage".
  final int averageDays;
  final double? quantity;
  final String? categoryId;
}

/// What "Oft gekauft" can show.
@immutable
class RegularOffers {
  const RegularOffers({required this.hasStats, required this.offers});

  static const none = RegularOffers(hasStats: false, offers: []);

  /// False: too few shopping trips to know what the person buys often.
  final bool hasStats;

  /// Most due first, never by price.
  final List<RegularOffer> offers;
}

/// Regulars count from this many purchases on.
const int _regularMinPurchases = 2;

/// Buying rhythms between these many days count as regular.
const double _regularMinDays = 2;
const double _regularMaxDays = 60;

/// At most this many searches per computation (Kap. 12, rule 10).
const int regularOffersMaxLookups = 6;

/// "Oft gekauft": items bought regularly that are not open on a list, each
/// searched once at its usual market (or the first favourite), most due
/// first. Empty, and nothing read or asked, while offers are closed or
/// "Spar-Hinweise auf der Startseite" is off.
///
/// "Nicht interessiert" is not applied here but where the rows are shown
/// (S9, S10): hiding an offer must take its row away in the same frame, and
/// must not search everything again.
final regularOffersProvider = FutureProvider.autoDispose<RegularOffers>(
  (ref) => _regularOffers(ref),
);

/// [regularOffersProvider] for one market (S9 "Diese Woche bei Lidl, oft
/// gekauft"): only regulars bought there are looked up, so the section
/// never spends its searches on other markets.
final regularOffersAtProvider = FutureProvider.autoDispose
    .family<RegularOffers, String>(
      (ref, chainId) => _regularOffers(ref, onlyChain: chainId),
    );

Future<RegularOffers> _regularOffers(Ref ref, {String? onlyChain}) async {
  if (!_offersOpen(ref)) return RegularOffers.none;
  final on = ref.watch(
    offerDisplayPrefsProvider.select((p) => p?.isOn(OfferSurface.homeTips)),
  );
  if (on != true) return RegularOffers.none;
  final region = ref.watch(regionProvider)!;
  final service = ref.watch(offerPriceServiceProvider);
  final favorites = ref.watch(favoriteStoresProvider);

  final stats = await ref.watch(offerPurchaseStatsProvider.future);
  final regulars = [
    for (final s in stats)
      if (s.purchaseCount >= _regularMinPurchases &&
          s.averageDaysBetween != null &&
          s.averageDaysBetween! >= _regularMinDays &&
          s.averageDaysBetween! <= _regularMaxDays)
        s,
  ];
  if (regulars.isEmpty) return RegularOffers.none;
  final open = await ref.watch(offerOpenItemNamesProvider.future);
  String? marketOf(ItemPurchaseStats s) {
    final usual = s.preferredRetailer;
    return (usual == null ? null : matchChain(usual)) ?? favorites.firstOrNull;
  }

  final candidates =
      regulars
          .where((s) => !open.contains(s.itemName.trim().toLowerCase()))
          .where((s) => onlyChain == null || marketOf(s) == onlyChain)
          .toList()
        ..sort((a, b) {
          double due(ItemPurchaseStats s) =>
              s.daysSinceLastPurchase / s.averageDaysBetween!;
          final byDue = due(b).compareTo(due(a));
          return byDue != 0 ? byDue : a.itemName.compareTo(b.itemName);
        });

  final found = <RegularOffer>[];
  var lookups = 0;
  for (final s in candidates) {
    if (lookups == regularOffersMaxLookups) break;
    final chainId = marketOf(s);
    if (chainId == null) continue;
    lookups++;
    final offers = await service.trySearchOffers(
      s.itemName,
      zipCode: region.zip,
      chainId: chainId,
    );
    final offer = RecipeOfferService.pickRelevantOffer(
      s.itemName,
      offers ?? const [],
      chainId: chainId,
    );
    if (offer == null || !offer.isValidNow) continue;
    found.add(
      RegularOffer(
        name: _capitalized(s.itemName.trim()),
        offer: offer,
        chainId: chainId,
        averageDays: s.averageDaysBetween!.round().clamp(1, 999),
        quantity: s.preferredQuantity,
        categoryId: s.preferredCategory,
      ),
    );
  }
  return RegularOffers(hasStats: true, offers: found);
}

/// [offers] without the ones hidden by "Nicht interessiert" at [now].
List<RegularOffer> interestingRegulars(
  List<RegularOffer> offers,
  OfferDisplayPrefs? prefs,
  DateTime now,
) => [
  for (final r in offers)
    if (!(prefs?.isNotInterested(r.offer.id, now) ?? false)) r,
];

String _capitalized(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

// ---------------------------------------------------------------------------
// Search (S10)
// ---------------------------------------------------------------------------

/// The search of "Angebote der Woche": offers of every market for [query],
/// in the order of the source. From 2 characters, after
/// [offerSearchDebounce]; offline only what an earlier search left on the
/// device. A failed request is an error (shown as such, never as "kein
/// Angebot").
final weeklyOfferSearchProvider = FutureProvider.autoDispose
    .family<List<StoreOffer>, ({String query, bool offline})>((ref, key) async {
      if (!_offersOpen(ref)) return const [];
      final zip = ref.watch(regionProvider)!.zip;
      final service = ref.watch(offerPriceServiceProvider);
      var left = false;
      ref.onCancel(() => left = true);
      ref.onResume(() => left = false);
      final query = key.query.trim();
      if (query.length < 2) return const [];
      if (key.offline) {
        return service.cachedOffers(query, zipCode: zip) ?? const [];
      }
      await Future<void>.delayed(offerSearchDebounce);
      if (left) return const [];
      final offers = await service.trySearchOffers(query, zipCode: zip);
      if (offers == null) throw StateError('offer search failed');
      return offers;
    });

/// One market's hits in the search, in the order of [groupOffersByMarket].
@immutable
class MarketOffers {
  const MarketOffers({required this.chainId, required this.offers});

  final String chainId;
  final List<StoreOffer> offers;
}

/// Groups search hits by market: the markets of the lists first, then the
/// favourites, then the rest alphabetically; inside a market an exact hit
/// before a hit on the head word, else the source's order. Never by price.
List<MarketOffers> groupOffersByMarket(
  String query,
  List<StoreOffer> offers, {
  List<String> listMarkets = const [],
  List<String> favorites = const [],
}) {
  final byChain = <String, List<StoreOffer>>{};
  for (final offer in offers) {
    final chain =
        StoreChainDirectory.byId(offer.retailerUniqueName.toLowerCase())?.id ??
        matchChain(offer.retailerName) ??
        offer.retailerUniqueName.toLowerCase();
    (byChain[chain] ??= []).add(offer);
  }
  String nameOf(String id) =>
      (StoreChainDirectory.byId(id)?.displayName ?? id).toLowerCase();
  int rank(String id) {
    final l = listMarkets.indexOf(id);
    if (l >= 0) return l;
    final f = favorites.indexOf(id);
    if (f >= 0) return listMarkets.length + f;
    return listMarkets.length + favorites.length;
  }

  final term = query.trim().toLowerCase();
  final chains = byChain.keys.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : nameOf(a).compareTo(nameOf(b));
    });
  return [
    for (final chain in chains)
      MarketOffers(
        chainId: chain,
        offers: [
          ...byChain[chain]!.where(
            (o) => o.productName.toLowerCase().contains(term),
          ),
          ...byChain[chain]!.where(
            (o) => !o.productName.toLowerCase().contains(term),
          ),
        ],
      ),
  ];
}
