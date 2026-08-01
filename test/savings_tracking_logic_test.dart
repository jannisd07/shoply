import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

ShoppingHistory _trip(DateTime completedAt, List<ShoppingHistoryItem> items) {
  return ShoppingHistory(
    id: 't-${completedAt.toIso8601String()}',
    userId: 'u',
    listName: 'Liste',
    totalItems: items.length,
    completedAt: completedAt,
    items: items,
  );
}

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

  group('totalSavingsOf (ShoppingHistoryScreen lifetime + monthly figure)', () {
    test('zero across trips with no offer-priced items', () {
      final trips = [
        _trip(DateTime(2026, 1, 1), [_historyItem(price: 2.5, priceOldValue: null)]),
        _trip(DateTime(2026, 1, 2), [_historyItem(price: null, priceOldValue: null)]),
      ];
      expect(totalSavingsOf(trips), 0.0);
    });

    test('sums per-unit savings scaled by quantity, ignoring non-savings items', () {
      final trips = [
        _trip(DateTime(2026, 1, 1), [
          _historyItem(price: 0.99, priceOldValue: 1.49, quantity: 2), // 1.00
          _historyItem(price: 2.00, priceOldValue: null), // ignored
        ]),
        _trip(DateTime(2026, 1, 15), [
          _historyItem(price: 3.00, priceOldValue: 3.00, quantity: 5), // 0 (not a real saving)
          _historyItem(price: 1.20, priceOldValue: 1.80, quantity: 3), // 1.80
        ]),
      ];
      expect(totalSavingsOf(trips), closeTo(2.80, 0.001));
    });

    test('empty trip list is zero, not an error', () {
      expect(totalSavingsOf(const []), 0.0);
    });
  });

  group('tripsInMonth (drives the "this month vs. last month" breakdown)', () {
    final trips = [
      _trip(DateTime(2026, 6, 30), [_historyItem(price: 1.0, priceOldValue: 1.5)]), // June: 0.5
      _trip(DateTime(2026, 7, 1), [_historyItem(price: 2.0, priceOldValue: 3.0)]), // July: 1.0
      _trip(DateTime(2026, 7, 20), [_historyItem(price: 1.0, priceOldValue: 1.2)]), // July: 0.2
      _trip(DateTime(2025, 7, 5), [_historyItem(price: 1.0, priceOldValue: 5.0)]), // wrong year, excluded
    ];

    test('filters to the given year/month only', () {
      final july2026 = tripsInMonth(trips, year: 2026, month: 7);
      expect(july2026.length, 2);
      expect(totalSavingsOf(july2026), closeTo(1.2, 0.001));
    });

    test('DateTime(year, month - 1) correctly rolls January back to prior December', () {
      final januaryTrips = [
        _trip(DateTime(2026, 1, 10), [_historyItem(price: 1.0, priceOldValue: 2.0)]),
      ];
      final all = [...trips, ...januaryTrips];
      final prevMonth = DateTime(2026, 1 - 1); // should become 2025-12
      expect(prevMonth.year, 2025);
      expect(prevMonth.month, 12);
      // No December 2025 trips in this fixture, so the "previous month" total
      // is honestly zero rather than accidentally matching some other month.
      expect(
        totalSavingsOf(tripsInMonth(all, year: prevMonth.year, month: prevMonth.month)),
        0.0,
      );
    });

    test('excludes trips from the same month in a different year', () {
      final july2026 = tripsInMonth(trips, year: 2026, month: 7);
      expect(july2026.any((t) => t.completedAt.year == 2025), isFalse);
    });
  });
}
