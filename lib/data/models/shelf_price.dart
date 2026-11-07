/// A regular ("shelf") price for a product, as opposed to a promotional
/// offer. Sourced from Open Food Facts' Open Prices database.
class ShelfPrice {
  final double price;
  final String currency;

  /// When this price was observed in the store — crowdsourced data can be
  /// months old, so this always travels with the price.
  final DateTime observedAt;

  /// Store name as recorded in OpenStreetMap, e.g. "REWE", "EDEKA".
  final String? retailer;

  /// Barcode the price belongs to.
  final String barcode;

  /// Product name from Open Food Facts, for showing what was actually matched.
  final String? productName;

  /// How many observations the [price] was derived from. One lone data point
  /// deserves less trust than a median over a dozen.
  final int sampleSize;

  const ShelfPrice({
    required this.price,
    required this.currency,
    required this.observedAt,
    required this.barcode,
    this.retailer,
    this.productName,
    this.sampleSize = 1,
  });

  /// Crowdsourced prices go stale. Beyond this the UI should mark them as
  /// an estimate rather than present them as the current price.
  static const Duration staleAfter = Duration(days: 120);

  bool get isStale => DateTime.now().difference(observedAt) > staleAfter;

  Map<String, dynamic> toJson() => {
        'price': price,
        'currency': currency,
        'observedAt': observedAt.toIso8601String(),
        'retailer': retailer,
        'barcode': barcode,
        'productName': productName,
        'sampleSize': sampleSize,
      };

  static ShelfPrice? fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble();
    final observed = DateTime.tryParse(json['observedAt'] as String? ?? '');
    final barcode = json['barcode'] as String?;
    if (price == null || observed == null || barcode == null) return null;
    return ShelfPrice(
      price: price,
      currency: json['currency'] as String? ?? 'EUR',
      observedAt: observed,
      retailer: json['retailer'] as String?,
      barcode: barcode,
      productName: json['productName'] as String?,
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 1,
    );
  }
}

/// One raw price observation, before aggregation.
class PriceObservation {
  final double price;
  final String currency;
  final DateTime date;
  final String? retailer;
  final String countryCode;
  final String barcode;
  final bool isDiscounted;

  const PriceObservation({
    required this.price,
    required this.currency,
    required this.date,
    required this.countryCode,
    required this.barcode,
    this.retailer,
    this.isDiscounted = false,
  });
}
