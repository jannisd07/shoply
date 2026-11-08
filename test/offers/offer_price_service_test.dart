// Network limits of the offers source (Kap. 12, rule 10): one market at a
// time, a broader search only when that market has no exact hit, a search
// cache of at most 200 entries (LRU) and no sorting by price across markets.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/offer_price_service.dart';

Map<String, Object?> _result(int id, String name, double price, String chain) =>
    {
      'id': id,
      'price': price,
      'description': '',
      'product': {'name': name},
      'advertisers': [
        {'name': chain.toUpperCase(), 'uniqueName': chain},
      ],
    };

/// A fake marktguru: the homepage hands out keys, the search answers from
/// [answers] (query → results) and records every search query.
class _FakeMarktguru {
  _FakeMarktguru([this.answers = const {}]);

  final Map<String, List<Map<String, Object?>>> answers;
  final searches = <String>[];

  late final client = MockClient((request) async {
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
  });

  OfferPriceService service() => OfferPriceService.forTesting(client);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('below two characters nothing is asked', () async {
    final fake = _FakeMarktguru();
    final result = await fake.service().searchOffers('m', zipCode: '89077');

    expect(result, isEmpty);
    expect(fake.searches, isEmpty);
  });

  test('with a market only that market comes back', () async {
    final fake = _FakeMarktguru({
      'milch': [
        _result(1, 'Weidemilch', 0.99, 'rewe'),
        _result(2, 'Frische Milch', 1.09, 'lidl'),
      ],
    });

    final result = await fake
        .service()
        .searchOffers('Milch', zipCode: '89077', chainId: 'lidl');

    expect(result.map((o) => o.id), [2]);
  });

  test('results keep the order of the source, never cheapest first', () async {
    final fake = _FakeMarktguru({
      'milch': [
        _result(1, 'Weidemilch', 1.49, 'rewe'),
        _result(2, 'Frische Milch', 0.79, 'lidl'),
      ],
    });

    final result =
        await fake.service().searchOffers('Milch', zipCode: '89077');

    expect(result.map((o) => o.id), [1, 2]);
  });

  test('an exact hit at the market needs no broader search', () async {
    final fake = _FakeMarktguru({
      'golden toast': [_result(1, 'Golden Toast', 1.29, 'lidl')],
    });

    await fake
        .service()
        .searchOffers('Golden Toast', zipCode: '89077', chainId: 'lidl');

    expect(fake.searches, ['golden toast']);
  });

  test('another market having the product does not trigger a broader search',
      () async {
    // The old rule broadened until "all stores show up" (a market
    // comparison). Now only the list's market matters.
    final fake = _FakeMarktguru({
      'golden toast': [_result(1, 'Golden Toast', 1.29, 'rewe')],
      'toast': [_result(2, 'Buttertoast', 0.99, 'lidl')],
    });

    final result = await fake
        .service()
        .searchOffers('Golden Toast', zipCode: '89077', chainId: 'rewe');

    expect(result.map((o) => o.id), [1]);
    expect(fake.searches, ['golden toast']);
  });

  test('without an exact hit at the market a similar product of it is found',
      () async {
    final fake = _FakeMarktguru({
      'golden toast': [_result(1, 'Golden Toast', 1.29, 'rewe')],
      'toast': [
        _result(2, 'Buttertoast', 0.99, 'lidl'),
        _result(3, 'Vollkorntoast', 1.19, 'rewe'),
      ],
    });

    final result = await fake
        .service()
        .searchOffers('Golden Toast', zipCode: '89077', chainId: 'lidl');

    expect(result.map((o) => o.id), [2]);
    expect(result.single.isBroadMatch, isTrue);
  });

  test('the search cache keeps at most 200 entries, least recently used out',
      () async {
    final fake = _FakeMarktguru();
    final service = fake.service();

    for (var i = 0; i < 201; i++) {
      await service.searchOffers('produkt $i', zipCode: '89077');
    }
    expect(fake.searches, hasLength(201));

    // The newest is still cached, the oldest was dropped.
    await service.searchOffers('produkt 200', zipCode: '89077');
    expect(fake.searches, hasLength(201));
    await service.searchOffers('produkt 0', zipCode: '89077');
    expect(fake.searches, hasLength(202));
  });

  test('a cache hit counts as use', () async {
    final fake = _FakeMarktguru();
    final service = fake.service();

    await service.searchOffers('produkt 0', zipCode: '89077');
    for (var i = 1; i < 200; i++) {
      await service.searchOffers('produkt $i', zipCode: '89077');
    }
    await service.searchOffers('produkt 0', zipCode: '89077'); // hit
    await service.searchOffers('produkt 200', zipCode: '89077'); // evicts 1
    final before = fake.searches.length;

    await service.searchOffers('produkt 0', zipCode: '89077');
    expect(fake.searches.length, before, reason: 'still cached');
    await service.searchOffers('produkt 1', zipCode: '89077');
    expect(fake.searches.length, before + 1, reason: 'was evicted');
  });
}
