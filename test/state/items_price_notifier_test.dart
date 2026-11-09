import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/presentation/state/items_provider.dart';

ShoppingItemModel _item(String id, {double? price, String? retailer}) =>
    ShoppingItemModel(
      id: id,
      listId: 'l1',
      name: 'Milch',
      createdAt: DateTime.utc(2026, 11, 9),
      updatedAt: DateTime.utc(2026, 11, 9),
      price: price,
      priceCurrency: price == null ? null : 'EUR',
      priceRetailer: retailer,
      priceUpdatedAt: price == null ? null : DateTime.utc(2026, 11, 8),
    );

class _Repo extends Fake implements ItemRepository {
  bool fail = false;
  bool restores = true;
  final calls = <String>[];

  @override
  Future<PriceChangeResult> setItemPrice(String itemId, ItemPrice price) async {
    calls.add('set $itemId');
    if (fail) throw Exception('offline');
    return PriceChangeResult(
      token: 't1',
      item: _item(itemId, price: price.price),
    );
  }

  @override
  Future<PriceChangeResult> clearItemPrice(String itemId) async {
    calls.add('clear $itemId');
    if (fail) throw Exception('offline');
    return PriceChangeResult(token: 't2', item: _item(itemId));
  }

  @override
  Future<bool> undoPriceChange(String token) async {
    calls.add('undo $token');
    return restores;
  }
}

class _Notifier extends ItemsNotifier {
  _Notifier(_Repo repo, List<ShoppingItemModel> items) : super(repo, 'l1') {
    state = AsyncValue.data(items);
  }

  int loads = 0;

  @override
  Future<void> loadItems() async => loads++;
}

ShoppingItemModel _row(_Notifier n) => n.state.value!.single;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const offer = ItemPrice(price: 1.29, retailer: 'lidl', oldValue: 1.59);

  test('setPrice shows the price at once and returns the token', () async {
    final repo = _Repo();
    final n = _Notifier(repo, [_item('a')]);
    final future = n.setPrice('a', offer);
    expect(_row(n).price, 1.29, reason: 'before the write returns');
    expect(_row(n).priceRetailer, 'lidl');
    expect(_row(n).priceOldValue, 1.59);
    expect(await future, 't1');
    expect(repo.calls, ['set a']);
  });

  test('a failed write rolls the row back and rethrows', () async {
    final repo = _Repo()..fail = true;
    final n = _Notifier(repo, [_item('a', price: 1.89, retailer: 'rewe')]);
    await expectLater(n.setPrice('a', offer), throwsException);
    expect(_row(n).price, 1.89);
    expect(_row(n).priceRetailer, 'rewe');
  });

  test('clearPrice drops the price at once', () async {
    final repo = _Repo();
    final n = _Notifier(repo, [_item('a', price: 1.89, retailer: 'rewe')]);
    final future = n.clearPrice('a');
    expect(_row(n).price, isNull);
    expect(_row(n).hasPrice, isFalse);
    expect(await future, 't2');
  });

  test('undoPrice puts the old price back at once', () async {
    final repo = _Repo();
    final n = _Notifier(repo, [_item('a', price: 1.89, retailer: 'rewe')]);
    final token = await n.setPrice('a', offer);
    expect(_row(n).price, 1.29);
    final future = n.undoPrice(token);
    expect(_row(n).price, 1.89);
    expect(_row(n).priceRetailer, 'rewe');
    await future;
    expect(repo.calls, ['set a', 'undo t1']);
    expect(n.loads, greaterThanOrEqualTo(0));
  });

  test('undo of a first price removes it again', () async {
    final n = _Notifier(_Repo(), [_item('a')]);
    final token = await n.setPrice('a', offer);
    await n.undoPrice(token);
    expect(_row(n).price, isNull);
  });

  test('when the repository did not restore, the list is reloaded', () async {
    final repo = _Repo()..restores = false;
    final n = _Notifier(repo, [_item('a')]);
    final token = await n.setPrice('a', offer);
    final before = n.loads;
    await n.undoPrice(token);
    expect(n.loads, greaterThan(before));
  });
}
