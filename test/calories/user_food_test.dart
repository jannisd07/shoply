import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';

void main() {
  final skyr = UserFood(
    id: 'f1',
    userId: 'u1',
    name: 'Skyr Natur',
    barcode: '4056489123457',
    kcal100: 63,
    protein100: 11,
    carbs100: 4,
    fat100: 0.2,
    servingG: 150,
    packageG: 500,
    createdAt: DateTime.utc(2026, 11, 7),
  );

  test('scales per-100 g values to an amount', () {
    expect(skyr.caloriesFor(250), 158);
    expect(skyr.proteinFor(250), closeTo(27.5, 0.001));
    expect(skyr.fatFor(250), closeTo(0.5, 0.001));
  });

  test('round-trips its row', () {
    expect(UserFood.fromJson(skyr.toJson()), skyr);
    expect(skyr.toJson()['kcal_100'], 63);
  });

  test('works as a product in search and the amount screen', () {
    final p = skyr.toFoodProduct();
    expect(p.barcode, '4056489123457');
    expect(p.caloriesPer100g, 63);
    expect(p.servingG, 150);
    expect(p.packageG, 500);
  });

  test('is made from a manual entry only when the amount is in grams or ml', () {
    FoodLogEntry entry({String? unit, double quantity = 1}) => FoodLogEntry(
          id: 'e1',
          userId: 'u1',
          loggedDate: DateTime(2026, 11, 7),
          mealType: MealType.lunch,
          foodName: 'Käsebrötchen',
          calories: 350,
          proteinG: 14,
          quantity: quantity,
          unit: unit,
          createdAt: DateTime.utc(2026, 11, 7),
        );
    final food = UserFood.fromEntry(entry(unit: 'g', quantity: 140), id: 'n1');
    expect(food!.kcal100, 250);
    expect(food.protein100, 10);
    expect(food.servingG, 140);
    expect(UserFood.fromEntry(entry(unit: 'Stück'), id: 'n2'), isNull);
  });

  test('Open Food Facts numbers as strings no longer break parsing', () {
    final p = FoodProduct.fromOpenFoodFacts({
      'code': '123',
      'product_name': '',
      'nutriments': {'energy-kcal_100g': '63', 'proteins_100g': 11, 'fat_100g': 'n/a'},
      'serving_quantity': '150',
      'product_quantity': 500,
    });
    expect(p.caloriesPer100g, 63);
    expect(p.proteinPer100g, 11);
    expect(p.fatPer100g, isNull);
    expect(p.hasName, isFalse);
    expect(p.servingG, 150);
    expect(p.packageG, 500);
    expect(p.caloriesFor(100), 63);
  });

  test('a product without nutrition has no kcal instead of 0', () {
    const p = FoodProduct(barcode: '1', name: 'X');
    expect(p.hasNutrition, isFalse);
    expect(p.caloriesForOrNull(100), isNull);
  });
}
