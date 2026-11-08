import 'package:flutter/foundation.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';

/// The unit of the amount on S7: grams (or ml), servings or packs of a
/// product with values per 100 g, or the unit of a food known only per
/// portion (an earlier entry in "Portion" or "Stück").
enum CalorieAmountUnit { base, serving, pack, portion }

/// What S7 "Menge" logs: a product with values per 100 g (Open Food Facts,
/// an own food, an earlier entry in g or ml) or a food known only per
/// portion. [kcal100] null = the product has no nutrition yet (S7 "Nährwerte
/// fehlen").
@immutable
class CalorieAmountFood {
  const CalorieAmountFood({
    required this.id,
    required this.name,
    required this.origin,
    this.brand,
    this.imageUrl,
    this.barcode,
    this.kcal100,
    this.protein100,
    this.carbs100,
    this.fat100,
    this.servingG,
    this.packageG,
    this.liquid = false,
    this.portion,
    this.initialAmount,
    this.fromOpenFoodFacts = false,
  });

  /// The route id: barcode, `own:<id>` or `recent:<entry id>`.
  final String id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? barcode;

  /// Source of the new entry (`barcode` scanned, `search` found by name,
  /// `manual` an own food).
  final FoodEntryOrigin origin;
  final int? kcal100;
  final double? protein100;
  final double? carbs100;
  final double? fat100;
  final double? servingG;
  final double? packageG;

  /// Amounts in ml ("pro 100 ml").
  final bool liquid;

  /// A food known only per portion: its last entry (amount, unit, numbers).
  final FoodLogEntry? portion;

  /// The amount to start with (grams, or portions for [portion]).
  final double? initialAmount;

  /// Values and photo come from Open Food Facts (attribution, product page).
  final bool fromOpenFoodFacts;

  bool get perPortion => portion != null;
  bool get hasNutrition => perPortion || kcal100 != null;
  String get baseUnit => liquid ? 'ml' : 'g';

  factory CalorieAmountFood.fromProduct(FoodProduct p, {required FoodEntryOrigin origin}) {
    final own = p.barcode.startsWith('own:');
    return CalorieAmountFood(
      id: p.barcode,
      name: p.name,
      brand: p.brand,
      imageUrl: p.imageUrl,
      barcode: own ? null : p.barcode,
      origin: own ? FoodEntryOrigin.manual : origin,
      kcal100: p.caloriesPer100g,
      protein100: p.proteinPer100g,
      carbs100: p.carbsPer100g,
      fat100: p.fatPer100g,
      servingG: p.servingG,
      packageG: p.packageG,
      liquid: p.isLiquid,
      fromOpenFoodFacts: !own && origin != FoodEntryOrigin.manual,
    );
  }

  factory CalorieAmountFood.fromUserFood(UserFood f) => CalorieAmountFood(
        id: 'own:${f.id}',
        name: f.name,
        barcode: f.barcode,
        origin: FoodEntryOrigin.manual,
        kcal100: f.kcal100.round(),
        protein100: f.protein100,
        carbs100: f.carbs100,
        fat100: f.fat100,
        servingG: f.servingG,
        packageG: f.packageG,
        initialAmount: f.servingG,
      );

  /// From an earlier entry ("Zuletzt gegessen" → "Andere Menge …"): per 100
  /// g when it was logged in g or ml, else per portion.
  factory CalorieAmountFood.fromEntry(FoodLogEntry e) {
    final unit = e.unit?.trim().toLowerCase();
    final grams = (unit == 'g' || unit == 'ml') && e.quantity > 0;
    if (grams) {
      final f = 100 / e.quantity;
      double? per(double? v) => v == null ? null : v * f;
      return CalorieAmountFood(
        id: 'recent:${e.id}',
        name: e.foodName,
        brand: e.brand,
        barcode: e.barcode,
        origin: e.origin,
        kcal100: (e.calories * f).round(),
        protein100: per(e.proteinG),
        carbs100: per(e.carbsG),
        fat100: per(e.fatG),
        liquid: unit == 'ml',
        initialAmount: e.quantity,
      );
    }
    return CalorieAmountFood(
      id: 'recent:${e.id}',
      name: e.foodName,
      brand: e.brand,
      barcode: e.barcode,
      origin: e.origin,
      portion: e,
      initialAmount: e.quantity > 0 ? e.quantity : 1,
    );
  }

