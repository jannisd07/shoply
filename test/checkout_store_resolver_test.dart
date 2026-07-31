// Deciding which shop the user is standing in when they finish a trip.
//
// A silently wrong answer is worse than a question: it teaches the app that
// you buy bananas at Lidl when you actually buy them at REWE, and the offer
// flyer then shows you the wrong store's deals. These tests pin down that
// the resolver only commits when the situation is genuinely unambiguous.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/nearby_store.dart';
import 'package:shoply/data/services/checkout_store_resolver.dart';

NearbyStore store(String name, double meters, {String? unique}) => NearbyStore(
      retailerUniqueName: unique ?? name.toLowerCase(),
      displayName: name,
      street: null,
      houseNumber: null,
      city: null,
      latitude: 0,
      longitude: 0,
      distanceMeters: meters,
    );

void main() {
  test('standing in a lone REWE resolves without asking', () {
    final r = CheckoutStoreResolver.resolve([store('REWE', 15)]);
    expect(r, isA<StoreResolved>());
    expect((r as StoreResolved).store.displayName, 'REWE');
  });

  test('a distant rival does not create doubt', () {
    final r = CheckoutStoreResolver.resolve([
      store('REWE', 20),
      store('Lidl', 180),
    ]);
    expect((r as StoreResolved).store.displayName, 'REWE');
  });

  test('two chains sharing a building are ambiguous', () {
    // The shopping-centre case: 20m vs 45m is well inside GPS error.
    final r = CheckoutStoreResolver.resolve([
      store('REWE', 20),
      store('Aldi', 45),
    ]);
    expect(r, isA<StoreAmbiguous>());
    expect((r as StoreAmbiguous).candidates.first.displayName, 'REWE');
  });

  test('two branches of the same chain are not a conflict', () {
    // Both answers would record "REWE", so there is nothing to ask about.
    final r = CheckoutStoreResolver.resolve([
      store('REWE', 20, unique: 'rewe'),
      store('REWE', 40, unique: 'rewe'),
    ]);
    expect(r, isA<StoreResolved>());
  });

  test('near several shops but inside none asks with a shortlist', () {
    final r = CheckoutStoreResolver.resolve([
      store('REWE', 120),
      store('Lidl', 160),
    ]);
    expect(r, isA<StoreAmbiguous>());
    expect((r as StoreAmbiguous).candidates.length, 2);
  });

  test('nothing nearby means ask without a shortlist', () {
    final r = CheckoutStoreResolver.resolve([store('REWE', 900)]);
    expect(r, isA<StoreUnknown>());
    expect((r as StoreUnknown).locationDenied, isFalse);
  });

  test('no stores at all means ask', () {
    expect(CheckoutStoreResolver.resolve([]), isA<StoreUnknown>());
  });

  test('denied location is flagged so the UI can explain the cost', () {
    final r = CheckoutStoreResolver.resolve(
      [store('REWE', 10)],
      locationDenied: true,
    );
    expect(r, isA<StoreUnknown>());
    expect((r as StoreUnknown).locationDenied, isTrue);
  });

  test('input order does not matter', () {
    final r = CheckoutStoreResolver.resolve([
      store('Lidl', 200),
      store('REWE', 12),
    ]);
    expect((r as StoreResolved).store.displayName, 'REWE');
  });

  test('candidates are offered closest first', () {
    final r = CheckoutStoreResolver.resolve([
      store('Aldi', 60),
      store('REWE', 30),
      store('Lidl', 45),
    ]) as StoreAmbiguous;
    expect(
      r.candidates.map((s) => s.displayName).toList(),
      ['REWE', 'Lidl', 'Aldi'],
    );
  });
}
