import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';

StoreOffer offer({
  int id = 1,
  String productName = 'Product',
  String retailerName = 'REWE',
  double price = 1.0,
  double? oldPrice,
  bool isBroadMatch = false,
}) {
  final o = StoreOffer(
    id: id,
    productName: productName,
    brandName: null,
    description: '',
    price: price,
    oldPrice: oldPrice,
    unitShortName: 'kg',
    retailerName: retailerName,
    retailerUniqueName: retailerName.toLowerCase(),
    categoryName: null,
    validFrom: null,
    validTo: null,
  );
  return isBroadMatch ? o.asBroadMatch() : o;
}

void main() {
  group('eligibleIngredientNames', () {
    test('skips pantry staples and too-short names', () {
      final names = RecipeOfferService.eligibleIngredientNames([
        'Salz',
        'Pfeffer',
        'Wasser',
        'salz und pfeffer',
        'Öl', // 2 chars — skipped
        'Tomaten',
        'Mehl',
      ]);
      expect(names, ['Tomaten', 'Mehl']);
    });

    test('de-duplicates case-insensitively, keeping the first spelling', () {
      final names = RecipeOfferService.eligibleIngredientNames(
          ['Tomaten', 'tomaten', ' TOMATEN ', 'Zwiebeln']);
      expect(names, ['Tomaten', 'Zwiebeln']);
    });

    test('caps at maxCheckedIngredients, preserving order', () {
      final raw = List.generate(20, (i) => 'Zutat$i');
      final names = RecipeOfferService.eligibleIngredientNames(raw);
      expect(names.length, RecipeOfferService.maxCheckedIngredients);
      expect(names.first, 'Zutat0');
      expect(names.last, 'Zutat9');
    });
  });

  group('isRelevantMatch', () {
    test('matches when the product name contains the full term', () {
      expect(
        RecipeOfferService.isRelevantMatch(
            'Milch', offer(productName: 'Frische Vollmilch 3,5%')),
        isTrue,
      );
    });

    test('matches multi-word ingredients via the head noun', () {
      expect(
        RecipeOfferService.isRelevantMatch(
            'passierte Tomaten', offer(productName: 'Tomaten passiert 500g')),
        isTrue,
      );
    });

    test('rejects unrelated products', () {
      expect(
        RecipeOfferService.isRelevantMatch(
            'Hähnchenbrust', offer(productName: 'Schweineschnitzel')),
        isFalse,
      );
    });
  });

  group('pickBestOffer', () {
    test('picks the cheapest exact match over a cheaper broad match', () {
      // id 3 came from the broadened stem query and only matches the stem
      // ("toast"), not the full term — the pricier true match still wins.
      final best = RecipeOfferService.pickBestOffer('Toastbrötchen', [
        offer(id: 1, productName: 'Toastbrötchen 6er', price: 1.49),
        offer(id: 2, productName: 'Toastbrötchen XXL', price: 1.99),
        offer(
            id: 3,
            productName: 'Golden Toast',
            price: 0.99,
            isBroadMatch: true),
      ]);
      expect(best!.id, 1);
    });

    test('falls back to the cheapest broad match when no exact match exists',
        () {
      final best = RecipeOfferService.pickBestOffer('Toastbrötchen', [
        offer(id: 1, productName: 'Golden Toast', price: 1.99, isBroadMatch: true),
        offer(id: 2, productName: 'Butter Toast', price: 1.49, isBroadMatch: true),
        offer(id: 3, productName: 'Waschmittel', price: 0.50),
      ]);
      expect(best!.id, 2);
    });

    test('returns null when nothing relates to the ingredient', () {
      final best = RecipeOfferService.pickBestOffer('Kreuzkümmel', [
        offer(productName: 'Toaster', price: 19.99),
      ]);
      expect(best, isNull);
    });

    test('returns null for an empty offer list', () {
      expect(RecipeOfferService.pickBestOffer('Milch', const []), isNull);
    });
  });

  group('RecipeOffersResult', () {
    RecipeIngredientOffer match({
      String ingredient = 'Milch',
      double price = 0.89,
      double? regularPrice,
      bool isBroadMatch = false,
      DateTime? validTo,
    }) {
      return RecipeIngredientOffer(
        ingredientName: ingredient,
        offerId: 42,
        productName: 'Frische Vollmilch',
        retailerName: 'Aldi',
        price: price,
        regularPrice: regularPrice,
        validTo: validTo,
        isBroadMatch: isBroadMatch,
      );
    }

    test('knownSavings sums regular-price deltas of exact matches only', () {
      final result = RecipeOffersResult(
        recipeId: 'r1',
        zipCode: '10115',
        checkedIngredientCount: 4,
        matches: [
          match(price: 0.89, regularPrice: 1.19), // +0.30
          match(ingredient: 'Butter', price: 1.49, regularPrice: 2.29), // +0.80
          match(
              ingredient: 'Käse',
              price: 1.99,
              regularPrice: 2.99,
              isBroadMatch: true), // excluded: broad
          match(ingredient: 'Mehl', price: 0.49), // excluded: no regular price
        ],
        signature: 'sig',
      );
      expect(result.knownSavings, closeTo(1.10, 0.001));
    });

    test('JSON round-trip preserves all fields including nulls', () {
      final original = RecipeOffersResult(
        recipeId: 'r1',
        zipCode: '10115',
        checkedIngredientCount: 3,
        matches: [
          match(
            regularPrice: 1.19,
            validTo: DateTime.utc(2026, 7, 25),
            isBroadMatch: true,
          ),
          match(ingredient: 'Mehl'),
        ],
        signature: 'r1|10115|Milch,Mehl',
      );

      final restored = RecipeOffersResult.fromJson(original.toJson())!;
      expect(restored.recipeId, original.recipeId);
      expect(restored.zipCode, original.zipCode);
      expect(restored.checkedIngredientCount, original.checkedIngredientCount);
      expect(restored.signature, original.signature);
      expect(restored.matches.length, 2);
      expect(restored.matches[0].regularPrice, 1.19);
      expect(restored.matches[0].validTo, DateTime.utc(2026, 7, 25));
      expect(restored.matches[0].isBroadMatch, isTrue);
      expect(restored.matches[1].regularPrice, isNull);
      expect(restored.matches[1].validTo, isNull);
      expect(restored.matches[1].isBroadMatch, isFalse);
    });

    test('expired matches are detected via isStillValid', () {
      expect(
          match(validTo: DateTime.utc(2020, 1, 1)).isStillValid, isFalse);
      expect(match(validTo: DateTime.utc(2099, 1, 1)).isStillValid, isTrue);
      expect(match().isStillValid, isTrue);
    });

    test('discountPercent follows the ≥5% rule', () {
      expect(match(price: 0.89, regularPrice: 1.19).discountPercent, 25);
      expect(match(price: 0.99, regularPrice: 1.00).discountPercent, isNull);
      expect(match().discountPercent, isNull);
    });
  });
}
