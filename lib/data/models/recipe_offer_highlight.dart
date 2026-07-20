import 'package:shoply/data/models/store_offer.dart';

/// One recipe ingredient matched with its best current supermarket offer
/// (Feature 8: "this recipe is cheaper this week — these ingredients are on
/// offer"). A slim, JSON-serializable snapshot of the matched [StoreOffer] so
/// results can live in a persistent cache without persisting the full offer
/// payload.
class RecipeIngredientOffer {
  final String ingredientName;
  final int offerId;
  final String productName;
  final String retailerName;
  final double price;
  final double? regularPrice;
  final String? unitSizeLabel;
  final String? unitPriceLabel;
  final DateTime? validTo;

  /// True when the match was found via generic-term broadening (a related
  /// but not exactly-matching product) — shown as "similar product" and
  /// excluded from the savings sum.
  final bool isBroadMatch;

  const RecipeIngredientOffer({
    required this.ingredientName,
    required this.offerId,
    required this.productName,
    required this.retailerName,
    required this.price,
    this.regularPrice,
    this.unitSizeLabel,
    this.unitPriceLabel,
    this.validTo,
    this.isBroadMatch = false,
  });

  factory RecipeIngredientOffer.fromStoreOffer(
    String ingredientName,
    StoreOffer offer,
  ) {
    return RecipeIngredientOffer(
      ingredientName: ingredientName,
      offerId: offer.id,
      productName: offer.productName,
      retailerName: offer.retailerName,
      price: offer.price,
      regularPrice: offer.regularPrice,
      unitSizeLabel: offer.unitSizeLabel,
      unitPriceLabel: offer.unitPriceLabel,
      validTo: offer.validTo,
      isBroadMatch: offer.isBroadMatch,
    );
  }

  /// Offer product image served by the marktguru CDN (same URL scheme as
  /// [StoreOffer.imageUrl]).
  String get imageUrl =>
      'https://mg2de.b-cdn.net/api/v1/offers/$offerId/images/default/0/medium.jpg';

  /// Discount vs. the regular price in percent (null below 5% or unknown) —
  /// same rule as [StoreOffer.discountPercent].
  int? get discountPercent {
    final regular = regularPrice;
    if (regular == null || regular <= 0) return null;
    final percent = ((1 - price / regular) * 100).round();
    return percent >= 5 ? percent : null;
  }

  /// Whether the offer's validity window is still open. Cached results can
  /// outlive an offer's end date (weekly Angebote vs. a 6h cache read hours
  /// later), so expired matches are filtered out at read time.
  bool get isStillValid {
    if (validTo == null) return true;
    return !DateTime.now().toUtc().isAfter(validTo!.toUtc());
  }

  Map<String, dynamic> toJson() => {
        'ingredientName': ingredientName,
        'offerId': offerId,
        'productName': productName,
        'retailerName': retailerName,
        'price': price,
        'regularPrice': regularPrice,
        'unitSizeLabel': unitSizeLabel,
        'unitPriceLabel': unitPriceLabel,
        'validTo': validTo?.toIso8601String(),
        'isBroadMatch': isBroadMatch,
      };

  static RecipeIngredientOffer? fromJson(Map<String, dynamic> json) {
    final ingredientName = json['ingredientName'] as String?;
    final offerId = json['offerId'] as int?;
    final productName = json['productName'] as String?;
    final price = (json['price'] as num?)?.toDouble();
    if (ingredientName == null ||
        offerId == null ||
        productName == null ||
        price == null) {
      return null;
    }
    return RecipeIngredientOffer(
      ingredientName: ingredientName,
      offerId: offerId,
      productName: productName,
      retailerName: (json['retailerName'] as String?) ?? '',
      price: price,
      regularPrice: (json['regularPrice'] as num?)?.toDouble(),
      unitSizeLabel: json['unitSizeLabel'] as String?,
      unitPriceLabel: json['unitPriceLabel'] as String?,
      validTo: DateTime.tryParse(json['validTo'] as String? ?? ''),
      isBroadMatch: (json['isBroadMatch'] as bool?) ?? false,
    );
  }
}

/// All current offers found for a recipe's ingredients around a zip code.
/// An empty [matches] list is a valid, cacheable answer ("checked, nothing
/// on offer right now") — the UI simply renders nothing for it.
class RecipeOffersResult {
  final String recipeId;
  final String zipCode;

  /// How many ingredients were actually checked against the offers API
  /// (staples like salt/water are skipped, and very long ingredient lists
  /// are capped — see RecipeOfferService).
  final int checkedIngredientCount;
  final List<RecipeIngredientOffer> matches;

  /// The exact recipe+zip+ingredients snapshot this was computed from;
  /// cache entries are only reused for an identical signature.
  final String signature;

  const RecipeOffersResult({
    required this.recipeId,
    required this.zipCode,
    required this.checkedIngredientCount,
    required this.matches,
    required this.signature,
  });

  /// Known savings vs. regular prices, summed over exact (non-broad) matches
  /// whose retailer disclosed a regular price. Broad matches are excluded —
  /// "save €X" shouldn't be claimed off a merely similar product.
  double get knownSavings => matches
      .where((m) => !m.isBroadMatch && m.regularPrice != null)
      .fold(0.0, (sum, m) => sum + (m.regularPrice! - m.price));

  RecipeOffersResult copyWithMatches(List<RecipeIngredientOffer> newMatches) {
    return RecipeOffersResult(
      recipeId: recipeId,
      zipCode: zipCode,
      checkedIngredientCount: checkedIngredientCount,
      matches: newMatches,
      signature: signature,
    );
  }

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'zipCode': zipCode,
        'checkedIngredientCount': checkedIngredientCount,
        'matches': matches.map((m) => m.toJson()).toList(),
        'signature': signature,
      };

  static RecipeOffersResult? fromJson(Map<String, dynamic> json) {
    final recipeId = json['recipeId'] as String?;
    final zipCode = json['zipCode'] as String?;
    final signature = json['signature'] as String?;
    if (recipeId == null || zipCode == null || signature == null) return null;
    final matches = (json['matches'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RecipeIngredientOffer.fromJson)
        .whereType<RecipeIngredientOffer>()
        .toList();
    return RecipeOffersResult(
      recipeId: recipeId,
      zipCode: zipCode,
      checkedIngredientCount:
          (json['checkedIngredientCount'] as num?)?.toInt() ?? matches.length,
      matches: matches,
      signature: signature,
    );
  }
}
