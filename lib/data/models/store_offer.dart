/// A single offer of a product at a retailer (marktguru), valid for a date
/// range. Offers are only ever shown for one market at a time; the app never
/// compares markets or sums a basket (Kap. 12, rule 2).
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

  /// Pack size in [unitShortName] (e.g. `0.5` for a 500g pack, in kg).
  final double? volume;
  /// Number of packs the offer price covers (e.g. `12` for a 12-pack case).
  /// `null`/`1` for a single pack.
  final double? packQuantity;
  /// Price per [unitShortName] ("Grundpreis"), e.g. €/kg or €/l — already
  /// computed by the API as `price / (volume * packQuantity)`.
  final double? referencePrice;

  /// True when this offer was only found by broadening the user's search to
  /// a generic stem (e.g. "Toastbrötchen" → "toast") rather than matching
  /// the typed product directly — a lower-confidence match worth flagging
  /// so the user can double-check it's the right product before adding it.
  final bool isBroadMatch;

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
    this.volume,
    this.packQuantity,
    this.referencePrice,
    this.isBroadMatch = false,
  });

  /// Same offer, flagged as having been found via generic-term broadening.
  StoreOffer asBroadMatch() => StoreOffer(
        id: id,
        productName: productName,
        brandName: brandName,
        description: description,
        price: price,
        oldPrice: oldPrice,
        unitShortName: unitShortName,
        retailerName: retailerName,
        retailerUniqueName: retailerUniqueName,
        categoryName: categoryName,
        validFrom: validFrom,
        validTo: validTo,
        volume: volume,
        packQuantity: packQuantity,
        referencePrice: referencePrice,
        isBroadMatch: true,
      );

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

  /// Retailer images are not licensed (Kap. 12, rule 7): always empty, so
  /// no image is ever loaded from the offers source. Kept only for
  /// `weekly_deals_screen.dart` until it shows the category symbol.
  @Deprecated('Retailer images are not licensed; show the category symbol')
  String get imageUrl => '';

  /// "statt" prices the retailer states itself. A UVP is the manufacturer's
  /// recommendation, not the retailer's former price, so it never counts.
  static final _regularPricePattern = RegExp(
    r'(?:normalpreis|statt|vorher|bisher)[:\s]*([0-9]+[.,][0-9]{1,2})',
    caseSensitive: false,
  );

  /// The retailer's own "statt" price ("laut Händler statt 1,19 €"), when it
  /// states one: the API's oldPrice or a "Normalpreis"/"statt"/"vorher"/
  /// "bisher" price in the description. Never a UVP. The app knows no
  /// regular shelf prices of its own.
  double? get regularPrice {
    if (oldPrice != null && oldPrice! > price) return oldPrice;
    final match = _regularPricePattern.firstMatch(description);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (value != null && value > price) return value;
    }
    return null;
  }

  /// Whether this offer is from the market [chainId] (a
  /// `StoreChainDirectory` id, which is the marktguru `uniqueName`).
  bool isFromChain(String chainId) {
    final name = retailerUniqueName.toLowerCase();
    final chain = chainId.toLowerCase();
    return name == chain || name.startsWith('$chain-');
  }

  bool get isValidNow {
    final now = DateTime.now().toUtc();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    return true;
  }

  static String _formatNum(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    // Trim to at most 2 decimals, no trailing zero (e.g. 1.5, not 1.50).
    var s = n.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Human-readable pack size, e.g. "500 g", "1.5 l", or "12 x 1 l" for a
  /// multi-pack. Null when the API didn't provide pack-size data.
  String? get unitSizeLabel {
    if (volume == null || unitShortName == null || volume! <= 0) return null;
    final size = '${_formatNum(volume!)} $unitShortName';
    if (packQuantity != null && packQuantity! > 1) {
      return '${_formatNum(packQuantity!)} x $size';
    }
    return size;
  }

  /// "Grundpreis" — price per [unitShortName], e.g. "1.58 €/kg". Null when
  /// unavailable, or when it wouldn't add information beyond the sale price
  /// (a plain single unit, e.g. exactly 1 l for 1 pack).
  String? get unitPriceLabel {
    if (referencePrice == null || unitShortName == null) return null;
    final isPlainSingleUnit = (packQuantity == null || packQuantity == 1) &&
        volume != null &&
        volume == 1;
    if (isPlainSingleUnit) return null;
    return '${referencePrice!.toStringAsFixed(2)} €/$unitShortName';
  }

  /// The offer in the shape of the marktguru API, so [fromJson] reads it
  /// back (the list sync keeps offers on the device for 6 h).
  /// [isBroadMatch] is not part of it.
  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'oldPrice': oldPrice,
        'description': description,
        'product': {'name': productName},
        'brand': brandName == null ? null : {'name': brandName},
        'unit': unitShortName == null ? null : {'shortName': unitShortName},
        'advertisers': [
          {'name': retailerName, 'uniqueName': retailerUniqueName},
        ],
        'categories': [
          if (categoryName != null) {'name': categoryName},
        ],
        'validityDates': [
          {
            'from': validFrom?.toIso8601String(),
            'to': validTo?.toIso8601String(),
          },
        ],
        'volume': volume,
        'quantity': packQuantity,
        'referencePrice': referencePrice,
      };

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
      volume: (json['volume'] as num?)?.toDouble(),
      packQuantity: (json['quantity'] as num?)?.toDouble(),
      referencePrice: (json['referencePrice'] as num?)?.toDouble(),
    );
  }
}
