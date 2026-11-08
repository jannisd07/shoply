// Which shop's offer gets shown for an item you buy regularly.
//
// The point of the home-screen flyer is "your bananas are on offer at your
// REWE". Kap. 12 forbids comparing markets, so only the shop where you
// usually buy the item counts; another shop never wins, however cheap.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';

StoreOffer offer(
  String retailer,
  double price, {
  double? oldPrice,
}) =>
    StoreOffer(
      id: retailer.hashCode ^ price.hashCode,
      productName: 'Bananen',
      brandName: null,
      description: '',
      price: price,
      oldPrice: oldPrice,
      unitShortName: null,
      retailerName: retailer,
      retailerUniqueName: retailer.toLowerCase(),
      categoryName: null,
      validFrom: null,
      validTo: null,
    );

void main() {
  test('without a usual market there is no offer nudge', () {
    expect(
      AvoNudgeService.pickOffer([offer('Netto', 1.29), offer('REWE', 1.49)]),
      isNull,
    );
  });

  test('only the usual market counts, never a cheaper one elsewhere', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Netto', 0.79), offer('REWE', 1.99)],
      preferredRetailer: 'REWE',
    );
    expect(pick!.retailerName, 'REWE');
  });

  test('matches the market by name or unique name, case-insensitive', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Aldi', 1.00), offer('Lidl', 1.40)],
      preferredRetailer: 'lidl',
    );
    expect(pick!.retailerName, 'Lidl');
  });

  test('no offer at the usual market means no nudge', () {
    expect(
      AvoNudgeService.pickOffer(
        [offer('Netto', 1.29)],
        preferredRetailer: 'REWE',
      ),
      isNull,
    );
  });

  test('within the market a disclosed discount beats a cheaper price', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('REWE', 1.55), offer('REWE', 1.60, oldPrice: 2.00)],
      preferredRetailer: 'REWE',
    );
    expect(pick!.price, 1.60);
  });

  test('no offers at all yields nothing', () {
    expect(AvoNudgeService.pickOffer([]), isNull);
    expect(AvoNudgeService.pickOffer([], preferredRetailer: 'REWE'), isNull);
  });

  test('an empty preferred retailer behaves like none', () {
    expect(
      AvoNudgeService.pickOffer(
        [offer('Netto', 1.29), offer('REWE', 1.49)],
        preferredRetailer: '   ',
      ),
      isNull,
    );
  });
}
