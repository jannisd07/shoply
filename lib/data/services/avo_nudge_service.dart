import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One "you're probably running low on X" suggestion, derived from the
/// user's real purchase rhythm in `item_purchase_stats`.
class RestockSuggestion {
  /// Normalized (lowercase) name as stored in the stats table.
  final String itemName;

  /// Name with the first letter capitalized, for display.
  final String displayName;

  /// Rounded average days between purchases (the user's buying rhythm).
  final int averageDays;

  /// Days since the item was last purchased.
  final int daysSince;

  /// daysSince / averageDays — how overdue the item is. Usually >= 1.0;
  /// can be slightly below when the item was included because today is its
  /// usual buying weekday (see [usualWeekday]).
  final double overdueRatio;

  /// The weekday (DateTime.monday..sunday) this item is usually bought on,
  /// when the purchase history shows a clear pattern — else null.
  final int? usualWeekday;

  final String? preferredCategory;
  final double? preferredQuantity;

  const RestockSuggestion({
    required this.itemName,
    required this.displayName,
    required this.averageDays,
    required this.daysSince,
    required this.overdueRatio,
    this.usualWeekday,
    this.preferredCategory,
    this.preferredQuantity,
  });
}

/// A regularly-bought item that is due again soon AND currently on offer at
/// a store around the user's real location — Avo's "relevant Angebot" nudge.
///
/// [regularPrice]/[discountPercent] are set only when the retailer actually
/// discloses a regular price ("statt 1,49") — most flyer offers don't, so
/// the nudge never invents a discount figure, it just shows the offer.
///
/// Carries flat offer fields (instead of a full [StoreOffer]) so it can be
/// cached across app starts without re-querying the offers API.
class OfferNudge {
  /// Normalized (lowercase) name as stored in the stats table.
  final String itemName;
  final String displayName;

  /// The offered product's own name (may be more specific than [itemName]).
  final String productName;
  final double price;
  final double? regularPrice;
  final int? discountPercent;
  final String retailerName;
  final DateTime? validTo;
  final String? unitSizeLabel;
  final String? preferredCategory;
  final double? preferredQuantity;

  const OfferNudge({
    required this.itemName,
    required this.displayName,
    required this.productName,
    required this.price,
    this.regularPrice,
    this.discountPercent,
    required this.retailerName,
    this.validTo,
    this.unitSizeLabel,
    this.preferredCategory,
    this.preferredQuantity,
  });

  bool get isStillValid => validTo == null || DateTime.now().isBefore(validTo!);

  /// Whether the retailer disclosed a real previous price to compare against.
  bool get hasDisclosedDiscount => regularPrice != null && discountPercent != null;

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'displayName': displayName,
        'productName': productName,
        'price': price,
        'regularPrice': regularPrice,
        'discountPercent': discountPercent,
        'retailerName': retailerName,
        'validTo': validTo?.toIso8601String(),
        'unitSizeLabel': unitSizeLabel,
        'preferredCategory': preferredCategory,
        'preferredQuantity': preferredQuantity,
      };

  static OfferNudge? fromJson(Map<String, dynamic> json) {
    final itemName = json['itemName'] as String?;
    final price = (json['price'] as num?)?.toDouble();
    if (itemName == null || price == null) return null;
    return OfferNudge(
      itemName: itemName,
      displayName: json['displayName'] as String? ?? itemName,
      productName: json['productName'] as String? ?? itemName,
      price: price,
      regularPrice: (json['regularPrice'] as num?)?.toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.round(),
      retailerName: json['retailerName'] as String? ?? '',
      validTo: DateTime.tryParse(json['validTo'] as String? ?? ''),
      unitSizeLabel: json['unitSizeLabel'] as String?,
      preferredCategory: json['preferredCategory'] as String?,
      preferredQuantity: (json['preferredQuantity'] as num?)?.toDouble(),
    );
  }
}

