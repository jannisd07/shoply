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
    required this.validFrom,
    required this.validTo,
  });

  /// Offer product image served by the marktguru CDN.
  String get imageUrl =>
      'https://mg2de.b-cdn.net/api/v1/offers/$id/images/default/0/medium.jpg';

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

/// Per-store summary: how many basket items are on offer and what they cost.
class StoreBasketResult {
  final String retailerName;
  final String retailerUniqueName;
  final List<BasketItemMatch> matches;

  const StoreBasketResult({
    required this.retailerName,
    required this.retailerUniqueName,
    required this.matches,
  });

  int get matchedCount => matches.where((m) => m.hasOffer).length;

  double get total => matches
      .where((m) => m.hasOffer)
      .fold(0.0, (sum, m) => sum + m.offer!.price);

  double get savings => matches.where((m) => m.hasOffer).fold(0.0, (sum, m) {
        final old = m.offer!.oldPrice;
        return old != null && old > m.offer!.price
            ? sum + (old - m.offer!.price)
            : sum;
      });
}

/// Full comparison of the basket across all nearby stores.
class BasketComparison {
  final String zipCode;
  final int itemCount;
  final List<StoreBasketResult> stores;

  const BasketComparison({
    required this.zipCode,
    required this.itemCount,
    required this.stores,
  });

  /// Best store: most basket items on offer, ties broken by lower total.
  StoreBasketResult? get bestStore {
    if (stores.isEmpty) return null;
    final sorted = List<StoreBasketResult>.from(stores)
      ..sort((a, b) {
        final byCount = b.matchedCount.compareTo(a.matchedCount);
        if (byCount != 0) return byCount;
        return a.total.compareTo(b.total);
      });
    return sorted.first.matchedCount > 0 ? sorted.first : null;
  }
}
