import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/checkout_store_resolver.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/data/services/store_locator_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// The data V1 "Einkauf abschließen" reads besides the list's items: the
/// preselected market, the market "here", location access and the savings
/// line. Each provider can be overridden in tests.

/// How V1 preselects the market (verlauf-kosten.md V1 "Vorauswahl").
@immutable
class CheckoutPreselection {
  const CheckoutPreselection(this.chainId, this.source);

  final String chainId;

  /// `list` (the list's market) or `learned` (twice in a row).
  final String source;
}

/// The market of the list, confirmed, else the learned one; null without.
/// Read once when V1 opens and never changed afterwards by itself.
final checkoutPreselectionProvider =
    Provider.autoDispose.family<CheckoutPreselection?, String>((ref, listId) {
      final guess = ref.watch(storeGuessForListProvider(listId)).valueOrNull;
      if (guess == null || StoreChainDirectory.byId(guess.chainId) == null) {
        return null;
      }
      if (guess.confirmed && guess.source == StoreSource.user) {
        return CheckoutPreselection(guess.chainId, 'list');
      }
      if (guess.source == StoreSource.learned &&
          ref.watch(storeDetectionOnProvider)) {
        return CheckoutPreselection(guess.chainId, 'learned');
      }
      if (guess.confirmed) return CheckoutPreselection(guess.chainId, 'list');
      return null;
    });

/// Overpass radius for the market "here" (V1 Daten: 250 m, the resolver's
/// candidate radius).
const double _kStoreHereRadius = 250;

/// The market the person is standing in, from a location the app may
/// already read (never asking), within 3 s; null when ambiguous, offline,
/// switched off ("Markt automatisch erkennen") or not found.
final checkoutStoreHereProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  if (!ref.watch(storeDetectionOnProvider)) return null;
  if (ref.watch(isOfflineProvider)) return null;
  try {
    final position = await UserLocationService.instance
        .getCoordinates(allowPermissionPrompt: false)
        .timeout(const Duration(seconds: 3));
    if (position == null) return null;
    final stores = await StoreLocatorService.instance
        .findNearbyStores(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: _kStoreHereRadius,
        )
        .timeout(const Duration(seconds: 3));
    final resolution = CheckoutStoreResolver.resolve(stores);
    if (resolution is! StoreResolved) return null;
    final store = resolution.store;
    final id = store.retailerUniqueName;
    if (id != null && StoreChainDirectory.byId(id) != null) return id;
    return matchChain(store.displayName);
  } catch (e) {
    debugPrint('⚠️ [CHECKOUT] Store here not found: ${e.runtimeType}');
    return null;
  }
});

/// What V1 knows about location access, for the one-time hint.
enum CheckoutLocationAccess {
  /// Allowed: the "(hier)" chip may come.
  granted,

  /// Never asked: hint "Standort verwenden" (once in a lifetime).
  notAsked,

  /// Denied: hint "In Einstellungen erlauben" (once in a lifetime).
  denied,

  /// Location services off, unknown, or the hint was shown already.
  none,
}

/// Location access as V1 needs it; asking is [CheckoutLocationPort.request].
abstract interface class CheckoutLocationPort {
  Future<CheckoutLocationAccess> status();

  /// The system question (after the explanation dialog). True when allowed.
  Future<bool> request();

  /// Opens the app's page in iOS Settings.
  Future<void> openSettings();
}

class _GeolocatorPort implements CheckoutLocationPort {
  const _GeolocatorPort();

  @override
  Future<CheckoutLocationAccess> status() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return CheckoutLocationAccess.none;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always ||
        LocationPermission.whileInUse => CheckoutLocationAccess.granted,
        LocationPermission.denied => CheckoutLocationAccess.notAsked,
        LocationPermission.deniedForever => CheckoutLocationAccess.denied,
        LocationPermission.unableToDetermine => CheckoutLocationAccess.none,
      };
    } catch (_) {
      return CheckoutLocationAccess.none;
    }
  }

  @override
  Future<bool> request() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

final checkoutLocationPortProvider = Provider<CheckoutLocationPort>(
  (ref) => const _GeolocatorPort(),
);

/// Key of "the location hint was shown once" (once in a lifetime, V1).
const String checkoutLocationHintKey = 'hist_checkout_location_hint_v1';

/// Which location hint V1 shows; [CheckoutLocationAccess.none] once it was
/// shown, while "Markt automatisch erkennen" is off, or with a preselection.
final checkoutLocationHintProvider =
    FutureProvider.autoDispose<CheckoutLocationAccess>((ref) async {
      if (!ref.watch(storeDetectionOnProvider)) {
        return CheckoutLocationAccess.none;
      }
      final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
      if (prefs == null || (prefs.getBool(checkoutLocationHintKey) ?? false)) {
        return CheckoutLocationAccess.none;
      }
      final access = await ref.watch(checkoutLocationPortProvider).status();
      return access == CheckoutLocationAccess.granted
          ? CheckoutLocationAccess.none
          : access;
    });

/// Remembers that the location hint was shown (it never comes again).
Future<void> markCheckoutLocationHintShown(SharedPreferences prefs) =>
    prefs.setBool(checkoutLocationHintKey, true);

/// "Kosten teilen" starts on when the last trip of this list was split.
String checkoutSplitLastKey(String listId) => 'hist_split_last_v1_$listId';

/// The savings line of V1 and the subtitle of V3 (L4): only the checked
/// items with an offer price of [chainId], over the shared
/// [totalSavingsOf] and [roundedSavingsCents]; null when offers may not
/// show (module, kill switch, no real region, the switch "Ersparnis im
/// Verlauf und nach dem Einkauf") or below 0,50 €.
final checkoutSavingsCentsProvider = Provider.autoDispose
    .family<int?, ({String listId, String? chainId})>((ref, key) {
      final chainId = key.chainId;
      if (chainId == null) return null;
      final visible = ref.watch(
        offerSurfaceVisibleProvider((
          surface: OfferSurface.historySavings,
          listId: key.listId,
        )),
      );
      if (!visible || ref.watch(regionProvider) == null) return null;
      final items =
          ref.watch(itemsNotifierProvider(key.listId)).valueOrNull ??
          const <ShoppingItemModel>[];
      return checkoutSavingsCents(items, chainId);
    });

/// [checkoutSavingsCentsProvider] without the gates: the checked [items]
/// as a trip at [chainId], rounded like everywhere ("ca. 3,20 €").
int? checkoutSavingsCents(List<ShoppingItemModel> items, String chainId) {
  final trip = ShoppingHistory(
    id: 'checkout',
    userId: '',
    listName: '',
    totalItems: 0,
    completedAt: DateTime.fromMillisecondsSinceEpoch(0),
    storeChainId: chainId,
    items: [
      for (final item in items)
        if (item.isChecked)
          ShoppingHistoryItem(
            id: item.id,
            historyId: 'checkout',
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            price: item.price,
            // Only an offer of this market counts (an item without a
            // retailer has no offer price at all).
            priceRetailer: item.priceRetailer,
            priceOldValue: item.priceOldValue,
          ),
    ],
  );
  final raw = (totalSavingsOf([trip]) * 100).round();
  return roundedSavingsCents(raw);
}

/// The name of [listId] from the loaded lists, else asked once.
final checkoutListNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, listId) async {
      final lists = ref.watch(listsNotifierProvider).valueOrNull;
      final known = lists?.where((l) => l.id == listId).firstOrNull;
      if (known != null) return known.name;
      try {
        return await ref.read(itemRepositoryProvider).getListName(listId);
      } catch (_) {
        return null;
      }
    });