/// Computes Avo's restock nudges from data the app already tracks:
/// [PurchaseTrackingService] updates `item_purchase_stats.average_days_between`
/// after every completed shopping trip. An item is suggested when it is
/// overdue by its own average rhythm, not currently on any open list, and
/// not snoozed by the user.
class AvoNudgeService {
  static AvoNudgeService? _instance;
  static AvoNudgeService get instance {
    _instance ??= AvoNudgeService._();
    return _instance!;
  }

  AvoNudgeService._();

  static const String _snoozeKey = 'avo_nudge_snoozed_until';
  static const String _offerSnoozeKey = 'avo_offer_nudge_snoozed_until';
  static const String _offerCacheKey = 'avo_offer_nudges_cache_v1';

  /// Minimum purchases before an item can be suggested at all.
  ///
  /// Two is the mathematical floor: with a single purchase there is no
  /// interval, so no rhythm can exist. Everything above that floor is a
  /// matter of *ranking*, not exclusion — see [habitStrength]. Occasional
  /// buys should still surface, just behind the staples.
  static const int _minPurchases = 2;

  /// Rhythms outside this window are ignored (daily-ish to ~2 months).
  static const double _minAvgDays = 2;
  static const double _maxAvgDays = 60;

  /// If an item is overdue by more than this factor, the habit has probably
  /// changed (bought elsewhere, stopped using it) — stop suggesting it.
  static const double _maxOverdueRatio = 4;

  /// An item that isn't overdue yet still gets suggested on its usual
  /// buying weekday once it's this close to being due.
  static const double _dueSoonRatio = 0.75;

  /// Offer nudges start once an item is this close to being due again
  /// (an offer for something you'll buy in a few days is actionable).
  static const double _offerDueRatio = 0.6;

  /// Minimum disclosed discount before an offer is preferred over a cheaper
  /// undiscounted one. (Disclosed regular prices are rare in flyer data —
  /// verified live: most staple offers carry no "statt" price — so this is
  /// a preference, not a requirement.)
  static const int _minOfferDiscountPercent = 10;

  /// Hard cap on offer-API searches per computation (results are cached).
  static const int _maxOfferLookups = 6;

  static const Duration _offerCacheTtl = Duration(hours: 6);

  final PurchaseTrackingService _trackingService = PurchaseTrackingService();

  /// The weekday (DateTime.monday..sunday) most of [dates] fall on, when the
  /// pattern is strong enough to mention: at least 3 purchases on that
  /// weekday AND at least half of all purchases. Null otherwise.
  @visibleForTesting
  static int? dominantWeekday(List<DateTime> dates) {
    if (dates.length < _minPurchases) return null;
    final counts = <int, int>{};
    for (final d in dates) {
      counts[d.weekday] = (counts[d.weekday] ?? 0) + 1;
    }
    int? bestDay;
    var bestCount = 0;
    counts.forEach((day, count) {
      if (count > bestCount) {
        bestDay = day;
        bestCount = count;
      }
    });
    if (bestCount < 3 || bestCount * 2 < dates.length) return null;
    return bestDay;
  }

  /// How much this item looks like a habit rather than a one-off, 0..1.
  ///
  /// Two signals, because they mean different things:
  ///
  ///  * **How often it has been bought.** Two purchases give exactly one
  ///    interval, which could be coincidence; twenty give a rhythm you can
  ///    rely on. The curve saturates, so the difference between 2 and 6
  ///    purchases matters far more than between 20 and 30.
  ///  * **How tight the cadence is.** Something bought weekly is more part of
  ///    the routine than something bought every seven weeks, even at equal
  ///    counts.
  ///
  /// Never returns 0: a rarely-bought item stays eligible, it just ranks
  /// below the staples. That is the whole point — excluding it would mean
  /// never reminding anyone of the things they buy now and then.
  @visibleForTesting
  static double habitStrength({
    required int purchaseCount,
    required double averageDaysBetween,
  }) {
    // (n-1)/(n-1+k): 2 buys → 0.25, 3 → 0.40, 5 → 0.57, 10 → 0.75, 20 → 0.86.
    final intervals = (purchaseCount - 1).clamp(0, 1000).toDouble();
    final countConfidence = intervals / (intervals + 3);

    // Weekly → ~0.88, monthly → 0.5, two-monthly → 0.
    final cadence = (1 - (averageDaysBetween / _maxAvgDays)).clamp(0.0, 1.0);

    return (0.35 + 0.45 * countConfidence + 0.20 * cadence).clamp(0.0, 1.0);
  }

