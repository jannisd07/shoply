import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

ShoppingItemModel _item({double? price, double? priceOldValue, double quantity = 1.0}) {
  final now = DateTime(2026, 1, 1);
  return ShoppingItemModel(
    id: 'i',
    listId: 'l',
    name: 'Milch',
    quantity: quantity,
    createdAt: now,
    updatedAt: now,
    price: price,
    priceOldValue: priceOldValue,
  );
}

ShoppingHistoryItem _historyItem({
  double? price,
  double? priceOldValue,
  double quantity = 1.0,
}) {
  return ShoppingHistoryItem(
    id: 'i',
    historyId: 'h',
    name: 'Milch',
    quantity: quantity,
    price: price,
    priceOldValue: priceOldValue,
  );
}

void main() {
  group('ShoppingItemModel.savingsPerUnit', () {
    test('null when no price', () {
      expect(_item(price: null, priceOldValue: 1.99).savingsPerUnit, isNull);
    });

    test('null when no old price (manual/unpriced item)', () {
      expect(_item(price: 0.99, priceOldValue: null).savingsPerUnit, isNull);
    });

    test('null when old price is not actually higher', () {
      expect(_item(price: 0.99, priceOldValue: 0.99).savingsPerUnit, isNull);
      expect(_item(price: 0.99, priceOldValue: 0.50).savingsPerUnit, isNull);
    });

    test('the delta when the old price is genuinely higher', () {
      expect(_item(price: 0.99, priceOldValue: 1.49).savingsPerUnit,
          closeTo(0.50, 0.001));
    });
  });

  group('ShoppingHistoryItem.savingsPerUnit', () {
    test('mirrors ShoppingItemModel semantics', () {
      expect(_historyItem(price: null, priceOldValue: 1.99).savingsPerUnit, isNull);
      expect(_historyItem(price: 0.99, priceOldValue: null).savingsPerUnit, isNull);
      expect(_historyItem(price: 0.99, priceOldValue: 0.90).savingsPerUnit, isNull);
      expect(_historyItem(price: 0.99, priceOldValue: 1.49).savingsPerUnit,
          closeTo(0.50, 0.001));
    });
  });

  group('Lifetime savings aggregation (ShoppingHistoryScreen logic)', () {
    double totalSavingsOf(List<List<ShoppingHistoryItem>> trips) {
      var total = 0.0;
      for (final items in trips) {
        for (final item in items) {
          final perUnit = item.savingsPerUnit;
          if (perUnit != null) total += perUnit * item.quantity;
        }
      }
      return total;
    }

    test('zero across trips with no offer-priced items', () {
      final trips = [
        [_historyItem(price: 2.5, priceOldValue: null)],
        [_historyItem(price: null, priceOldValue: null)],
      ];
      expect(totalSavingsOf(trips), 0.0);
    });

    test('sums per-unit savings scaled by quantity, ignoring non-savings items', () {
      final trips = [
        [
          _historyItem(price: 0.99, priceOldValue: 1.49, quantity: 2), // 1.00
          _historyItem(price: 2.00, priceOldValue: null), // ignored
        ],
        [
          _historyItem(price: 3.00, priceOldValue: 3.00, quantity: 5), // 0 (not a real saving)
          _historyItem(price: 1.20, priceOldValue: 1.80, quantity: 3), // 1.80
        ],
      ];
      expect(totalSavingsOf(trips), closeTo(2.80, 0.001));
    });
  });
}
