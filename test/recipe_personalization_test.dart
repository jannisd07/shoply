import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/recipe_personalization.dart';

void main() {
  final referenceNow = DateTime(2026, 8, 3);

  Recipe recipe({
    List<String> labels = const [],
    List<Ingredient> ingredients = const [],
    double averageRating = 0.0,
    int ratingCount = 0,
    int viewCount = 0,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: 'r1',
      name: 'Test Recipe',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 10,
      defaultServings: 2,
      ingredients: ingredients,
      instructions: const [],
      authorId: 'a1',
      authorName: 'Author',
      createdAt: createdAt ?? referenceNow.subtract(const Duration(days: 90)),
      averageRating: averageRating,
      ratingCount: ratingCount,
      viewCount: viewCount,
      labels: labels,
    );
  }

  group('scoreForYouRecipe', () {
    test('matching diet preference adds points', () {
      final r = recipe(labels: ['vegetarian']);
      final withPref = scoreForYouRecipe(
        r,
        dietPreferences: const ['vegetarian'],
        allergies: const [],
        now: referenceNow,
      );
      final withoutPref = scoreForYouRecipe(
        r,
        dietPreferences: const [],
        allergies: const [],
        now: referenceNow,
      );
      expect(withPref - withoutPref, closeTo(2.0, 0.0001));
    });

    test('matching allergen heavily penalizes the score', () {
      final r = recipe(ingredients: const [
        Ingredient(name: 'Peanuts', amount: 1, unit: 'cup'),
      ]);
      final score = scoreForYouRecipe(
        r,
        dietPreferences: const [],
        allergies: const ['peanuts'],
        now: referenceNow,
      );
      expect(score, lessThan(0));
    });

    test('eat_healthier boosts a healthy-labeled recipe only', () {
      final healthy = recipe(labels: ['healthy']);
      final other = recipe(labels: ['comfort-food']);

      final healthyBoost = scoreForYouRecipe(
            healthy,
            dietPreferences: const [],
            allergies: const [],
            appPriorities: const {'eat_healthier'},
            now: referenceNow,
          ) -
          scoreForYouRecipe(
            healthy,
            dietPreferences: const [],
            allergies: const [],
            now: referenceNow,
          );
      final otherBoost = scoreForYouRecipe(
            other,
            dietPreferences: const [],
            allergies: const [],
            appPriorities: const {'eat_healthier'},
            now: referenceNow,
          ) -
          scoreForYouRecipe(
            other,
            dietPreferences: const [],
            allergies: const [],
            now: referenceNow,
          );

      expect(healthyBoost, closeTo(1.5, 0.0001));
      expect(otherBoost, 0.0);
    });

    test('discover_recipes doubles the freshness bonus for a recent recipe', () {
      final fresh = recipe(createdAt: referenceNow.subtract(const Duration(days: 3)));

      final baseline = scoreForYouRecipe(
        fresh,
        dietPreferences: const [],
        allergies: const [],
        now: referenceNow,
      );
      final withDiscover = scoreForYouRecipe(
        fresh,
        dietPreferences: const [],
        allergies: const [],
        appPriorities: const {'discover_recipes'},
        now: referenceNow,
      );

      expect(withDiscover - baseline, closeTo(1.0, 0.0001));
    });

    test('discover_recipes has no effect on an old recipe', () {
      final old = recipe(createdAt: referenceNow.subtract(const Duration(days: 120)));

      final baseline = scoreForYouRecipe(
        old,
        dietPreferences: const [],
        allergies: const [],
        now: referenceNow,
      );
      final withDiscover = scoreForYouRecipe(
        old,
        dietPreferences: const [],
        allergies: const [],
        appPriorities: const {'discover_recipes'},
        now: referenceNow,
      );

      expect(withDiscover, baseline);
    });

    test('unmapped priorities (save_money, share_lists, stay_organized) '
        'never change the score', () {
      final r = recipe(labels: ['healthy'], createdAt: referenceNow.subtract(const Duration(days: 3)));
      final baseline = scoreForYouRecipe(
        r,
        dietPreferences: const [],
        allergies: const [],
        now: referenceNow,
      );
      final withUnmapped = scoreForYouRecipe(
        r,
        dietPreferences: const [],
        allergies: const [],
        appPriorities: const {'save_money', 'share_lists', 'stay_organized'},
        now: referenceNow,
      );
      expect(withUnmapped, baseline);
    });

    test('no priorities and no preferences reproduces the original '
        'rating/view/freshness-only score', () {
      final r = recipe(
        averageRating: 4.0,
        ratingCount: 10,
        viewCount: 50,
        createdAt: referenceNow.subtract(const Duration(days: 5)),
      );
      final score = scoreForYouRecipe(
        r,
        dietPreferences: const [],
        allergies: const [],
        now: referenceNow,
      );
      // 4.0*0.5 + 50*0.01 + min(10*0.2, 2) + 1.0 (fresh, <=7 days)
      expect(score, closeTo(2.0 + 0.5 + 2.0 + 1.0, 0.0001));
    });
  });
}
