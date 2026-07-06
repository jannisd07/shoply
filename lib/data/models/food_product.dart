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

  const FoodProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  bool get hasNutrition => caloriesPer100g != null;

  /// Scales per-100g nutrition to a given weight in grams.
  int caloriesFor(double grams) =>
      caloriesPer100g == null ? 0 : ((caloriesPer100g! * grams) / 100).round();
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

  static double? _num(Map<String, dynamic>? nutriments, String key) {
    final v = nutriments?[key];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  /// Parses one hit from the search-a-licious `/search` endpoint or one
  /// `product` object from the `/api/v2/product/{barcode}.json` endpoint —
  /// both share the same field names for what this app needs.
  factory FoodProduct.fromOpenFoodFacts(Map<String, dynamic> json) {
    final nutriments = json['nutriments'] as Map<String, dynamic>?;
    final name = (json['product_name'] as String?)?.trim();
    return FoodProduct(
      barcode: json['code'] as String? ?? '',
      name: (name == null || name.isEmpty) ? 'Unknown product' : name,
      brand: _brandString(json['brands']),
      imageUrl: json['image_front_small_url'] as String?,
      caloriesPer100g: _num(nutriments, 'energy-kcal_100g')?.round(),
      proteinPer100g: _num(nutriments, 'proteins_100g'),
      carbsPer100g: _num(nutriments, 'carbohydrates_100g'),
      fatPer100g: _num(nutriments, 'fat_100g'),
    );
  }

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
      ];
}
