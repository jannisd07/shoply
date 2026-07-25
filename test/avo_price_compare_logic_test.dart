import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';

StoreOffer _offer({
  required int id,
  required String product,
  required double price,
  required String retailer,
  bool broad = false,
}) {
  return StoreOffer(
    id: id,
    productName: product,
    brandName: null,
    description: product,
    price: price,
    oldPrice: null,
    unitShortName: null,
    retailerName: retailer,
    retailerUniqueName: retailer.toLowerCase(),
    categoryName: null,
    validFrom: null,
    validTo: null,
    isBroadMatch: broad,
  );
}

StoreBasketResult _store(
  String retailer,
  double total,
  List<BasketItemMatch> matches,
) {
  return StoreBasketResult(
    retailerName: retailer,
    retailerUniqueName: retailer.toLowerCase(),
    matches: matches,
    comparableTotal: total,
  );
}

void main() {
  group('AvoAssistantService.summarizeBasketComparison', () {
    test('picks the cheapest store and reports savings vs. the next-cheapest', () {
      final comparison = BasketComparison(
        zipCode: '10115',
        comparableItemCount: 2,
        stores: [
          _store('Rewe', 10.50, [
            BasketItemMatch(itemName: 'milk', offer: _offer(id: 1, product: 'Milch', price: 5.0, retailer: 'Rewe')),
            BasketItemMatch(itemName: 'bread', offer: _offer(id: 2, product: 'Brot', price: 5.5, retailer: 'Rewe')),
          ]),
          _store('Aldi', 8.00, [
            BasketItemMatch(itemName: 'milk', offer: _offer(id: 3, product: 'Milch', price: 3.5, retailer: 'Aldi')),
            BasketItemMatch(itemName: 'bread', offer: _offer(id: 4, product: 'Brot', price: 4.5, retailer: 'Aldi')),
          ]),
        ],
      );

      final result = AvoAssistantService.summarizeBasketComparison(comparison, 'Weekly groceries');

      expect(result['found'], true);
      expect(result['list_name'], 'Weekly groceries');
      expect(result['best_store'], 'Aldi');
      expect(result['savings_vs_next_cheapest'], 2.5);
      expect((result['stores'] as List).length, 2);
      expect((result['stores'] as List).first, {
        'store': 'Aldi',
        'total': 8.0,
        'matched_items': 2,
      });
      expect(result.containsKey('note'), false);
    });

    test('excludes stores with zero matched items from the ranking', () {
      final comparison = BasketComparison(
        zipCode: '10115',
        comparableItemCount: 1,
        stores: [
          _store('Aldi', 3.5, [
            BasketItemMatch(itemName: 'milk', offer: _offer(id: 1, product: 'Milch', price: 3.5, retailer: 'Aldi')),
          ]),
          // Filled in from another store's offer for comparability, but has
          // zero offers of its own — must not be recommended as "best".
          _store('Lidl', 3.5, [
            const BasketItemMatch(itemName: 'milk', offer: null),
          ]),
        ],
      );

      final result = AvoAssistantService.summarizeBasketComparison(comparison, 'my list');

      expect(result['best_store'], 'Aldi');
      expect((result['stores'] as List).length, 1);
      expect(result.containsKey('savings_vs_next_cheapest'), false);
    });

    test('caps the store list at 3 even with more matched stores', () {
      final comparison = BasketComparison(
        zipCode: '10115',
        comparableItemCount: 1,
        stores: [
          for (final r in ['Aldi', 'Lidl', 'Rewe', 'Edeka', 'Penny'])
            _store(r, 5.0, [
              BasketItemMatch(itemName: 'milk', offer: _offer(id: r.hashCode, product: 'Milch', price: 5.0, retailer: r)),
            ]),
        ],
      );

      final result = AvoAssistantService.summarizeBasketComparison(comparison, 'my list');

      expect((result['stores'] as List).length, 3);
    });

    test('omits savings when the cheapest two stores are effectively tied', () {
      final comparison = BasketComparison(
        zipCode: '10115',
        comparableItemCount: 1,
        stores: [
          _store('Aldi', 5.0, [
            BasketItemMatch(itemName: 'milk', offer: _offer(id: 1, product: 'Milch', price: 5.0, retailer: 'Aldi')),
          ]),
          _store('Lidl', 5.0, [
            BasketItemMatch(itemName: 'milk', offer: _offer(id: 2, product: 'Milch', price: 5.0, retailer: 'Lidl')),
          ]),
        ],
      );

      final result = AvoAssistantService.summarizeBasketComparison(comparison, 'my list');

      expect(result.containsKey('savings_vs_next_cheapest'), false);
    });

    test('flags broad-match-only coverage as a confidence note', () {
      final comparison = BasketComparison(
        zipCode: '10115',
        comparableItemCount: 1,
        stores: [
          _store('Aldi', 5.0, [
            BasketItemMatch(
              itemName: 'toast',
              offer: _offer(id: 1, product: 'Toastbrot', price: 5.0, retailer: 'Aldi', broad: true),
            ),
          ]),
        ],
      );

      final result = AvoAssistantService.summarizeBasketComparison(comparison, 'my list');

      expect(result['note'], contains('similar-product match'));
    });
  });
}
