import 'package:equatable/equatable.dart';

/// A food product looked up from Open Food Facts (by name search or
/// barcode), normalized to per-100g nutrition plus the fields needed to log
/// a specific quantity of it.
class FoodProduct extends Equatable {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  /// One serving / one package in grams, when Open Food Facts knows them
  /// ("Portion · 150 g", "Packung · 500 g").
  final double? servingG;
  final double? packageG;

  /// Open Food Facts had no name ([name] is then empty; the screens treat
  /// the product as unknown).
  final bool hasName;

  /// Sold by volume (`product_quantity_unit` "ml"): amounts and "pro 100 ml"
  /// are in millilitres.
  final bool isLiquid;

  const FoodProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.servingG,
    this.packageG,
    this.hasName = true,
    this.isLiquid = false,
  });

  bool get hasNutrition => caloriesPer100g != null;

  /// Scales per-100g nutrition to a given weight in grams (0 without data;
  /// new code uses [caloriesForOrNull] so a missing value is never 0 kcal).
  int caloriesFor(double grams) => caloriesForOrNull(grams) ?? 0;

  int? caloriesForOrNull(double grams) =>
      caloriesPer100g == null ? null : ((caloriesPer100g! * grams) / 100).round();
  double? _scale(double? per100g, double grams) =>
      per100g == null ? null : (per100g * grams) / 100;
  double? proteinFor(double grams) => _scale(proteinPer100g, grams);
  double? carbsFor(double grams) => _scale(carbsPer100g, grams);
  double? fatFor(double grams) => _scale(fatPer100g, grams);

  static String? _brandString(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.isEmpty ? null : raw.first.toString();
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s.split(',').first.trim();
  }

  /// Open Food Facts sends numbers as numbers or strings ("63", "n/a");
  /// anything unreadable is "unknown", never a crash (old `as num` emptied
  /// the whole search).
  static double? _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
    return null;
  }

  static double? _num(Map<String, dynamic>? nutriments, String key) => _toDouble(nutriments?[key]);

  static double? _grams(Object? v) {
    final d = _toDouble(v);
    return d != null && d > 0 ? d : null;
  }

  /// Parses one hit from the search-a-licious `/search` endpoint or one
  /// `product` object from the `/api/v2/product/{barcode}.json` endpoint —
  /// both share the same field names for what this app needs.
  factory FoodProduct.fromOpenFoodFacts(Map<String, dynamic> json) {
    final nutriments = json['nutriments'] as Map<String, dynamic>?;
    final name = (json['product_name'] as String?)?.trim();
    return FoodProduct(
      barcode: json['code'] as String? ?? '',
      name: name ?? '',
      hasName: name != null && name.isNotEmpty,
      isLiquid: (json['product_quantity_unit'] as String?)?.trim().toLowerCase() == 'ml',
      brand: _brandString(json['brands']),
      imageUrl: json['image_front_small_url'] as String?,
      caloriesPer100g: _num(nutriments, 'energy-kcal_100g')?.round(),
      proteinPer100g: _num(nutriments, 'proteins_100g'),
      carbsPer100g: _num(nutriments, 'carbohydrates_100g'),
      fatPer100g: _num(nutriments, 'fat_100g'),
      servingG: _grams(json['serving_quantity']),
      packageG: _grams(json['product_quantity']),
    );
  }

  /// The product as this device keeps it (product cache, "Zuletzt
  /// gescannt").
  Map<String, dynamic> toCacheJson() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'image': imageUrl,
        'kcal': caloriesPer100g,
        'protein': proteinPer100g,
        'carbs': carbsPer100g,
        'fat': fatPer100g,
        'serving_g': servingG,
        'package_g': packageG,
        'liquid': isLiquid,
      };

  factory FoodProduct.fromCacheJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    final name = json['name'] as String? ?? '';
    return FoodProduct(
      barcode: json['barcode'] as String,
      name: name,
      hasName: name.isNotEmpty,
      brand: json['brand'] as String?,
      imageUrl: json['image'] as String?,
      caloriesPer100g: (json['kcal'] as num?)?.round(),
      proteinPer100g: d('protein'),
      carbsPer100g: d('carbs'),
      fatPer100g: d('fat'),
      servingG: d('serving_g'),
      packageG: d('package_g'),
      isLiquid: json['liquid'] as bool? ?? false,
    );
  }

  /// The same product with nutrition per 100 g typed in from the pack
  /// (S7 "Nährwerte fehlen").
  FoodProduct withNutrition({
    required int kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) =>
      FoodProduct(
        barcode: barcode,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        caloriesPer100g: kcal,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        servingG: servingG,
        packageG: packageG,
        hasName: hasName,
        isLiquid: isLiquid,
      );

  @override
  List<Object?> get props => [
        barcode,
        name,
        brand,
        imageUrl,
        caloriesPer100g,
        proteinPer100g,
        carbsPer100g,
        fatPer100g,
        servingG,
        packageG,
        hasName,
        isLiquid,
      ];
}