  /// Ranking score for a restock suggestion: how due it is, tempered by how
  /// much of a habit it is.
  ///
  /// Sorting on overdue ratio alone let a twice-bought oddity outrank a
  /// weekly staple simply because its shaky average made it look overdue.
  @visibleForTesting
  static double suggestionPriority({
    required int purchaseCount,
    required double averageDaysBetween,
    required double overdueRatio,
  }) {
    // Saturating: being 5x overdue is not five times as urgent as 1x, and
    // without the cap a stale outlier would dominate the list forever.
    final dueness = (overdueRatio / 2).clamp(0.0, 1.0);
    return dueness *
        habitStrength(
          purchaseCount: purchaseCount,
          averageDaysBetween: averageDaysBetween,
        );
  }

  /// Top [limit] restock suggestions, most relevant first.
  ///
  /// An item qualifies when it is overdue by its own rhythm, or — when its
  /// purchase history shows a clear weekday pattern — when today is that
  /// weekday and it is at least close to due ("you usually buy this on
  /// Sundays").
  Future<List<RestockSuggestion>> getRestockSuggestions({int limit = 3}) async {
    try {
      final stats = await _trackingService.getAllStats();
      if (stats.isEmpty) return [];

      final snoozed = await _loadSnoozes(_snoozeKey);
      final today = DateTime.now().weekday;
      final candidates = <ItemPurchaseStats>[];
      final weekdays = <String, int?>{};
      for (final s in stats) {
        final avg = s.averageDaysBetween;
        if (s.purchaseCount < _minPurchases) continue;
        if (avg == null || avg < _minAvgDays || avg > _maxAvgDays) continue;
        final ratio = s.daysSinceLastPurchase / avg;
        if (ratio > _maxOverdueRatio) continue;
        final usualDay = dominantWeekday(s.purchaseDates);
        final overdue = ratio >= 1.0;
        final dueOnUsualDay =
            usualDay != null && usualDay == today && ratio >= _dueSoonRatio;
        if (!overdue && !dueOnUsualDay) continue;
        if (_isSnoozed(snoozed, s.itemName)) continue;
        weekdays[s.itemName] = usualDay;
        candidates.add(s);
      }
      if (candidates.isEmpty) return [];

      // Exclude items already sitting unchecked on one of the user's lists.
      final openItemNames = await _getOpenItemNames();
      candidates.removeWhere(
          (s) => openItemNames.contains(s.itemName.trim().toLowerCase()));
      if (candidates.isEmpty) return [];

      candidates.sort((a, b) {
        final pa = suggestionPriority(
          purchaseCount: a.purchaseCount,
          averageDaysBetween: a.averageDaysBetween!,
          overdueRatio: a.daysSinceLastPurchase / a.averageDaysBetween!,
        );
        final pb = suggestionPriority(
          purchaseCount: b.purchaseCount,
          averageDaysBetween: b.averageDaysBetween!,
          overdueRatio: b.daysSinceLastPurchase / b.averageDaysBetween!,
        );
        final byPriority = pb.compareTo(pa);
        if (byPriority != 0) return byPriority;
        // Stable tie-break so the card does not reshuffle between rebuilds.
        return a.itemName.compareTo(b.itemName);
      });

      return candidates.take(limit).map((s) {
        final avg = s.averageDaysBetween!;
        return RestockSuggestion(
          itemName: s.itemName,
          displayName: _capitalize(s.itemName),
          averageDays: avg.round().clamp(1, 999),
          daysSince: s.daysSinceLastPurchase,
          overdueRatio: s.daysSinceLastPurchase / avg,
          usualWeekday: weekdays[s.itemName],
          preferredCategory: s.preferredCategory,
          preferredQuantity: s.preferredQuantity,
        );
      }).toList();
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to compute suggestions: $e');
      return [];
    }
  }