  /// The units S7 offers as chips, base first.
  List<CalorieAmountUnit> get units => perPortion
      ? const [CalorieAmountUnit.portion]
      : [
          CalorieAmountUnit.base,
          if (servingG != null) CalorieAmountUnit.serving,
          if (packageG != null) CalorieAmountUnit.pack,
        ];

  /// The unit and amount S7 opens with.
  ({CalorieAmountUnit unit, double amount}) get start {
    if (perPortion) return (unit: CalorieAmountUnit.portion, amount: initialAmount ?? 1);
    final first = initialAmount;
    if (first != null) return (unit: CalorieAmountUnit.base, amount: first);
    if (servingG != null) return (unit: CalorieAmountUnit.serving, amount: 1);
    return (unit: CalorieAmountUnit.base, amount: 100);
  }

  /// Step of the stepper: ±10 g, ±0,5 Portion or Packung.
  static double stepOf(CalorieAmountUnit unit) => unit == CalorieAmountUnit.base ? 10 : 0.5;

  /// Grams (or ml) of [amount] in [unit]; null for a per-portion food.
  double? gramsOf(double amount, CalorieAmountUnit unit) => switch (unit) {
        CalorieAmountUnit.base => amount,
        CalorieAmountUnit.serving => amount * (servingG ?? 0),
        CalorieAmountUnit.pack => amount * (packageG ?? 0),
        CalorieAmountUnit.portion => null,
      };

  /// Numbers for [amount] in [unit]; [per100] overrides the product's values
  /// (typed in from the pack).
  ({int? kcal, double? protein, double? carbs, double? fat}) nutritionFor(
    double amount,
    CalorieAmountUnit unit, {
    ({int kcal, double? protein, double? carbs, double? fat})? per100,
  }) {
    final p = portion;
    if (p != null) {
      final f = p.quantity > 0 ? amount / p.quantity : amount;
      double? s(double? v) => v == null ? null : v * f;
      return (kcal: (p.calories * f).round(), protein: s(p.proteinG), carbs: s(p.carbsG), fat: s(p.fatG));
    }
    final g = gramsOf(amount, unit) ?? 0;
    final kcal = per100?.kcal ?? kcal100;
    double? s(double? v) => v == null ? null : v * g / 100;
    return (
      kcal: kcal == null ? null : (kcal * g / 100).round(),
      protein: s(per100 != null ? per100.protein : protein100),
      carbs: s(per100 != null ? per100.carbs : carbs100),
      fat: s(per100 != null ? per100.fat : fat100),
    );
  }

  /// The diary row for [amount] in [unit] on [dateKey]/[meal].
  FoodLogEntry entryFor({
    required double amount,
    required CalorieAmountUnit unit,
    required String dateKey,
    required MealType meal,
    required DateTime now,
    ({int kcal, double? protein, double? carbs, double? fat})? per100,
  }) {
    final n = nutritionFor(amount, unit, per100: per100);
    final p = portion;
    return FoodLogEntry(
      id: '',
      userId: '',
      loggedDate: parseCalorieDayKey(dateKey),
      mealType: meal,
      origin: p?.origin ?? origin,
      sourceRecipeId: p?.sourceRecipeId,
      foodName: name,
      brand: brand,
      quantity: p != null ? amount : (gramsOf(amount, unit) ?? amount),
      unit: p != null ? p.unit : baseUnit,
      calories: n.kcal ?? 0,
      proteinG: n.protein,
      carbsG: n.carbs,
      fatG: n.fat,
      barcode: barcode,
      estimated: p?.estimated ?? false,
      confidence: p?.confidence,
      loggedTime: FoodLogTime.of(now),
      createdAt: now,
    );
  }
}
