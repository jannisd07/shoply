import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A tiny in-memory PostgREST: `shopping_items` rows with `col=eq.value`
/// filters, insert, update and `single()` answers. Every other table
/// (`shopping_lists`) answers with an empty success.
class _Postgrest {
  final Map<String, Map<String, dynamic>> items = {};
  final List<String> writes = [];
  var _nextId = 1;

  Future<http.Response> handle(http.Request request) async {
    final single =
        request.headers['Accept']?.contains('vnd.pgrst.object') ?? false;
    http.Response ok(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    if (!request.url.path.endsWith('/shopping_items')) {
      return ok(single ? <String, dynamic>{} : <dynamic>[]);
    }
    final filters = <String, String>{
      for (final e in request.url.queryParameters.entries)
        if (e.value.startsWith('eq.')) e.key: e.value.substring(3),
    };
    Iterable<Map<String, dynamic>> matching() => items.values.where(
      (row) => filters.entries.every((f) => '${row[f.key]}' == f.value),
    );
    http.Response rows(Iterable<Map<String, dynamic>> found) {
      final list = found.toList();
      if (!single) return ok(list);
      if (list.length != 1) {
        return ok({
          'code': 'PGRST116',
          'message': 'JSON object requested, multiple (or no) rows returned',
          'details':
              'Results contain ${list.length} rows, '
              'application/vnd.pgrst.object+json requires 1 row',
          'hint': null,
        }, 406);
      }
      return ok(list.single);
    }

    switch (request.method) {
      case 'GET':
        return rows(matching());
      case 'PATCH':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add('PATCH ${jsonEncode(body)}');
        final found = matching().toList();
        for (final row in found) {
          row.addAll(body);
        }
        return rows(found);
      case 'POST':
        final decoded = jsonDecode(request.body);
        final bodies = decoded is List
            ? decoded.cast<Map<String, dynamic>>()
            : [decoded as Map<String, dynamic>];
        final created = <Map<String, dynamic>>[];
        for (final body in bodies) {
          writes.add('POST ${jsonEncode(body)}');
          final row = <String, dynamic>{
            'id': 'new${_nextId++}',
            'is_checked': false,
            'created_at': '2026-11-09T08:00:00Z',
            'updated_at': '2026-11-09T08:00:00Z',
            ...body,
          };
          items[row['id'] as String] = row;
          created.add(row);
        }
        return rows(created);
    }
    return ok(<dynamic>[]);
  }
}

class _FakeSupabase implements SupabaseService {
  _FakeSupabase(this.client);

  @override
  final SupabaseClient client;

  @override
  User? get currentUser => User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-11-09T00:00:00Z',
  );

