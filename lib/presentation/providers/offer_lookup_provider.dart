/// Offers read only from what the device already has (`angebote.md` 3.2,
/// Lücke L2): the offer of the detail screen by id, and the counter on a
/// list card. Nothing here asks the offers source.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Offers the person saw in this session, by id, so the offer detail opens
/// from the surface that showed it without a request (at most 200, least
/// recently used out).
class OfferCache {
  static const maxEntries = 200;

  final LinkedHashMap<int, StoreOffer> _byId = LinkedHashMap();

  /// Keeps [offer]; call it before opening the detail.
  void remember(StoreOffer offer) {
    _byId.remove(offer.id);
    _byId[offer.id] = offer;
    while (_byId.length > maxEntries) {
      _byId.remove(_byId.keys.first);
    }
  }

  StoreOffer? byId(int id) => _byId[id];
}

/// The session's offers; a new, empty cache for another account.
final offerCacheProvider = Provider<OfferCache>((ref) {
  ref.watch(offerAccountIdProvider);
  return OfferCache();
});

/// What [offerByIdProvider] looks up: the offer and the list whose cached
/// offers may hold it.
typedef OfferLookup = ({int offerId, String? listId});

/// The offer [OfferLookup.offerId] from the session cache, else from the
/// list's cached offers; null when it is no longer saved or offers are off.
/// Answers synchronously when the session cache has it, so the detail never
/// shows a loading state.
final offerByIdProvider = FutureProvider.autoDispose
    .family<StoreOffer?, OfferLookup>((ref, key) {
      if (!ref.watch(offersRemoteEnabledProvider) ||
          !ref.watch(offersAvailableProvider)) {
        return null;
      }
      // Without a real region there are no offers (`angebote.md` 1.3) and a
      // hidden list shows none; both wait while they are still being read.
      if (!ref.watch(regionLoadedProvider)) {
        return Completer<StoreOffer?>().future;
      }
      if (ref.watch(regionProvider) == null) return null;
      final listId = key.listId;
      if (listId != null) {
        if (ref.watch(hiddenOfferListsProvider) == null) {
          return Completer<StoreOffer?>().future;
        }
        if (!ref.watch(offersVisibleForListProvider(listId))) return null;
      }
      final known = ref.watch(offerCacheProvider).byId(key.offerId);
      if (known != null) return known;
      if (listId == null) return null;
      return ref
          .watch(listOfferSyncProvider)
          .cached(listId)
          .then(
            (snapshot) => snapshot?.offersByName.values
                .where((o) => o.id == key.offerId)
                .firstOrNull,
          );
    });

/// The confirmed market of [listId] as the device has it cached, without
/// working out the market again (which reads the list, its items and its
/// trips). A list screen that is open answers through
/// [storeForListProvider].
final cachedStoreOfListProvider = Provider.autoDispose.family<String?, String>((
  ref,
  listId,
) {
  if (ref.exists(storeGuessForListProvider(listId))) {
    return ref.watch(storeForListProvider(listId))?.id;
  }
  final repo = ref.watch(listStoreRepositoryProvider);
  final changes = repo.changes
      .where((id) => id == listId)
      .listen((_) => ref.invalidateSelf());
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    changes.cancel();
  });
  if (!repo.isCacheLoaded) {
    unawaited(
      repo.loadCache().then((_) {
        if (!disposed) ref.invalidateSelf();
      }),
    );
    return null;
  }
  final guess = repo.cachedGuess(listId);
  return guess != null && guess.confirmed ? guess.chainId : null;
});

/// The open items of [listId] the device has without a request: the live
/// list when it is loaded, else the offline copy; null when neither exists.
/// Read once, without listening, so a list card never keeps a list's
/// realtime channel open. Override in tests.
final cachedOpenItemsProvider = Provider.autoDispose
    .family<List<ShoppingItemModel>?, String>((ref, listId) {
      final items = ref.exists(itemsNotifierProvider(listId))
          ? ref.read(itemsNotifierProvider(listId)).valueOrNull
          : OfflineCacheService.instance.getCachedListItemsSync(listId);
      if (items == null) return null;
      return [
        for (final item in items)
          if (!item.isChecked) item,
      ];
    });

/// "2 Angebote" on the cover of a list card (S8): open items of [listId]
/// with a current offer of its market, from the cached offers only (a list
/// card never starts a sync). 0 while offers may not show on the list.
final listOfferBadgeCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, listId) async {
      final visible = ref.watch(
        offerSurfaceVisibleProvider((
          surface: OfferSurface.itemOffers,
          listId: listId,
        )),
      );
      if (!visible) return 0;
      final region = ref.watch(regionProvider);
      final chainId = ref.watch(cachedStoreOfListProvider(listId));
      final items = ref.watch(cachedOpenItemsProvider(listId));
      final prefs = ref.watch(offerDisplayPrefsProvider);
      final now = ref.watch(offerClockProvider)();
      if (region == null || chainId == null) return 0;
      final snapshot = await ref.watch(listOfferSyncProvider).cached(listId);
      if (snapshot == null ||
          snapshot.chainId != chainId ||
          snapshot.zip != region.zip) {
        return 0;
      }
      bool current(StoreOffer offer) => offer.isValidNow;
      if (items == null) {
        return snapshot.offersByName.values.where(current).length;
      }
      return items.where((item) {
        final offer = snapshot.offerFor(item.name);
        return offer != null &&
            current(offer) &&
            !(prefs?.isDeclined(item.id, offer.id, now) ?? false);
      }).length;
    });

/// The name of [listId] from the loaded lists ("Wocheneinkauf"); null while
/// unknown. Override in tests.
final offerListNameProvider = Provider.autoDispose.family<String?, String>(
  (ref, listId) => ref.watch(
    listsNotifierProvider.select(
      (lists) => lists.valueOrNull
          ?.where((l) => l.id == listId)
          .firstOrNull
          ?.name
          .trim(),
    ),
  ),
);

/// Whether [listId] is one of the person's lists: null while the lists are
/// loading, false for a deleted list or one the person left (S9 then shows
/// A's error page). Override in tests.
final offerListExistsProvider = Provider.autoDispose.family<bool?, String>(
  (ref, listId) => ref.watch(
    listsNotifierProvider.select(
      (lists) => lists.valueOrNull?.any((l) => l.id == listId),
    ),
  ),
);

/// What [cachedMoreOffersProvider] is asked for: the list and the item name.
typedef MoreOffersKey = ({String listId, String query});

/// "Weitere Angebote bei Lidl" in the offer detail (S5): offers of the
/// list's market for the item that an earlier search left on the device,
/// read once when the detail opens and never a request, so the section never
/// appears late. Empty without them or while offers may not show.
final cachedMoreOffersProvider = Provider.autoDispose
    .family<List<StoreOffer>, MoreOffersKey>((ref, key) {
      if (!ref.watch(offersRemoteEnabledProvider) ||
          !ref.watch(offersVisibleForListProvider(key.listId))) {
        return const [];
      }
      final region = ref.watch(regionProvider);
      final chainId = ref.watch(storeForListProvider(key.listId))?.id;
      if (region == null || chainId == null) return const [];
      return ref
              .read(offerPriceServiceProvider)
              .cachedOffers(key.query, zipCode: region.zip, chainId: chainId) ??
          const [];
    });
