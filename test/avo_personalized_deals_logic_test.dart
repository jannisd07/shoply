import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';

RecipeIngredientOffer _match({
  required String item,
  required double price,
  double? regularPrice,
  bool broad = false,
}) {
  return RecipeIngredientOffer(
    ingredientName: item,
    offerId: item.hashCode,
    productName: item,
    retailerName: 'Aldi',
    price: price,
    regularPrice: regularPrice,
    isBroadMatch: broad,
  );
}

void main() {
  group('AvoAssistantService.summarizePersonalizedDeals', () {
    test('reports found=0 with a note when there are no matches', () {
      final result = AvoAssistantService.summarizePersonalizedDeals(const []);

      expect(result['found'], 0);
      expect(result.containsKey('deals'), false);
      expect(result['note'], isA<String>());
    });

    test('shapes matches into a deal list, including discount when available', () {
      final matches = [
        _match(item: 'milk', price: 0.89, regularPrice: 1.19),
        _match(item: 'bread', price: 1.5),
      ];

      final result = AvoAssistantService.summarizePersonalizedDeals(matches);

      expect(result['found'], 2);
      final deals = result['deals'] as List;
      expect(deals.length, 2);
      expect(deals[0], {
        'item': 'milk',
        'product': 'milk',
        'price': 0.89,
        'regular_price': 1.19,
        'discount_percent': 25,
        'store': 'Aldi',
      });
      expect(deals[1], {
        'item': 'bread',
        'product': 'bread',
        'price': 1.5,
        'store': 'Aldi',
      });
    });

    test('flags broad/similar-product matches', () {
      final result = AvoAssistantService.summarizePersonalizedDeals(
        [_match(item: 'flour', price: 0.99, broad: true)],
      );

      final deal = (result['deals'] as List).first as Map;
      expect(deal['similar_product'], true);
    });

    test('respects the limit parameter', () {
      final matches = List.generate(
        8,
        (i) => _match(item: 'item$i', price: 1.0),
      );

      final result = AvoAssistantService.summarizePersonalizedDeals(matches, limit: 3);

      expect(result['found'], 3);
      expect((result['deals'] as List).length, 3);
    });
  });
}