  /// Up to [limit] "your regular item is on offer" nudges: rhythm items that
  /// are due again soon and currently have a relevant live offer at a store
  /// around the user's real zip code. Offers with a disclosed discount are
  /// preferred; otherwise the cheapest relevant offer is shown as a plain
  /// Angebot (no invented discount figure).
  ///
  /// Results are cached for [_offerCacheTtl] (offers change weekly) so this
  /// costs at most [_maxOfferLookups] API searches per 6 hours; without a
  /// real location (no GPS permission, no manual zip) it nudges nothing
  /// rather than claiming a "nearby" offer from the nationwide fallback.
  Future<List<OfferNudge>> getOfferNudges({int limit = 2}) async {
    try {
      final zipInfo = await UserLocationService.instance.getZipInfo();
      if (!zipInfo.isReal) return [];

      final stats = await _trackingService.getAllStats();
      if (stats.isEmpty) return [];

      final snoozed = await _loadSnoozes(_offerSnoozeKey);
      final candidates = <ItemPurchaseStats>[];
      for (final s in stats) {
        final avg = s.averageDaysBetween;
        if (s.purchaseCount < _minPurchases) continue;
        if (avg == null || avg < _minAvgDays || avg > _maxAvgDays) continue;
        final ratio = s.daysSinceLastPurchase / avg;
        if (ratio < _offerDueRatio || ratio > _maxOverdueRatio) continue;
        if (_isSnoozed(snoozed, s.itemName)) continue;
        candidates.add(s);
      }
      if (candidates.isEmpty) return [];

      // Items already on a list are covered by the per-item offer chips in
      // the list itself — don't double-nudge them on the home screen.
      final openItemNames = await _getOpenItemNames();
      candidates.removeWhere(
          (s) => openItemNames.contains(s.itemName.trim().toLowerCase()));
      if (candidates.isEmpty) return [];

      candidates.sort((a, b) {
        final pa = suggestionPriority(
          purchaseCount: a.purchaseCount,
          averageDaysBetween: a.averageDaysBetween!,
          overdueRatio: a.daysSinceLastPurchase / a.averageDaysBetween!,
        );
        final pb = suggestionPriority(
          purchaseCount: b.purchaseCount,
          averageDaysBetween: b.averageDaysBetween!,
          overdueRatio: b.daysSinceLastPurchase / b.averageDaysBetween!,
        );
        final byPriority = pb.compareTo(pa);
        if (byPriority != 0) return byPriority;
        // Stable tie-break so the card does not reshuffle between rebuilds.
        return a.itemName.compareTo(b.itemName);
      });
      final lookups = candidates.take(_maxOfferLookups).toList();

      final signature =
          '${zipInfo.zipCode}|${lookups.map((s) => s.itemName).join('|')}';
      final cached = await _loadOfferCache(signature);
      if (cached != null) {
        return cached
            .where((n) => n.isStillValid && !_isSnoozed(snoozed, n.itemName))
            .take(limit)
            .toList();
      }

      final nudges = <OfferNudge>[];
      // Sequential on purpose: the offers service throttles anyway, and this
      // runs in the background of the home screen — no user is waiting on it.
      for (final s in lookups) {
        final offer = await _bestOfferFor(
          s.itemName,
          zipInfo.zipCode,
          preferredRetailer: s.preferredRetailer,
        );
        if (offer == null) continue;
        nudges.add(OfferNudge(
          itemName: s.itemName,
          displayName: _capitalize(s.itemName),
          productName: offer.productName,
          price: offer.price,
          regularPrice: offer.regularPrice,
          discountPercent: offer.discountPercent,
          retailerName: offer.retailerName,
          validTo: offer.validTo,
          unitSizeLabel: offer.unitSizeLabel,
          preferredCategory: s.preferredCategory,
          preferredQuantity: s.preferredQuantity,
        ));
      }

      // Disclosed discounts first (the strongest honest signal); within each
      // group keep the overdue-first order (List.sort isn't stable, so
      // partition instead).
      final ordered = <OfferNudge>[
        ...nudges.where((n) => n.hasDisclosedDiscount),
        ...nudges.where((n) => !n.hasDisclosedDiscount),
      ];

      await _saveOfferCache(signature, ordered);
      debugPrint(
          '🥑 [AVO_NUDGE] Offer nudges: ${ordered.length}/${lookups.length} '
          'rhythm items on offer');
      return ordered.take(limit).toList();
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to compute offer nudges: $e');
      return [];
    }
  }

