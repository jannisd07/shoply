import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Avo's restock suggestions for the home screen card.
/// autoDispose so a fresh visit to home recomputes against current lists.
final restockSuggestionsProvider =
    FutureProvider.autoDispose<List<RestockSuggestion>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  return AvoNudgeService.instance.getRestockSuggestions(limit: 3);
});

/// Rhythm items currently on offer nearby ("Milch: −23 % bei Lidl"), for the
/// same home card. Backed by a 6h persistent cache in [AvoNudgeService], so
/// watching this does not hit the offers API on every home visit.
final offerNudgesProvider =
    FutureProvider.autoDispose<List<OfferNudge>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  return AvoNudgeService.instance.getOfferNudges(limit: 2);
});

/// Everything you buy regularly that is on offer right now, grouped by shop —
/// the home screen's personal flyer.
///
/// Shares [AvoNudgeService]'s 6h offer cache with [offerNudgesProvider], so
/// the flyer costs no extra API calls beyond the larger limit; the nudge card
/// simply shows the top two of the same computation.
final personalFlyerProvider =
    FutureProvider.autoDispose<List<FlyerSection>>((ref) async {
  final authUser = await ref.watch(authUserProvider.future);
  if (authUser == null) return const [];
  final nudges = await AvoNudgeService.instance.getOfferNudges(limit: 12);
  return groupOffersByRetailer(nudges);
});

/// One shop's worth of the flyer.
class FlyerSection {
  final String retailerName;
  final List<OfferNudge> offers;

  const FlyerSection({required this.retailerName, required this.offers});

  /// Combined saving, counting only offers where the shop disclosed a real
  /// previous price — otherwise "you save X" would be invented.
  double get disclosedSavings => offers.fold<double>(0, (sum, o) {
        final regular = o.regularPrice;
        if (regular == null || regular <= o.price) return sum;
        return sum + (regular - o.price);
      });
}

/// Group [nudges] by shop, biggest section first, so the flyer opens with the
/// shop where the user has the most to gain rather than an alphabetical list.
@visibleForTesting
List<FlyerSection> groupOffersByRetailer(List<OfferNudge> nudges) {
  final byRetailer = <String, List<OfferNudge>>{};
  for (final nudge in nudges) {
    final name = nudge.retailerName.trim();
    if (name.isEmpty) continue;
    byRetailer.putIfAbsent(name, () => []).add(nudge);
  }

  final sections = [
    for (final entry in byRetailer.entries)
      FlyerSection(retailerName: entry.key, offers: entry.value),
  ];
  sections.sort((a, b) {
    final byCount = b.offers.length.compareTo(a.offers.length);
    if (byCount != 0) return byCount;
    // Stable tie-break so the flyer does not reshuffle between rebuilds.
    return a.retailerName.compareTo(b.retailerName);
  });
  return sections;
}
