/// Models for live supermarket offers (marktguru) and basket price
/// comparison across nearby stores.

/// A single offer of a product at a retailer, valid for a date range.
class StoreOffer {
  final int id;
  final String productName;
  final String? brandName;
  final String description;
  final double price;
  final double? oldPrice;
  final String? unitShortName;
  final String retailerName;
  final String retailerUniqueName;
  final String? categoryName;
  final DateTime? validFrom;
  final DateTime? validTo;

  const StoreOffer({
    required this.id,
    required this.productName,
    required this.brandName,
    required this.description,
    required this.price,
    required this.oldPrice,
    required this.unitShortName,
    required this.retailerName,
    required this.retailerUniqueName,
    required this.categoryName,
    required this.validFrom,
    required this.validTo,
  });

  /// Non-food categories to hide (marktguru mixes appliances, drugstore,
  /// furniture into grocery-term searches — e.g. "Toaster" for "Toast").
  static const Set<String> _nonFoodCategories = {
    'küchengeräte',
    'haushaltsgeräte',
    'haushalt',
    'elektro',
    'elektronik',
    'multimedia',
    'möbel',
    'garten',
    'baumarkt',
    'heimwerken',
    'kleidung',
    'mode',
    'schuhe',
    'spielzeug',
    'drogerie',
    'kosmetik',
    'körperpflege',
    'schönheitspflege',
    'gesundheit',
    'tierbedarf',
    'auto',
    'werkzeug',
    'schmuck',
    'uhren',
    'buch',
    'schreibwaren',
  };

  /// Whether this offer looks like an actual grocery/food product.
  bool get isFood {
    final cat = categoryName?.toLowerCase().trim();
    if (cat == null || cat.isEmpty) return true; // no category → keep
    return !_nonFoodCategories.any((c) => cat.contains(c));
  }

  /// Offer product image served by the marktguru CDN.
  String get imageUrl =>
      'https://mg2de.b-cdn.net/api/v1/offers/$id/images/default/0/medium.jpg';

  static final _regularPricePattern = RegExp(
    r'(?:normalpreis|statt|uvp|vorher|bisher)[:\s]*([0-9]+[.,][0-9]{1,2})',
    caseSensitive: false,
  );

  /// The regular (non-offer) price, when the retailer discloses it:
  /// either via the API's oldPrice or embedded in the description
  /// ("Normalpreis: 2.29", "statt 3,49", "UVP 4,99").
  double? get regularPrice {
    if (oldPrice != null && oldPrice! > price) return oldPrice;
    final match = _regularPricePattern.firstMatch(description);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (value != null && value > price) return value;
    }
    return null;
  }

  /// Discount vs. the regular price in percent (null below 5% or unknown).
  int? get discountPercent {
    final regular = regularPrice;
    if (regular == null || regular <= 0) return null;
    final percent = ((1 - price / regular) * 100).round();
    return percent >= 5 ? percent : null;
  }

  bool get isValidNow {
    final now = DateTime.now().toUtc();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    return true;
  }

  static StoreOffer? fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble();
    final product = json['product'] as Map<String, dynamic>?;
    final advertisers = json['advertisers'] as List?;
    if (price == null || product == null || advertisers == null || advertisers.isEmpty) {
      return null;
    }
    final advertiser = advertisers.first as Map<String, dynamic>;
    final categories = (json['categories'] as List?)?.cast<Map<String, dynamic>>();
    final categoryName = (categories != null && categories.isNotEmpty)
        ? categories.first['name'] as String?
        : null;
    final validity = (json['validityDates'] as List?)?.cast<Map<String, dynamic>>();

    DateTime? from;
    DateTime? to;
    if (validity != null && validity.isNotEmpty) {
      from = DateTime.tryParse(validity.first['from'] as String? ?? '');
      to = DateTime.tryParse(validity.first['to'] as String? ?? '');
    }

    return StoreOffer(
      id: json['id'] as int,
      productName: (product['name'] as String?)?.trim() ?? '',
      brandName: (json['brand'] as Map<String, dynamic>?)?['name'] as String?,
      description: (json['description'] as String?) ?? '',
      price: price,
      oldPrice: (json['oldPrice'] as num?)?.toDouble(),
      unitShortName:
          (json['unit'] as Map<String, dynamic>?)?['shortName'] as String?,
      retailerName: (advertiser['name'] as String?) ?? '',
      retailerUniqueName: (advertiser['uniqueName'] as String?) ?? '',
      categoryName: categoryName,
      validFrom: from,
      validTo: to,
    );
  }
}

/// One shopping-list item matched (or not) with its cheapest offer at a store.
class BasketItemMatch {
  final String itemName;
  final StoreOffer? offer;

  const BasketItemMatch({required this.itemName, this.offer});

  bool get hasOffer => offer != null;
}

/// Per-store summary for the comparable basket.
///
/// [comparableTotal] always covers the SAME set of items across every store:
/// where the store has its own offer we use it, otherwise we fill with the
/// cheapest offer found for that item anywhere. That makes store totals
/// directly comparable (no partial-basket confusion), while [matchedCount]
/// still shows how many items are genuinely on offer at this store.
class StoreBasketResult {
  final String retailerName;
  final String retailerUniqueName;
  final List<BasketItemMatch> matches;
  final double comparableTotal;

  const StoreBasketResult({
    required this.retailerName,
    required this.retailerUniqueName,
    required this.matches,
    required this.comparableTotal,
  });

  int get matchedCount => matches.where((m) => m.hasOffer).length;

  /// Sum of the store's own offers only (may cover fewer items).
  double get ownTotal => matches
      .where((m) => m.hasOffer)
      .fold(0.0, (sum, m) => sum + m.offer!.price);

  double get savings => matches.where((m) => m.hasOffer).fold(0.0, (sum, m) {
        final regular = m.offer!.regularPrice;
        return regular != null ? sum + (regular - m.offer!.price) : sum;
      });
}

/// Full comparison of the basket across all nearby stores.
class BasketComparison {
  final String zipCode;

  /// Number of list items that at least one store has on offer (the basis
  /// for the comparable totals).
  final int comparableItemCount;
  final List<StoreBasketResult> stores;

  const BasketComparison({
    required this.zipCode,
    required this.comparableItemCount,
    required this.stores,
  });

  /// Stores sorted cheapest-first by the comparable basket total.
  List<StoreBasketResult> get ranked {
    final sorted = List<StoreBasketResult>.from(stores)
      ..sort((a, b) {
        final byTotal = a.comparableTotal.compareTo(b.comparableTotal);
        if (byTotal != 0) return byTotal;
        return b.matchedCount.compareTo(a.matchedCount);
      });
    return sorted;
  }

  /// Best store: the cheapest comparable basket that has at least one own
  /// offer, so we never recommend a store that carries none of the items.
  StoreBasketResult? get bestStore {
    for (final store in ranked) {
      if (store.matchedCount > 0) return store;
    }
    return null;
  }

  /// The cheapest current offer for a single list item across all stores,
  /// or null when no store has it on offer. [itemName] must be the trimmed
  /// item name the comparison was built from.
  StoreOffer? cheapestOfferFor(String itemName) {
    StoreOffer? cheapest;
    for (final store in stores) {
      for (final match in store.matches) {
        final offer = match.offer;
        if (offer == null || match.itemName != itemName) continue;
        if (cheapest == null || offer.price < cheapest.price) {
          cheapest = offer;
        }
      }
    }
    return cheapest;
  }
}