  /// Whether an offered product really is the user's item, precise enough
  /// for a proactive nudge. Plain substring matching is too loose here:
  /// "Milchreis"/"Milch Reis" contains "milch" but isn't milk. German
  /// compounds put the head noun last, so the item must be the *head*:
  /// either the product's last word exactly ("Frische Milch"), or the tail
  /// of a compound word ("Vollmilch", "Räucherkäse") — an exact word that
  /// is NOT last ("Milch Reis", "Frucht Butter Milch" for butter) is a
  /// modifier, not the product.
  @visibleForTesting
  static bool offerMatchesItem(String itemName, String productName) {
    final name = itemName.trim().toLowerCase();
    final product = productName.toLowerCase();
    if (name.isEmpty || product.isEmpty) return false;

    // Multi-word items ("golden toast"): the full name appearing in the
    // product is a strong match; otherwise fall through using the item's
    // longest word (usually its noun).
    String head = name;
    if (name.contains(' ')) {
      if (product.contains(name)) return true;
      head = name
          .split(RegExp(r'\s+'))
          .reduce((a, b) => b.length > a.length ? b : a);
    }
    if (head.length < 3) return false;

    final words = product
        .split(RegExp(r'[^a-zäöüß]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w == head) {
        if (i == words.length - 1) return true;
      } else if (w.endsWith(head)) {
        return true;
      }
    }
    return false;
  }

  /// The best live offer for [itemName]: among offers that actually match
  /// the item (see [offerMatchesItem]), the cheapest one with a disclosed
  /// discount of at least [_minOfferDiscountPercent]% — or, since most
  /// flyer offers disclose no regular price at all, the cheapest relevant
  /// offer.
  Future<StoreOffer?> _bestOfferFor(
    String itemName,
    String zipCode, {
    String? preferredRetailer,
  }) async {
    final offers =
        await OfferPriceService.instance.searchOffers(itemName, zipCode: zipCode);
    final relevant = [
      for (final offer in offers)
        if (offerMatchesItem(itemName, offer.productName)) offer,
    ];
    return pickOffer(relevant, preferredRetailer: preferredRetailer);
  }

  /// Choose which offer to surface, given the already relevance-filtered
  /// [offers] (price-sorted, cheapest first).
  ///
  /// Where the user habitually shops beats a few cents elsewhere: telling
  /// someone their bananas are cheap at a Netto across town is noise if they
  /// always shop at REWE. So an offer from [preferredRetailer] wins unless
  /// another shop is meaningfully cheaper — [_rivalMustBeatBy] guards against
  /// hiding a genuinely worthwhile saving.
  @visibleForTesting
  static StoreOffer? pickOffer(
    List<StoreOffer> offers, {
    String? preferredRetailer,
  }) {
    if (offers.isEmpty) return null;

    StoreOffer? best(Iterable<StoreOffer> candidates) {
      StoreOffer? cheapest;
      for (final offer in candidates) {
        cheapest ??= offer;
        final discount = offer.discountPercent;
        if (discount != null && discount >= _minOfferDiscountPercent) {
          return offer;
        }
      }
      return cheapest;
    }

    final overall = best(offers);
    final preferred = preferredRetailer?.trim().toLowerCase();
    if (preferred == null || preferred.isEmpty) return overall;

    final atPreferred = best(offers.where((o) =>
        o.retailerName.toLowerCase() == preferred ||
        o.retailerUniqueName.toLowerCase() == preferred));
    if (atPreferred == null) return overall;
    if (overall == null) return atPreferred;

    final saving = atPreferred.price - overall.price;
    return saving > _rivalMustBeatBy ? overall : atPreferred;
  }

