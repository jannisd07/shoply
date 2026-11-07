// Which shop's offer gets shown for an item you buy regularly.
//
// The point of the home-screen flyer is "your bananas are on offer at your
// REWE". Pointing at a Netto across town for four cents less is noise, so the
// usual shop wins unless another one is meaningfully cheaper.
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
  test('without a known shop the cheapest wins', () {
    final pick = AvoNudgeService.pickOffer([
      offer('Netto', 1.29),
      offer('REWE', 1.49),
    ]);
    expect(pick!.retailerName, 'Netto');
  });

  test('a few cents elsewhere does not displace your usual shop', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Netto', 1.29), offer('REWE', 1.49)],
      preferredRetailer: 'REWE',
    );
    expect(pick!.retailerName, 'REWE');
  });

  test('a real saving does displace it', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Netto', 0.79), offer('REWE', 1.99)],
      preferredRetailer: 'REWE',
    );
    expect(pick!.retailerName, 'Netto');
  });

  test('your shop is used even when it is the pricier one, within tolerance',
      () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Aldi', 1.00), offer('Lidl', 1.40)],
      preferredRetailer: 'lidl',
    );
    expect(pick!.retailerName, 'Lidl');
  });

  test('falls back when your shop has no offer for this item', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Netto', 1.29)],
      preferredRetailer: 'REWE',
    );
    expect(pick!.retailerName, 'Netto');
  });

  test('a disclosed discount is preferred over a marginally cheaper price', () {
    // 20% off at 1.60 beats an undiscounted 1.55 — the flyer is about deals.
    final pick = AvoNudgeService.pickOffer([
      offer('Netto', 1.55),
      offer('REWE', 1.60, oldPrice: 2.00),
    ]);
    expect(pick!.retailerName, 'REWE');
  });

  test('no offers at all yields nothing', () {
    expect(AvoNudgeService.pickOffer([]), isNull);
    expect(
      AvoNudgeService.pickOffer([], preferredRetailer: 'REWE'),
      isNull,
    );
  });

  test('an empty preferred retailer behaves like none', () {
    final pick = AvoNudgeService.pickOffer(
      [offer('Netto', 1.29), offer('REWE', 1.49)],
      preferredRetailer: '   ',
    );
    expect(pick!.retailerName, 'Netto');
  });
}
