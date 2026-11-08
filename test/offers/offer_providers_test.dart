// Offer providers behind the list slots (Kap. 12): no request without a real
// region or with offers off (module or kill switch), only the offers of the
// list's market, a typed search waits 300 ms, and the offers of a list's
// items are fetched at most every 6 h; checking off and adding count locally.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

const _listId = 'list-1';
const _lidl = StoreInfo(id: 'lidl', name: 'Lidl', shortLabel: 'L');
const _ulm = Region(zip: '89077', city: 'Ulm', source: RegionSource.gps);

ShoppingItemModel _item(String id, String name, {bool checked = false}) {
  final now = DateTime(2026, 11, 8);
  return ShoppingItemModel(
    id: id,
    listId: _listId,
    name: name,
    isChecked: checked,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, Object?> _result(
  int id,
  String name,
  double price,
  String chain, {
  double? oldPrice,
}) =>
    {
      'id': id,
      'price': price,
      'oldPrice': oldPrice,
      'description': '',
      'product': {'name': name},
      'advertisers': [
        {'name': chain == 'lidl' ? 'Lidl' : 'REWE', 'uniqueName': chain},
      ],
    };

/// Counts every HTTP request to the offers source (keys page and search).
class _Source {
  _Source([this.answers = const {}, this.clock]);

  final Map<String, List<Map<String, Object?>>> answers;

  /// Shared with the snapshot, so the 30-min search cache ages with it.
  final _Clock? clock;
  var requests = 0;
  final searches = <String>[];

  late final service = OfferPriceService.forTesting(
    MockClient((request) async {
      requests++;
      if (request.url.host == 'www.marktguru.de') {
        return http.Response(
          '<script type="application/json">'
          '{"config":{"apiKey":"a","clientKey":"c"}}</script>',
          200,
        );
      }
      final q = request.url.queryParameters['q']!;
      searches.add(q);
      return http.Response(
        jsonEncode({'results': answers[q] ?? const []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
    now: clock == null ? DateTime.now : () => clock!.now,
  );
}

final _answers = {
  'milch': [
    _result(1, 'Weidemilch', 0.99, 'rewe', oldPrice: 1.49),
    _result(2, 'Frische Milch', 0.89, 'lidl', oldPrice: 1.19),
  ],
  'butter': [_result(3, 'Süßrahmbutter', 1.79, 'lidl', oldPrice: 2.49)],
  'brot': [_result(4, 'Bauernbrot', 1.49, 'rewe')],
};

/// The list's items as the test changes them.
final _items = StateProvider<List<ShoppingItemModel>>((ref) => const []);

class _Clock {
  DateTime now = DateTime(2026, 11, 8, 9);
}

ProviderContainer _container({
  required _Source source,
  Region? region = _ulm,
  bool offersOn = true,
  StoreInfo? store = _lidl,
  List<ShoppingItemModel>? items,
  _Clock? clock,
}) {
  final open = items ??
      [_item('a', 'Milch'), _item('b', 'Butter'), _item('c', 'Brot')];
  final container = ProviderContainer(
    overrides: [
      offerPriceServiceProvider.overrideWithValue(source.service),
      listOfferSyncProvider.overrideWith(
        (ref) => ListOfferSync(
          ref.watch(offerPriceServiceProvider),
          now: clock == null ? DateTime.now : () => clock.now,
        ),
      ),
      regionProvider.overrideWithValue(region),
      offersAvailableProvider.overrideWithValue(offersOn),
      storeForListProvider.overrideWith((ref, id) => store),
      _items.overrideWith((ref) => open),
      offerListItemsProvider.overrideWith((ref, id) => ref.watch(_items)),
      regionLoadedProvider.overrideWithValue(true),
      offerDealListIdsProvider.overrideWith((ref) => const [_listId]),
      offerDealItemsProvider.overrideWith(
        (ref, ids) async => [
          for (final item in ref.watch(_items))
            if (!item.isChecked) item,
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Keeps every list provider alive like the list screen does, waits for the
/// sync and returns the offers per item id.
Future<void> _syncList(ProviderContainer container) async {
  container.listen(listOfferSummaryProvider(_listId), (_, __) {});
  container.listen(listOfferCountProvider(_listId), (_, __) {});
  await container.read(listOfferSnapshotProvider(_listId).future);
}

Future<void> _hiddenListsLoaded() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('without a real region', () {
    test('every offer provider is empty and nothing is asked', () async {
      final source = _Source(_answers);
      final container = _container(source: source, region: null);
      await _hiddenListsLoaded();

      expect(await container.read(offerSearchAllProvider('milch').future),
          isEmpty);
      expect(
        await container.read(
          offerSuggestionsProvider((listId: _listId, query: 'milch')).future,
        ),
        isEmpty,
      );
      await _syncList(container);
      expect(container.read(listItemOffersProvider(_listId)), isEmpty);
      expect(container.read(listOfferSummaryProvider(_listId)), isNull);
      expect(container.read(listOfferCountProvider(_listId)), 0);
      expect(
        container.read(itemOfferProvider((listId: _listId, itemId: 'a'))),
        isNull,
      );
      expect(source.requests, 0);
    });
  });

  group('with offers off (module or kill switch)', () {
    test('every offer provider is empty and nothing is asked', () async {
      final source = _Source(_answers);
      final container = _container(source: source, offersOn: false);
      await _hiddenListsLoaded();

      expect(await container.read(offerSearchAllProvider('milch').future),
          isEmpty);
      expect(
        await container.read(
          offerSuggestionsProvider((listId: _listId, query: 'milch')).future,
        ),
        isEmpty,
      );
      await _syncList(container);
      expect(container.read(listOfferSummaryProvider(_listId)), isNull);
      expect(container.read(listOfferCountProvider(_listId)), 0);
      expect(source.requests, 0);
    });
  });

  group('a list without a confirmed market', () {
    test('shows no market-specific offers and asks nothing for it', () async {
      final source = _Source(_answers);
      final container = _container(source: source, store: null);
      await _hiddenListsLoaded();

      expect(
        await container.read(
          offerSuggestionsProvider((listId: _listId, query: 'milch')).future,
        ),
        isEmpty,
      );
      await _syncList(container);
      expect(container.read(listOfferSummaryProvider(_listId)), isNull);
      expect(source.requests, 0);
    });
  });

  group('with region, market and offers on', () {
    test('suggestions show only the market of the list', () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();

      final offers = await container.read(
        offerSuggestionsProvider((listId: _listId, query: 'milch')).future,
      );

      expect(offers.map((o) => o.id), [2]);
    });

    test('the list summary counts the items on offer at its market', () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();
      await _syncList(container);

      expect(container.read(listOfferCountProvider(_listId)), 2);
      expect(
        container.read(itemOfferProvider((listId: _listId, itemId: 'a')))?.id,
        2,
      );
      expect(
        container.read(itemOfferProvider((listId: _listId, itemId: 'c'))),
        isNull,
        reason: 'bread is only on offer at REWE',
      );
      final summary = container.read(listOfferSummaryProvider(_listId))!;
      expect(summary.matched, 2);
      expect(summary.total, 3);
      // 0,30 € (milk) + 0,70 € (butter) = 1,00 €.
      expect(summary.savingsCents, 100);
    });

    test('checking off an item counts again without a request', () async {
      final source = _Source(_answers);
      final items = [_item('a', 'Milch'), _item('b', 'Butter')];
      final container = _container(source: source, items: items);
      await _hiddenListsLoaded();
      await _syncList(container);
      final before = source.requests;

      container.read(_items.notifier).state = [
        _item('a', 'Milch', checked: true),
        items[1],
      ];
      await Future<void>.delayed(Duration.zero);

      expect(container.read(listOfferCountProvider(_listId)), 1);
      expect(container.read(listOfferSummaryProvider(_listId))?.total, 1);
      expect(source.requests, before);
    });

    test('the offers of a list are fetched at most every 6 h', () async {
      final clock = _Clock();
      final source = _Source(_answers, clock);
      final container = _container(source: source, clock: clock);
      await _hiddenListsLoaded();
      await _syncList(container);
      final firstRound = source.searches.length;
      expect(firstRound, greaterThan(0));

      clock.now = clock.now.add(const Duration(hours: 5));
      container.invalidate(listOfferSnapshotProvider(_listId));
      await _syncList(container);
      expect(source.searches.length, firstRound);

      clock.now = clock.now.add(const Duration(hours: 2));
      container.invalidate(listOfferSnapshotProvider(_listId));
      await _syncList(container);
      expect(source.searches.length, greaterThan(firstRound));
    });

    test('the 6-h snapshot survives an app restart', () async {
      final source = _Source(_answers);
      final clock = _Clock();
      final first = _container(source: source, clock: clock);
      await _hiddenListsLoaded();
      await _syncList(first);
      final firstRound = source.searches.length;
      first.dispose();

      final restarted = _Source(_answers);
      final second = _container(source: restarted, clock: clock);
      await _hiddenListsLoaded();
      await _syncList(second);

      expect(restarted.requests, 0);
      expect(second.read(listOfferCountProvider(_listId)), 2);
      expect(firstRound, greaterThan(0));
    });

    test('a typed search waits 300 ms and asks nothing when overtaken',
        () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();

      final sub = container.listen(
        offerSearchAllProvider('mil'),
        (_, __) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      sub.close();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(source.requests, 0);
    });

    test('the all-markets search keeps the order of the source', () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();

      final offers =
          await container.read(offerSearchAllProvider('milch').future);

      expect(offers.map((o) => o.id), [1, 2]);
    });
  });

  group('deals of the lists (Home, weekly offers)', () {
    test('without a real region there are none and nothing is asked',
        () async {
      final source = _Source(_answers);
      final container = _container(source: source, region: null);
      await _hiddenListsLoaded();

      expect(await container.read(personalizedDealsProvider.future), isEmpty);
      expect(source.requests, 0);
    });

    test('with offers off there are none and nothing is asked', () async {
      final source = _Source(_answers);
      final container = _container(source: source, offersOn: false);
      await _hiddenListsLoaded();

      expect(await container.read(personalizedDealsProvider.future), isEmpty);
      expect(source.requests, 0);
    });

    test('a list without a confirmed market brings none', () async {
      final source = _Source(_answers);
      final container = _container(source: source, store: null);
      await _hiddenListsLoaded();

      expect(await container.read(personalizedDealsProvider.future), isEmpty);
      expect(source.requests, 0);
    });

    test('only offers of the list market, in the order of the list',
        () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();

      final deals = await container.read(personalizedDealsProvider.future);

      expect(deals.map((d) => d.offerId), [2, 3]);
      expect(deals.map((d) => d.retailerName).toSet(), {'Lidl'});
    });

    test('shares the 6-h snapshot with the list screen', () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();
      await _syncList(container);
      final before = source.requests;

      await container.read(personalizedDealsProvider.future);

      expect(source.requests, before);
    });
  });

  group('transition for older callers', () {
    test('the old per-row lookup gives the offer of the list market only',
        () async {
      final source = _Source(_answers);
      final container = _container(source: source);
      await _hiddenListsLoaded();
      await _syncList(container);

      // ignore: deprecated_member_use_from_same_package
      final offers = await container.read(
        // ignore: deprecated_member_use_from_same_package
        basketComparisonProvider(_listId).future,
      );
      // ignore: deprecated_member_use_from_same_package
      expect(offers.cheapestOfferFor('Milch')?.id, 2);
      // ignore: deprecated_member_use_from_same_package
      expect(offers.cheapestOfferFor('Brot'), isNull);
    });
  });
}
