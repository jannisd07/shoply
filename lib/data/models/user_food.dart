import 'package:equatable/equatable.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';

/// An own food ("Eigene"): saved from a manual entry or typed in from the
/// package when a barcode was unknown. Values per 100 g (`user_food`).
class UserFood extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? barcode;
  final double kcal100;
  final double? protein100;
  final double? carbs100;
  final double? fat100;
  final double? servingG;
  final double? packageG;
  final DateTime createdAt;

  const UserFood({
    required this.id,
    required this.userId,
    required this.name,
    this.barcode,
    required this.kcal100,
    this.protein100,
    this.carbs100,
    this.fat100,
    this.servingG,
    this.packageG,
    required this.createdAt,
  });

  /// Limits of the `user_food` checks (B6 migration): a row outside them is
  /// rejected by the server for good.
  static const int maxNameLength = 200;
  static const double maxKcal100 = 900;
  static const double maxMacro100 = 100;
  static final RegExp _barcode = RegExp(r'^[0-9]{6,14}$');

  /// A barcode the table takes, or null.
  static String? validBarcode(String? code) {
    final c = code?.trim();
    return c != null && _barcode.hasMatch(c) ? c : null;
  }

  /// Fits every check of `user_food`: name 1–200 characters, kcal 0–900 and
  /// macros 0–100 per 100 g, serving and pack above 0, barcode 6–14 digits.
  bool get fitsServer {
    final n = name.trim();
    bool macro(double? v) => v == null || (v >= 0 && v <= maxMacro100);
    return n.isNotEmpty &&
        n.length <= maxNameLength &&
        kcal100 >= 0 &&
        kcal100 <= maxKcal100 &&
        macro(protein100) &&
        macro(carbs100) &&
        macro(fat100) &&
        (servingG == null || servingG! > 0) &&
        (packageG == null || packageG! > 0) &&
        (barcode == null || validBarcode(barcode) != null);
  }

  /// From a logged entry whose amount is in g or ml; null otherwise (a
  /// "Stück"/"Portion" entry has no per-100 g basis) and when the values per
  /// 100 g leave the table's limits (500 kcal in 50 g would be 1.000 kcal per
  /// 100 g). A barcode the table does not take is dropped; the name is cut
  /// to 200 characters.
  static UserFood? fromEntry(FoodLogEntry entry, {required String id}) {
    final unit = entry.unit?.toLowerCase();
    if ((unit != 'g' && unit != 'ml') || entry.quantity <= 0) return null;
    final factor = 100 / entry.quantity;
    double? per100(double? v) => v == null ? null : v * factor;
    final name = entry.foodName.trim();
    final food = UserFood(
      id: id,
      userId: entry.userId,
      name: name.length > maxNameLength ? name.substring(0, maxNameLength) : name,
      barcode: validBarcode(entry.barcode),
      kcal100: entry.calories * factor,
      protein100: per100(entry.proteinG),
      carbs100: per100(entry.carbsG),
      fat100: per100(entry.fatG),
      servingG: entry.quantity,
      createdAt: entry.createdAt,
    );
    return food.fitsServer ? food : null;
  }

  int caloriesFor(double grams) => (kcal100 * grams / 100).round();
  double? proteinFor(double grams) => protein100 == null ? null : protein100! * grams / 100;
  double? carbsFor(double grams) => carbs100 == null ? null : carbs100! * grams / 100;
  double? fatFor(double grams) => fat100 == null ? null : fat100! * grams / 100;

  /// Same shape as an Open Food Facts hit, for search and the amount screen.
  FoodProduct toFoodProduct() => FoodProduct(
        barcode: barcode ?? 'own:$id',
        name: name,
        caloriesPer100g: kcal100.round(),
        proteinPer100g: protein100,
        carbsPer100g: carbs100,
        fatPer100g: fat100,
        servingG: servingG,
        packageG: packageG,
      );

  factory UserFood.fromJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    return UserFood(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      kcal100: d('kcal_100') ?? 0,
      protein100: d('protein_100'),
      carbs100: d('carbs_100'),
      fat100: d('fat_100'),
      servingG: d('serving_g'),
      packageG: d('package_g'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'barcode': barcode,
        'kcal_100': kcal100,
        'protein_100': protein100,
        'carbs_100': carbs100,
        'fat_100': fat100,
        'serving_g': servingG,
        'package_g': packageG,
        'created_at': createdAt.toIso8601String(),
      };

  /// Row for an upsert (the server sets `created_at` on insert).
  Map<String, dynamic> toUpsertJson() => Map.of(toJson())..remove('created_at');

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        barcode,
        kcal100,
        protein100,
        carbs100,
        fat100,
        servingG,
        packageG,
        createdAt,
      ];
}
