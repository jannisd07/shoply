import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_adaptation.dart';

Recipe _recipe(List<Ingredient> ingredients, {List<String> steps = const []}) =>
    Recipe(
      id: 'r1',
      name: 'Test',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 25,
      defaultServings: 2,
      ingredients: ingredients,
      instructions: steps,
      authorId: 'a1',
      authorName: 'Mara Köhler',
      createdAt: DateTime(2026, 1, 1),
    );

Ingredient _i(String name, [double amount = 1, String unit = '']) =>
    Ingredient(name: name, amount: amount, unit: unit);

void main() {
  group('allergens (Konzept 13 §2.3)', () {
    test('Reis, Weizen and Eis are not eggs; Eigelb is', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('Reis'), _i('Weizen'), _i('Eis'), _i('Eigelb')]),
        RecipeDietProfile.of(allergies: ['eggs']),
      );
      expect(
        [for (final i in a.ingredients) i.allergens.isNotEmpty],
        [false, false, false, true],
      );
    });

    test('Kokosmilch and Hafermilch are no milk, Vollmilch is', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('Kokosmilch'), _i('Hafermilch'), _i('Vollmilch')]),
        RecipeDietProfile.of(allergies: ['milk']),
      );
      expect(
        [for (final i in a.ingredients) i.allergens.isNotEmpty],
        [false, false, true],
      );
    });

    test('Feta is milk; lactose-free Hirtenkäse is fine with lactose only', () {
      final lactose = RecipeAdaptation.of(
        _recipe([_i('Feta'), _i('laktosefreier Hirtenkäse')]),
        RecipeDietProfile.of(allergies: ['lactose']),
      );
      final milk = RecipeAdaptation.of(
        _recipe([_i('laktosefreier Hirtenkäse')]),
        RecipeDietProfile.of(allergies: ['milk']),
      );
      expect(
        [for (final i in lactose.ingredients) i.allergens.isNotEmpty],
        [true, false],
      );
      expect(milk.ingredients.single.allergens, isNotEmpty);
      expect(breaksRecipeDiet('Feta', RecipeDiet.vegan), isTrue);
    });

    test('Erdnussbutter is peanut, not milk', () {
      final milk = RecipeAdaptation.of(
        _recipe([_i('Erdnussbutter')]),
        RecipeDietProfile.of(allergies: ['milk']),
      );
      final peanut = RecipeAdaptation.of(
        _recipe([_i('Erdnussbutter')]),
        RecipeDietProfile.of(allergies: ['peanuts']),
      );
      expect(milk.ingredients.single.allergens, isEmpty);
      expect(peanut.ingredients.single.allergens, isNotEmpty);
    });

    test('English recipes warn too', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('whole milk'), _i('2 eggs'), _i('peanuts')]),
        RecipeDietProfile.of(allergies: ['milk', 'eggs', 'peanuts']),
      );
      expect(a.ingredients.every((i) => i.allergens.isNotEmpty), isTrue);
    });

    test('a substitute never brings an allergen of its own', () {
      // Vegetarian with a soy and a gluten allergy: Tofu, Tempeh (soy) and
      // Seitan (gluten) are all out, so the chicken is not replaced.
      final a = RecipeAdaptation.of(
        _recipe([_i('Hähnchen', 300, 'g')]),
        RecipeDietProfile.of(
          allergies: ['soy', 'gluten'],
          diets: ['vegetarian'],
        ),
      );
      final chicken = a.ingredients.single;
      expect(chicken.substitute, isNull);
      expect(chicken.breaksDietOnly, isTrue);
    });

    test('Käse is not replaced by Hefeflocken with a yeast allergy', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('Käse', 100, 'g')]),
        RecipeDietProfile.of(allergies: ['milk', 'yeast']),
      );
      expect(a.ingredients.single.substitute?.name, 'Veganer Käse');
    });

    test('milk with lactose intolerance gets a plant milk, same amount', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('Milch', 250, 'ml')]),
        RecipeDietProfile.of(allergies: ['lactose']),
      );
      final milk = a.ingredients.single;
      expect(milk.substitute?.name, 'Hafermilch');
      expect(milk.substitute?.amount, 250);
      expect(milk.isUnsafe, isFalse);
      expect(a.hasSubstitutes, isTrue);
    });

    test('an allergen without a known substitute stays and is unsafe', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('geröstete Erdnüsse', 50, 'g')]),
        RecipeDietProfile.of(allergies: ['peanuts']),
      );
      expect(a.ingredients.single.isUnsafe, isTrue);
      expect(a.hasAllergen, isTrue);
    });

    test('dairy_free from the diet list counts as a milk allergy', () {
      final p = RecipeDietProfile.of(diets: ['dairy_free']);
      expect(p.allergies.single.fromDiet, 'dairy_free');
      final a = RecipeAdaptation.of(_recipe([_i('Sahne')]), p);
      expect(a.ingredients.single.allergens, isNotEmpty);
    });

    test('Pesto is named as not checked, only with allergies', () {
      final withAllergy = RecipeAdaptation.of(
        _recipe([_i('Pesto'), _i('Gemüsebrühe'), _i('Zucchini')]),
        RecipeDietProfile.of(allergies: ['nuts']),
      );
      final dietOnly = RecipeAdaptation.of(
        _recipe([_i('Pesto')]),
        RecipeDietProfile.of(diets: ['vegan']),
      );
      expect(
        [for (final i in withAllergy.unchecked) i.original.name],
        ['Pesto', 'Gemüsebrühe'],
      );
      expect(dietOnly.unchecked, isEmpty);
    });

    test('no profile: nothing is flagged', () {
      final a = RecipeAdaptation.of(
        _recipe([_i('Feta')]),
        const RecipeDietProfile(),
      );
      expect(a.hasNotice, isFalse);
    });
  });

  group('diets', () {
    test('Champignons are no ham, Fleischtomaten no meat', () {
      expect(breaksRecipeDiet('Champignons', RecipeDiet.vegetarian), isFalse);
      expect(breaksRecipeDiet('Fleischtomaten', RecipeDiet.vegan), isFalse);
      expect(breaksRecipeDiet('Speck', RecipeDiet.vegetarian), isTrue);
      expect(
        breaksRecipeDiet('Rinderhackfleisch', RecipeDiet.pescatarian),
        isTrue,
      );
    });

    test('fish is fine for pescetarians, not for vegetarians', () {
      expect(breaksRecipeDiet('Lachs', RecipeDiet.pescatarian), isFalse);
      expect(breaksRecipeDiet('Lachs', RecipeDiet.vegetarian), isTrue);
    });

    test('vegans avoid milk, eggs and honey', () {
      expect(breaksRecipeDiet('Butter', RecipeDiet.vegan), isTrue);
      expect(breaksRecipeDiet('Eier', RecipeDiet.vegan), isTrue);
      expect(breaksRecipeDiet('Honig', RecipeDiet.vegan), isTrue);
      expect(breaksRecipeDiet('Butter', RecipeDiet.vegetarian), isFalse);
      expect(breaksRecipeDiet('Hafermilch', RecipeDiet.vegan), isFalse);
    });

    test('shown diet: the label only while no ingredient breaks it', () {
      Recipe labelled(List<String> labels, List<String> names) =>
          _recipe([for (final n in names) _i(n)]).copyWith(labels: labels);
      expect(
        recipeShownDiet(labelled(['vegan'], ['Eigelb', 'Senf', 'Dill'])),
        RecipeDiet.vegetarian,
        reason: 'egg yolk: never vegan, still vegetarian',
      );
      expect(
        recipeShownDiet(labelled(['Vegan'], ['Hafermilch', 'Mehl'])),
        RecipeDiet.vegan,
      );
      expect(recipeShownDiet(labelled(['vegetarian'], ['Speck'])), isNull);
      expect(
        recipeShownDiet(labelled(['non-vegan'], ['Mehl'])),
        isNull,
        reason: 'exact labels only',
      );
      expect(recipeShownDiet(labelled([], ['Mehl'])), isNull);
    });

    test('steps name the substitute instead of the original', () {
      final recipe = _recipe(
        [_i('Speck', 100, 'g'), _i('Zwiebel')],
        steps: ['Speck würfeln.', 'Zwiebel dazugeben.'],
      );
      final a = RecipeAdaptation.of(
        recipe,
        RecipeDietProfile.of(diets: ['vegetarian']),
      );
      expect(a.adaptedSteps.first, 'Veganer Speck würfeln.');
      expect(a.stepSubstitutions.first.single.original.name, 'Speck');
      expect(a.stepSubstitutions.last, isEmpty);
      final cooked = a.applyTo(recipe, adapted: true);
      expect(cooked.ingredients.first.name, 'Veganer Speck');
      expect(cooked.instructions.first, 'Veganer Speck würfeln.');
      expect(a.applyTo(recipe, adapted: false), same(recipe));
    });
  });

  group('amounts (Konzept 13 §2.2)', () {
    test('grams round to 5, below 20 to 1', () {
      expect(scaleIngredient(_i('Mehl', 200, 'g'), 3, 2).amount, 135);
      expect(scaleIngredient(_i('Hefe', 7, 'g'), 2, 3).amount, 11);
    });

    test('eggs round up, pieces to halves, pinches stay', () {
      expect(scaleIngredient(_i('Eier', 3), 2, 3).amount, 5);
      expect(scaleIngredient(_i('Zucchini', 1), 2, 3).amount, 1.5);
      expect(scaleIngredient(_i('Salz', 1, 'Prise'), 2, 6).amount, 1);
    });

    test('spoons use fractions', () {
      final half = scaleIngredient(_i('Oregano', 1, 'TL'), 2, 1);
      expect(formatRecipeAmount(half, 'de'), '½ TL');
      expect(formatRecipeAmount(_i('Öl', 1.5, 'EL'), 'de'), '1½ EL');
    });

    test('formatting in the app language', () {
      expect(formatRecipeAmount(_i('Kartoffeln', 500, 'g'), 'de'), '500 g');
      expect(formatRecipeAmount(_i('Milch', 1.5, 'l'), 'de'), '1,5 L');
      expect(formatRecipeAmount(_i('Milch', 1.5, 'l'), 'en'), '1.5 L');
      expect(formatRecipeAmount(_i('Zucchini', 1), 'de'), '1');
      expect(formatRecipeAmount(_i('Salz', 0), 'de'), '');
      expect(formatRecipeAmount(_i('Thymian', 2, 'Zweige'), 'de'), '2 Zweige');
    });

    test('list items: no amount becomes one, pieces lose the unit', () {
      final salt = recipeIngredientToItem(_i('Salz', 0));
      expect(salt.quantity, 1);
      expect(salt.unit, isNull);
      expect(recipeIngredientToItem(_i('Zwiebel', 2, 'Stück')).unit, isNull);
      expect(recipeIngredientToItem(_i('Mehl', 200, 'Gramm')).unit, 'g');
      expect(recipeIngredientToItem(_i('Öl', 3, 'EL')).unit, 'EL');
    });

    test('the same ingredient twice is summed', () {
      final merged = mergeIngredients([
        _i('Olivenöl', 2, 'EL'),
        _i('Zwiebel', 1),
        _i('Olivenöl', 1, 'EL'),
      ]);
      expect(merged.length, 2);
      expect(merged.first.amount, 3);
    });
  });

  test('staples and names already on the list', () {
    expect(isStapleIngredient('Salz'), isTrue);
    expect(isStapleIngredient('Pfeffer, frisch gemahlen'), isTrue);
    expect(isStapleIngredient('brauner Zucker'), isTrue);
    expect(isStapleIngredient('Wassermelone'), isFalse);
    expect(isStapleIngredient('Zuckerschoten'), isFalse);
    expect(sameShoppingName('Kartoffeln, festkochend', 'Kartoffeln'), isTrue);
    expect(sameShoppingName('Zwiebeln', 'Zwiebel'), isTrue);
    expect(sameShoppingName('Paprika', 'Paprikapulver'), isFalse);
  });
}
