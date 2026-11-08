import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_aisles.dart';

final _at = DateTime(2026, 11, 7, 10, 42);

ShoppingItemModel _item(
  String id, {
  String? category,
  int? order,
  double quantity = 1,
  String? unit,
  String? notes,
}) => ShoppingItemModel(
  id: id,
  listId: 'l1',
  name: id,
  categoryId: category,
  orderIndex: order,
  quantity: quantity,
  unit: unit,
  notes: notes,
  createdAt: _at,
  updatedAt: _at,
);

Future<String> _subtitle(
  WidgetTester tester,
  ShoppingItemModel item, {
  Locale locale = const Locale('de'),
}) async {
  late String out;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: Builder(
        builder: (context) {
          out = shoppingItemSubtitle(context, item);
          return const SizedBox();
        },
      ),
    ),
  );
  return out;
}

void main() {
  group('shoppingAisles', () {
    test('default walking order, empty categories left out', () {
      final aisles = shoppingAisles(
        [
          _item('Milch', category: 'dairy'),
          _item('Bananen', category: 'fruits_vegetables'),
          _item('Brot', category: 'bakery'),
        ],
        order: const ShoppingAisleOrder(),
        languageCode: 'de',
      );
      expect(aisles.map((a) => a.id), ['fruits_vegetables', 'bakery', 'dairy']);
      expect(aisles.first.name, 'Obst & Gemüse');
    });

    test('saved order first, then the rest in walking order', () {
      final aisles = shoppingAisles(
        [
          _item('Milch', category: 'dairy'),
          _item('Bananen', category: 'fruits_vegetables'),
          _item('Wasser', category: 'beverages'),
        ],
        order: const ShoppingAisleOrder(categoryOrder: ['beverages', 'dairy']),
        languageCode: 'en',
      );
      expect(aisles.map((a) => a.id), [
        'beverages',
        'dairy',
        'fruits_vegetables',
      ]);
      expect(aisles.first.name, 'Beverages');
    });

    test('own categories by name; unknown ones fall back to "other"', () {
      const own = CustomCategory(
        id: 'custom_1',
        name: 'Grillzeug',
        color: Color(0xFF000000),
      );
      final aisles = shoppingAisles(
        [
          _item('Kohle', category: 'custom_1'),
          _item('Fremd', category: 'custom_unknown'),
          _item('Alt', category: 'Milchprodukte'),
          _item('Nichts'),
        ],
        order: const ShoppingAisleOrder(customCategories: [own]),
        languageCode: 'de',
      );
      expect(aisles.map((a) => a.id), ['custom_1', 'dairy', 'other']);
      expect(aisles.first.name, 'Grillzeug');
      expect(aisles.last.items.map((i) => i.id), ['Fremd', 'Nichts']);
    });

    test('items keep the list order inside an aisle', () {
      final aisles = shoppingAisles(
        [
          _item('c', category: 'dairy'),
          _item('b', category: 'dairy', order: 2),
          _item('a', category: 'dairy', order: 1),
          _item('d', category: 'dairy'),
        ],
        order: const ShoppingAisleOrder(),
        languageCode: 'de',
      );
      expect(aisles.single.items.map((i) => i.id), ['a', 'b', 'c', 'd']);
    });
  });

  group('shoppingItemSubtitle', () {
    testWidgets('unit, pieces, single piece, note', (tester) async {
      expect(
        await _subtitle(tester, _item('x', quantity: 500, unit: 'g')),
        '500 g',
      );
      expect(await _subtitle(tester, _item('x', quantity: 3)), '3 St.');
      expect(await _subtitle(tester, _item('x')), '');
      expect(
        await _subtitle(tester, _item('x', quantity: 6, notes: 'still')),
        '6 St. · still',
      );
      expect(
        await _subtitle(tester, _item('x', quantity: 1.5, unit: 'kg')),
        '1,5 kg',
      );
      expect(
        await _subtitle(
          tester,
          _item('x', quantity: 1.5, unit: 'kg'),
          locale: const Locale('en'),
        ),
        '1.5 kg',
      );
    });
  });
}
