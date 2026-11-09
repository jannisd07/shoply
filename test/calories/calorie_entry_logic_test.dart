// The logic behind logging food (B6 W3b): the product cache and "Zuletzt
// gescannt", the barcode lookup order (own food, this device, Open Food
// Facts), amounts per 100 g or per portion, the goal form's checks and the
// allergy match of a photo estimate.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/nutrition_goal.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/goal_form.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import '../screens/calories/calorie_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('product cache and lookup', () {
    Future<ProviderContainer> container({
      Map<String, FoodProduct> off = const {},
      List<UserFood> own = const [],
      bool offline = false,
      Map<String, Object> prefs = const {},
    }) async {
      final env = await CalorieTestEnv.create(extraPrefs: prefs);
      final c = ProviderContainer(overrides: env.overrides(offProducts: off, userFoods: own, offline: offline));
      addTearDown(c.dispose);
      await c.read(calorieSharedPreferencesProvider.future);
      return c;
    }

    test('a found product is kept and listed first in "Zuletzt gescannt" (at most 5)', () async {
      final c = await container(off: {
        for (var i = 0; i < 7; i++) '400000000000$i': offProduct('400000000000$i', 'Produkt $i'),
      });
      for (var i = 0; i < 7; i++) {
        await c.read(calorieBarcodeLookupProvider)('400000000000$i');
      }
      final state = c.read(calorieProductCacheProvider);
      expect(state.recentScans.map((p) => p.name), ['Produkt 6', 'Produkt 5', 'Produkt 4', 'Produkt 3', 'Produkt 2']);
      expect(state.products, hasLength(7));
    });

    test('stored products come back after a restart, offline too', () async {
      final stored = jsonEncode({
        'products': [offProduct('4000000000099', 'Skyr').toCacheJson()],
        'scanned': ['4000000000099'],
      });
      final c = await container(offline: true, prefs: {'cal_products_v1_$kUser': stored});
      expect(c.read(calorieProductCacheProvider).recentScans.single.name, 'Skyr');
      expect((await c.read(calorieBarcodeLookupProvider)('4000000000099'))!.name, 'Skyr');
    });

    test('own foods win over Open Food Facts; offline and unknown throws "offline"', () async {
      final c = await container(
        off: {'4000000000099': offProduct('4000000000099', 'OFF-Skyr')},
        own: [UserFood(id: 'o1', userId: kUser, name: 'Mein Skyr', barcode: '4000000000099', kcal100: 70, createdAt: DateTime(2026))],
      );
      await Future<void>.delayed(Duration.zero);
      expect((await c.read(calorieBarcodeLookupProvider)('4000000000099'))!.name, 'Mein Skyr');

      final off = await container(offline: true);
      await expectLater(
        off.read(calorieBarcodeLookupProvider)('4000000000099'),
        throwsA(isA<OffRequestFailed>().having((e) => e.reason, 'reason', 'offline')),
      );
    });

    test('unknown or nameless products are "not found"', () async {
      final c = await container(off: {
        '4000000000099': const FoodProduct(barcode: '4000000000099', name: '', hasName: false),
      });
      expect(await c.read(calorieBarcodeLookupProvider)('4000000000099'), isNull);
      expect(await c.read(calorieBarcodeLookupProvider)('4000000000082'), isNull);
    });
  });

  group('CalorieAmountFood', () {
    test('per 100 g: grams, servings and packs', () {
      final f = CalorieAmountFood.fromProduct(
        offProduct('4000000000099', 'Skyr', kcal: 63, protein: 11, servingG: 150, packageG: 500),
        origin: FoodEntryOrigin.search,
      );
      expect(f.units, [CalorieAmountUnit.base, CalorieAmountUnit.serving, CalorieAmountUnit.pack]);
      expect(f.start.unit, CalorieAmountUnit.serving);
      expect(f.nutritionFor(250, CalorieAmountUnit.base).kcal, 158);
      expect(f.nutritionFor(1, CalorieAmountUnit.pack).kcal, 315);
      final entry = f.entryFor(
        amount: 2,
        unit: CalorieAmountUnit.serving,
        dateKey: kToday,
        meal: MealType.lunch,
        now: kNow,
      );
      expect(entry.quantity, 300);
      expect(entry.unit, 'g');
      expect(entry.origin, FoodEntryOrigin.search);
    });

    test('typed-in values per 100 g replace missing ones', () {
      final f = CalorieAmountFood.fromProduct(offProduct('4000000000099', 'X', kcal: null), origin: FoodEntryOrigin.barcode);
      expect(f.hasNutrition, isFalse);
      expect(f.nutritionFor(200, CalorieAmountUnit.base, per100: (kcal: 50, protein: 3.0, carbs: null, fat: null)).kcal, 100);
    });

    test('an earlier entry in g becomes per 100 g; in servings per portion', () {
      final grams = CalorieAmountFood.fromEntry(food('a', 'Hafer', 220, quantity: 60, unit: 'g'));
      expect(grams.kcal100, 367);
      expect(grams.start.amount, 60);
      final portion = CalorieAmountFood.fromEntry(food('b', 'Pizza', 800, quantity: 1, unit: 'serving'));
      expect(portion.perPortion, isTrue);
      expect(portion.nutritionFor(0.5, CalorieAmountUnit.portion).kcal, 400);
    });
  });

  group('GoalDraft', () {
    const base = GoalDraft(age: '34', height: '168', weight: '74', goal: NutritionGoalType.loseWeight, target: '70');

    test('complete inputs give a result and allow "Übernehmen"', () {
      expect(base.result, isNotNull);
      expect(base.canApply, isTrue);
    });

    test('"1,68" is metres; ranges and invalid numbers are named', () {
      final m = base.copyWith(height: '1,68');
      expect(m.heightCm, 168);
      expect(m.heightConverted, isTrue);
      expect(base.copyWith(height: '90').heightError, 'cal_height_range');
      expect(base.copyWith(weight: '20').weightError, 'cal_weight_range');
      expect(base.copyWith(age: '9').ageError, 'cal_age_range');
      expect(base.copyWith(age: '3,4,5').ageError, 'cal_number_invalid');
      expect(base.copyWith(age: '').result, isNull);
    });

    test('losing with a target above the weight, or under 18, cannot be applied', () {
      expect(base.copyWith(target: '80').canApply, isFalse);
      expect(base.copyWith(age: '16').canApply, isFalse);
      expect(base.copyWith(age: '16', goal: NutritionGoalType.maintain).canApply, isTrue);
    });

    test('the pace changes the target; maintain has no target weight', () {
      final slow = base.copyWith(pace: GoalPace.gemuetlich).result!.dailyCalorieTarget;
      final fast = base.copyWith(pace: GoalPace.zuegig).result!.dailyCalorieTarget;
      expect(slow, greaterThan(fast));
      expect(base.copyWith(goal: NutritionGoalType.maintain).targetKg, isNull);
    });
  });

  group('allergies on a photo estimate', () {
    test('a part with a keyword and a type the server named; each once', () {
      const matcher = AllergenMatcher(['peanuts', 'Gluten', 'Kiwi']);
      final found = estimateAllergyMatches(
        matcher,
        dish: 'Bowl',
        components: ['Reis', 'Erdnusssoße'],
        named: [AllergyType.peanuts, AllergyType.gluten],
      );
      expect(found.map((m) => m.type), [AllergyType.peanuts, AllergyType.gluten]);
    });

    test('nothing stored: nothing found', () {
      expect(
        estimateAllergyMatches(const AllergenMatcher([]), dish: 'Brot', components: ['Weizen'], named: [AllergyType.gluten]),
        isEmpty,
      );
    });
  });
}
