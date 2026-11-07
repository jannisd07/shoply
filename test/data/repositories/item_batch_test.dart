import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';

ShoppingItemModel _item(String id, String name, double q, {String? unit}) =>
    ShoppingItemModel(
      id: id,
      listId: 'l1',
      name: name,
      quantity: q,
      unit: unit,
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
    );

void main() {
  test('merges into an unchecked item with the same name and unit', () {
    final plan = AddItemsPlan.of(
      [_item('a', 'Milch', 1), _item('b', 'Mehl', 500, unit: 'g')],
      const [
        NewItem(name: 'milch', quantity: 2),
        NewItem(name: 'Mehl', quantity: 1, unit: 'kg'),
      ],
    );
    expect(plan.merges, {'a': 2});
    expect(plan.inserts.single.name, 'Mehl');
    expect(plan.inserts.single.unit, 'kg');
  });

  test('"pcs" and no unit are the same unit', () {
    final plan = AddItemsPlan.of(
      [_item('a', 'Eier', 6, unit: 'pcs')],
      const [NewItem(name: 'Eier', quantity: 4)],
    );
    expect(plan.merges, {'a': 4});
    expect(plan.inserts, isEmpty);
  });

  test('combines the same item named twice in one batch', () {
    final plan = AddItemsPlan.of(const [], const [
      NewItem(name: 'Zwiebeln', quantity: 2, category: 'fruits_vegetables'),
      NewItem(name: 'zwiebeln', quantity: 1),
      NewItem(name: 'Knoblauch'),
    ]);
    expect(plan.inserts.length, 2);
    final onions = plan.inserts.firstWhere((i) => i.name == 'Zwiebeln');
    expect(onions.quantity, 3);
    expect(onions.category, 'fruits_vegetables');
  });

  test('skips empty names and non-positive quantities', () {
    final plan = AddItemsPlan.of(const [], const [
      NewItem(name: '  '),
      NewItem(name: 'Salz', quantity: 0),
      NewItem(name: 'Pfeffer'),
    ]);
    expect(plan.inserts.map((i) => i.name), ['Pfeffer']);
  });
}