  /// How much cheaper another shop must be before it displaces the user's
  /// usual one in an offer nudge.
  static const double _rivalMustBeatBy = 0.50;

  /// Snooze an offer nudge until its offer expires (or a week, when the
  /// offer has no end date) — it stops being relevant on its own.
  Future<void> snoozeOffer(OfferNudge nudge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozed = await _loadSnoozes(_offerSnoozeKey);
      final until = nudge.validTo != null &&
              nudge.validTo!.isAfter(DateTime.now())
          ? nudge.validTo!
          : DateTime.now().add(const Duration(days: 7));
      snoozed[nudge.itemName] = until.toIso8601String();
      await prefs.setString(_offerSnoozeKey, jsonEncode(snoozed));
      debugPrint('🥑 [AVO_NUDGE] Snoozed offer "${nudge.itemName}" until $until');
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to snooze offer: $e');
    }
  }

  Future<List<OfferNudge>?> _loadOfferCache(String signature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_offerCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['signature'] != signature) return null;
      final fetchedAt = DateTime.tryParse(decoded['fetchedAt'] as String? ?? '');
      if (fetchedAt == null ||
          DateTime.now().difference(fetchedAt) > _offerCacheTtl) {
        return null;
      }
      return (decoded['nudges'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OfferNudge.fromJson)
          .whereType<OfferNudge>()
          .toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveOfferCache(String signature, List<OfferNudge> nudges) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _offerCacheKey,
        jsonEncode({
          'signature': signature,
          'fetchedAt': DateTime.now().toIso8601String(),
          'nudges': nudges.map((n) => n.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to cache offer nudges: $e');
    }
  }

  /// Snooze a suggestion for one of its own purchase cycles (at least 2 days),
  /// so a dismissal isn't forever — the nudge comes back when it is plausibly
  /// due again.
  Future<void> snooze(RestockSuggestion suggestion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snoozed = await _loadSnoozes(_snoozeKey);
      final days = suggestion.averageDays < 2 ? 2 : suggestion.averageDays;
      snoozed[suggestion.itemName] =
          DateTime.now().add(Duration(days: days)).toIso8601String();
      await prefs.setString(_snoozeKey, jsonEncode(snoozed));
      debugPrint(
          '🥑 [AVO_NUDGE] Snoozed "${suggestion.itemName}" for $days days');
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to snooze: $e');
    }
  }

  /// Names (normalized) of all unchecked items on lists the user can see.
  /// RLS scopes the query to the user's own/shared lists.
  Future<Set<String>> _getOpenItemNames() async {
    try {
      final rows = await Supabase.instance.client
          .from('shopping_items')
          .select('name')
          .eq('is_checked', false);
      return (rows as List)
          .map((r) => (r['name'] as String? ?? '').trim().toLowerCase())
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('🥑 [AVO_NUDGE] Failed to load open items: $e');
      // Fail closed: if we can't check, suggest nothing rather than
      // suggesting an item that is already on a list.
      rethrow;
    }
  }

  Future<Map<String, String>> _loadSnoozes(String prefsKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      final result = <String, String>{};
      // Prune expired snoozes while loading.
      decoded.forEach((name, until) {
        final ts = DateTime.tryParse('$until');
        if (ts != null && ts.isAfter(now)) result[name] = '$until';
      });
      if (result.length != decoded.length) {
        await prefs.setString(prefsKey, jsonEncode(result));
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  bool _isSnoozed(Map<String, String> snoozed, String itemName) {
    return snoozed.containsKey(itemName);
  }

  String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }
}