  @override
  PostgrestQueryBuilder from(String table) => client.from(table);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _row(
  String id,
  String name, {
  double quantity = 1,
  double? price,
  String? retailer,
  double? oldValue,
}) => {
  'id': id,
  'list_id': 'l1',
  'name': name,
  'quantity': quantity,
  'is_checked': false,
  'created_at': '2026-11-09T07:00:00Z',
  'updated_at': '2026-11-09T07:00:00Z',
  'price': price,
  'price_currency': price == null ? null : 'EUR',
  'price_retailer': retailer,
  'price_unit': null,
  'price_updated_at': price == null ? null : '2026-11-08T10:00:00Z',
  'price_old_value': oldValue,
};

void main() {
  late _Postgrest db;
  late ItemRepository repo;

  setUp(() {
    db = _Postgrest();
    final client = SupabaseClient(
      'http://localhost:54321',
      'anon',
      httpClient: MockClient(db.handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repo = ItemRepository(supabase: _FakeSupabase(client));
  });

  const offer = ItemPrice(
    price: 1.29,
    retailer: 'lidl',
    unit: '1 l',
    oldValue: 1.59,
  );

  group('ItemPrice', () {
    test('columns carry price, currency, retailer, unit, old value, date', () {
      final at = DateTime.utc(2026, 11, 9, 12);
      final columns = ItemPrice(
        price: 1.29,
        retailer: 'lidl',
        unit: '1 l',
        oldValue: 1.59,
        updatedAt: at,
      ).toColumns();
      expect(columns, {
        'price': 1.29,
        'price_currency': 'EUR',
        'price_retailer': 'lidl',
        'price_unit': '1 l',
        'price_updated_at': at.toIso8601String(),
        'price_old_value': 1.59,
      });
    });

    test('price_updated_at is written in UTC, also for a local date', () {
      final local = DateTime(2026, 11, 9, 12);
      final text =
          ItemPrice(price: 1, updatedAt: local).toColumns()['price_updated_at']
              as String;
      expect(text.endsWith('Z'), isTrue);
      expect(DateTime.parse(text).isAtSameMomentAs(local), isTrue);
      expect(
        (const ItemPrice(price: 1).toColumns()['price_updated_at'] as String)
            .endsWith('Z'),
        isTrue,
      );
    });

    test('a manual price has no retailer, unit or comparison price', () {
      final columns = const ItemPrice(price: 2).toColumns();
      expect(columns['price_retailer'], isNull);
      expect(columns['price_unit'], isNull);
      expect(columns['price_old_value'], isNull);
      expect(columns['price_updated_at'], isA<String>());
    });

    test('columnsOf mirrors an item without a price as all null', () {
      final item = ShoppingItemModel.fromJson(_row('a', 'Milch'));
      expect(ItemPrice.columnsOf(item).values, everyElement(isNull));
      expect(
        ItemPrice.columnsOf(item).keys,
        unorderedEquals(ItemPrice.clearedColumns.keys),
      );
    });
  });

  group('setItemPrice / clearItemPrice / undoPriceChange', () {
    test('sets the six price columns and returns the changed item', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      expect(result.item.price, 1.29);
      expect(result.item.priceCurrency, 'EUR');
      expect(result.item.priceRetailer, 'lidl');
      expect(result.item.priceUnit, '1 l');
      expect(result.item.priceOldValue, 1.59);
      expect(result.item.priceUpdatedAt, isNotNull);
      expect(db.items['a']!['price'], 1.29);
      expect(result.token, isNotEmpty);
    });

    test('undo of a first price removes it again', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      await repo.undoPriceChange(result.token);
      final row = db.items['a']!;
      for (final key in ItemPrice.clearedColumns.keys) {
        expect(row[key], isNull, reason: key);
      }
    });

    test('undo restores the price that was replaced', () async {
      db.items['a'] = _row(
        'a',
        'Milch',
        price: 1.89,
        retailer: 'rewe',
        oldValue: 2.19,
      );
      final result = await repo.setItemPrice('a', offer);
      expect(db.items['a']!['price_retailer'], 'lidl');
      await repo.undoPriceChange(result.token);
      final row = db.items['a']!;
      expect(row['price'], 1.89);
      expect(row['price_retailer'], 'rewe');
      expect(row['price_old_value'], 2.19);
      expect(
        DateTime.parse(row['price_updated_at'] as String),
        DateTime.utc(2026, 11, 8, 10),
      );
    });

    test('clear nulls every price column; undo brings them back', () async {
      db.items['a'] = _row(
        'a',
        'Milch',
        price: 1.89,
        retailer: 'rewe',
        oldValue: 2.19,
      );
      final result = await repo.clearItemPrice('a');
      expect(result.item.price, isNull);
      expect(result.item.hasPrice, isFalse);
      for (final key in ItemPrice.clearedColumns.keys) {
        expect(db.items['a']![key], isNull, reason: key);
      }
      await repo.undoPriceChange(result.token);
      expect(db.items['a']!['price'], 1.89);
      expect(db.items['a']!['price_retailer'], 'rewe');
    });

    test('a token works once; an unknown token does nothing', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      await repo.undoPriceChange(result.token);
      final writes = db.writes.length;
      await repo.undoPriceChange(result.token);
      await repo.undoPriceChange('unknown');
      expect(db.writes.length, writes);
    });

    test('undo after the item was deleted does not throw', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      db.items.remove('a');
      await repo.undoPriceChange(result.token);
    });

    test('undo reports whether it restored', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      expect(await repo.undoPriceChange(result.token), isTrue);
      expect(await repo.undoPriceChange(result.token), isFalse);
      expect(await repo.undoPriceChange('unknown'), isFalse);
    });

    test('an old token does not overwrite a later price', () async {
      db.items['a'] = _row('a', 'Milch');
      final first = await repo.setItemPrice('a', offer);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.setItemPrice(
        'a',
        const ItemPrice(price: 0.99, retailer: 'aldi'),
      );
      expect(await repo.undoPriceChange(first.token), isFalse);
      expect(db.items['a']!['price'], 0.99);
      expect(db.items['a']!['price_retailer'], 'aldi');
    });

