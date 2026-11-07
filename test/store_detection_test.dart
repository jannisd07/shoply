// Pins the unambiguous ends of the "Markt pro Liste" decision. How the
// learned, name, location and private-label signals combine is a product
// decision and is tested once it is made.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/store_detection_service.dart';

void main() {
  test('an explicit choice beats every other signal', () {
    final guess = resolveStoreForList(
      explicitChainId: 'rewe',
      nameChainId: 'lidl',
      recentTripChains: const ['lidl', 'lidl', 'lidl'],
      nearbyChainId: 'lidl',
      privateLabelHits: const {'lidl': 5},
    );
    expect(guess, const StoreGuess('rewe', StoreSource.user, confirmed: true));
  });

  test('no signals means no market', () {
    expect(resolveStoreForList(), isNull);
  });
}
