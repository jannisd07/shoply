// The suggestion card shows three rows and scrolls to the rest, so the
// provider must return *every* match — but ordered so the rows visible
// without scrolling are different stores rather than three variants from
// the same one.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

StoreOffer offer({
  required int id,
  required String name,
  required double price,
  required String retailer,
}) =>
    StoreOffer(
      id: id,
      productName: name,
      brandName: null,
      description: '',
      price: price,
      oldPrice: null,
      unitShortName: null,
      retailerName: retailer,
      retailerUniqueName: retailer,
      categoryName: null,
      validFrom: null,
      validTo: null,
    );

Future<List<StoreOffer>> suggestionsFor(List<StoreOffer> all) async {
  final container = ProviderContainer(overrides: [
    offerSearchAllProvider('oliven').overrideWith((ref) async => all),
  ]);
  addTearDown(container.dispose);
  return container.read(offerSuggestionsProvider('oliven').future);
}

void main() {
  test('returns every match, not just the first three', () async {
    final all = [
      for (var i = 0; i < 7; i++)
        offer(id: i, name: 'Oliven $i', price: 1.0 + i, retailer: 'rewe'),
    ];
    expect((await suggestionsFor(all)).length, 7);
  });

  test('leads with one offer per retailer', () async {
    final all = [
      offer(id: 1, name: 'Oliven klein', price: 1.00, retailer: 'rewe'),
      offer(id: 2, name: 'Oliven groß', price: 1.20, retailer: 'rewe'),
      offer(id: 3, name: 'Oliven', price: 1.50, retailer: 'lidl'),
      offer(id: 4, name: 'Oliven', price: 1.80, retailer: 'aldi'),
    ];
    final result = await suggestionsFor(all);
    // First three rows = three different stores, the second REWE variant
    // moves below the fold.
    expect(result.take(3).map((o) => o.retailerUniqueName).toSet().length, 3);
    expect(result.last.id, 2);
    expect(result.length, 4);
  });

  test('relevant names outrank loose matches', () async {
    final all = [
      offer(id: 1, name: 'Sahne Joghurt', price: 0.50, retailer: 'rewe'),
      offer(id: 2, name: 'Oliven schwarz', price: 2.00, retailer: 'lidl'),
    ];
    final result = await suggestionsFor(all);
    // Cheaper, but it isn't what the user typed.
    expect(result.first.id, 2);
  });

  test('no duplicates when every offer is from a different store', () async {
    final all = [
      offer(id: 1, name: 'Oliven', price: 1.0, retailer: 'rewe'),
      offer(id: 2, name: 'Oliven', price: 2.0, retailer: 'lidl'),
    ];
    final result = await suggestionsFor(all);
    expect(result.map((o) => o.id).toList(), [1, 2]);
  });

  test('empty input yields no suggestions', () async {
    expect(await suggestionsFor([]), isEmpty);
  });
}
