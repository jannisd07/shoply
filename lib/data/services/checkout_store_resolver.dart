import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shoply/data/models/nearby_store.dart';

/// Outcome of trying to work out which shop the user is standing in when they
/// finish a shopping trip.
sealed class StoreResolution {
  const StoreResolution();
}

/// One shop is close enough and clearly separated from the rest — record it
/// without bothering the user.
class StoreResolved extends StoreResolution {
  final NearbyStore store;
  const StoreResolved(this.store);
}

/// Several shops are plausible (a shopping centre, a retail park). Ask, and
/// offer these as the choices, closest first.
class StoreAmbiguous extends StoreResolution {
  final List<NearbyStore> candidates;
  const StoreAmbiguous(this.candidates);
}

/// Nothing usable nearby — either GPS says the user is not at a shop, or
/// there is no location at all. Ask without a shortlist.
class StoreUnknown extends StoreResolution {
  /// True when the user has denied location access, so the UI can explain
  /// what that costs them before asking manually.
  final bool locationDenied;
  const StoreUnknown({this.locationDenied = false});
}

/// Decides, from the shops around the user, whether the current one can be
/// identified confidently.
///
/// Getting this wrong is worse than asking: a silently mis-recorded shop
/// teaches the app that you buy your bananas at Lidl when you actually buy
/// them at REWE, and then puts the wrong flyer in front of you. So the bar
/// for "resolved" is deliberately high and anything else falls through to a
/// question.
class CheckoutStoreResolver {
  /// Beyond this the user is not plausibly inside the shop.
  @visibleForTesting
  static const double insideRadiusMeters = 80;

  /// A different retailer this much further away no longer competes for the
  /// answer. Below it — think REWE and Aldi sharing one building — the
  /// situation is a genuine coin flip and the user is asked.
  @visibleForTesting
  static const double separationMeters = 50;

  /// Shops within this distance are offered as choices when asking.
  @visibleForTesting
  static const double candidateRadiusMeters = 250;

  /// [stores] does not need to be pre-sorted.
  static StoreResolution resolve(
    List<NearbyStore> stores, {
    bool locationDenied = false,
  }) {
    if (locationDenied) return const StoreUnknown(locationDenied: true);

    final sorted = [...stores]
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final candidates = sorted
        .where((s) => s.distanceMeters <= candidateRadiusMeters)
        .toList();
    if (candidates.isEmpty) return const StoreUnknown();

    final nearest = candidates.first;
    if (nearest.distanceMeters > insideRadiusMeters) {
      // Near some shops but not inside one — let the user say.
      return StoreAmbiguous(candidates);
    }

    // Branches of the same chain next to each other are not a conflict: the
    // answer we record is the retailer, and it is the same either way.
    final rival = candidates.firstWhere(
      (s) => !_sameRetailer(s, nearest),
      orElse: () => nearest,
    );
    if (identical(rival, nearest) || rival == nearest) {
      return StoreResolved(nearest);
    }

    final gap = rival.distanceMeters - nearest.distanceMeters;
    if (gap >= separationMeters) return StoreResolved(nearest);

    return StoreAmbiguous(candidates);
  }

  static bool _sameRetailer(NearbyStore a, NearbyStore b) {
    final an = a.retailerUniqueName ?? a.displayName.toLowerCase();
    final bn = b.retailerUniqueName ?? b.displayName.toLowerCase();
    return an == bn;
  }
}
