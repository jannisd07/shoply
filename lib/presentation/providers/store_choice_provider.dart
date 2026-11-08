/// What the market menu (S1) and "Markt wählen" (S2) offer: the markets of
/// a list's past trips, stores near the person and the common chains.
/// "Markt pro Liste" is core: none of this depends on the offers module.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/store_locator_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

/// What "Markt wählen" returns (`/stores/pick`, `context.pop(result)`).
@immutable
sealed class StoreChoice {
  const StoreChoice();
}

/// A chain from [StoreChainDirectory].
final class ChainStoreChoice extends StoreChoice {
  const ChainStoreChoice(this.chainId);

  final String chainId;

  @override
  bool operator ==(Object other) =>
      other is ChainStoreChoice && other.chainId == chainId;

  @override
  int get hashCode => chainId.hashCode;
}

/// A market of the person's own ("Bio Kaiser"): no brand colour, no offers.
final class CustomStoreChoice extends StoreChoice {
  const CustomStoreChoice(this.name);

  final String name;

  @override
  bool operator ==(Object other) =>
      other is CustomStoreChoice && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// "Kein fester Markt".
final class NoStoreChoice extends StoreChoice {
  const NoStoreChoice();

  @override
  bool operator ==(Object other) => other is NoStoreChoice;

  @override
  int get hashCode => 0;
}

/// Chains of the newest trips of [listId], newest first, each once, at most
/// three (Lücke L7: read from the trip history). Empty when it cannot be
/// read, offline too.
final listStoreHistoryProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, listId) async {
      final chains = await ref
          .watch(listStoreRepositoryProvider)
          .recentTripChains(listId);
      return chains.toSet().take(3).toList();
    });

/// A store near the person in "Markt wählen".
@immutable
class NearbyStoreOption {
  const NearbyStoreOption({
    required this.chainId,
    required this.distanceMeters,
    this.street,
  });

  final String chainId;
  final double distanceMeters;

  /// "Kaiser-Joseph-Straße".
  final String? street;
}

/// Radius of "In der Nähe" in S2.
const double nearbyStoresRadiusMeters = 2000;

/// At most this many stores in "In der Nähe".
const int nearbyStoresMax = 5;

/// Known chains within 2 km, closest first, at most five. Only with a
/// location the app may already read: this never asks for permission
/// (S2 never asks). Empty without location, offline or when Overpass does
/// not answer. Override in tests.
final nearbyStoreOptionsProvider =
    FutureProvider.autoDispose<List<NearbyStoreOption>>((ref) async {
      try {
        final position = await UserLocationService.instance.getCoordinates(
          allowPermissionPrompt: false,
        );
        if (position == null) return const [];
        final stores = await StoreLocatorService.instance.findNearbyStores(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: nearbyStoresRadiusMeters,
        );
        final options = <NearbyStoreOption>[];
        for (final store in stores) {
          final unique = store.retailerUniqueName;
          final chainId =
              unique != null && StoreChainDirectory.byId(unique) != null
              ? unique
              : matchChain(store.displayName);
          if (chainId == null) continue;
          options.add(
            NearbyStoreOption(
              chainId: chainId,
              distanceMeters: store.distanceMeters,
              street: store.street,
            ),
          );
          if (options.length == nearbyStoresMax) break;
        }
        return options;
      } catch (e) {
        debugPrint('⚠️ [STORE] Stores nearby not found: $e');
        return const [];
      }
    });

/// The common chains for the market menu when a list has no history:
/// Lidl, the Aldi of the region, REWE, Edeka, Kaufland, Netto.
List<String> popularChainIds(String? zip) => [
  'lidl',
  if (zip == null) ...['aldi-sued', 'aldi-nord'] else aldiForZip(zip),
  'rewe',
  'edeka',
  'kaufland',
  'netto-marken-discount',
];

/// Aldi Süd or Aldi Nord for a zip code, by the rough line between them
/// (south and west: Aldi Süd; north and east: Aldi Nord). Only the order of
/// a menu depends on it; the other Aldi stays one tap away.
String aldiForZip(String zip) {
  if (zip.length < 2) return 'aldi-nord';
  final two = int.tryParse(zip.substring(0, 2));
  if (two == null) return 'aldi-nord';
  const south = {40, 41, 42, 45, 46, 47, 50, 51, 52, 53, 54, 55, 56, 57};
  if (south.contains(two)) return 'aldi-sued';
  if (two >= 60 && two <= 97) return 'aldi-sued';
  return 'aldi-nord';
}