    test('an undo does not overwrite a price another member set', () async {
      db.items['a'] = _row('a', 'Milch');
      final result = await repo.setItemPrice('a', offer);
      db.items['a']!['price'] = 2.5;
      expect(await repo.undoPriceChange(result.token), isFalse);
      expect(db.items['a']!['price'], 2.5);
    });

    test(
      'undo after clear is skipped when a price was set meanwhile',
      () async {
        db.items['a'] = _row('a', 'Milch', price: 1.89, retailer: 'rewe');
        final cleared = await repo.clearItemPrice('a');
        db.items['a']!['price'] = 3.0;
        expect(await repo.undoPriceChange(cleared.token), isFalse);
        expect(db.items['a']!['price'], 3.0);
      },
    );

    test('quantity and name are untouched', () async {
      db.items['a'] = _row('a', 'Milch', quantity: 3);
      await repo.setItemPrice('a', offer);
      expect(db.items['a']!['quantity'], 3);
      expect(db.items['a']!['name'], 'Milch');
    });
  });

  group('NewItem with a price', () {
    test('a new row is written with its price', () async {
      final result = await repo.addItems('l1', const [
        NewItem(name: 'Milch', category: 'dairy', price: offer),
        NewItem(name: 'Brot', category: 'bakery'),
      ]);
      final milk = db.items.values.firstWhere((r) => r['name'] == 'Milch');
      expect(milk['price'], 1.29);
      expect(milk['price_retailer'], 'lidl');
      expect(milk['price_old_value'], 1.59);
      final bread = db.items.values.firstWhere((r) => r['name'] == 'Brot');
      expect(bread.containsKey('price'), isFalse);
      expect(result.items, hasLength(2));
    });

    test(
      'a merge replaces the price; undo restores quantity and price',
      () async {
        db.items['a'] = _row(
          'a',
          'Milch',
          quantity: 1,
          price: 1.89,
          retailer: 'rewe',
        );
        final result = await repo.addItems('l1', const [
          NewItem(name: 'milch', quantity: 2, price: offer),
        ]);
        expect(db.items['a']!['quantity'], 3);
        expect(db.items['a']!['price'], 1.29);
        expect(db.items['a']!['price_retailer'], 'lidl');
        await repo.undoAddItems(result.token);
        expect(db.items['a']!['quantity'], 1);
        expect(db.items['a']!['price'], 1.89);
        expect(db.items['a']!['price_retailer'], 'rewe');
      },
    );

    test('a merge without a price leaves the existing price alone', () async {
      db.items['a'] = _row('a', 'Milch', price: 1.89, retailer: 'rewe');
      await repo.addItems('l1', const [NewItem(name: 'Milch', quantity: 2)]);
      expect(db.items['a']!['price'], 1.89);
      expect(db.items['a']!['price_retailer'], 'rewe');
    });
  });

  group('AddItemsPlan with prices', () {
    ShoppingItemModel existing(String id, String name) =>
        ShoppingItemModel.fromJson(_row(id, name));

    test('a merge carries the price of its batch item', () {
      final plan = AddItemsPlan.of(
        [existing('a', 'Milch')],
        const [NewItem(name: 'Milch', price: offer), NewItem(name: 'Brot')],
      );
      expect(plan.mergePrices, {'a': offer});
      expect(plan.inserts.single.price, isNull);
    });

    test('merges keep the first price of a batch that names an item twice', () {
      const other = ItemPrice(price: 1.19, retailer: 'rewe');
      final plan = AddItemsPlan.of(
        [existing('a', 'Milch')],
        const [
          NewItem(name: 'Milch', price: offer),
          NewItem(name: 'milch', price: other),
        ],
      );
      expect(plan.mergePrices, {'a': offer});
      expect(plan.merges, {'a': 2});
    });

    test('the same item twice keeps the first price it finds', () {
      const other = ItemPrice(price: 0.99, retailer: 'aldi');
      final plan = AddItemsPlan.of(const [], const [
        NewItem(name: 'Milch'),
        NewItem(name: 'milch', price: offer),
        NewItem(name: 'MILCH', price: other),
      ]);
      expect(plan.inserts.single.quantity, 3);
      expect(plan.inserts.single.price, offer);
    });
  });
}
