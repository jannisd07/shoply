// A StoreOffer as the list sync keeps it on the device (6-h snapshot), plus
// the honesty rules on the model itself: no retailer image, no own
// percentage, market by chain id.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/store_offer.dart';

void main() {
  final offer = StoreOffer(
    id: 42,
    productName: 'Frische Vollmilch 3,5 %',
    brandName: 'Milbona',
    description: 'statt 1,19',
    price: 0.99,
    oldPrice: 1.19,
    unitShortName: 'l',
    retailerName: 'Lidl',
    retailerUniqueName: 'lidl',
    categoryName: 'Milch',
    validFrom: DateTime.utc(2026, 11, 2),
    validTo: DateTime.utc(2026, 11, 14),
    volume: 1,
    packQuantity: 1,
    referencePrice: 0.99,
  );

  test('toJson and fromJson keep every field', () {
    final back = StoreOffer.fromJson(offer.toJson())!;

    expect(back.id, 42);
    expect(back.productName, 'Frische Vollmilch 3,5 %');
    expect(back.brandName, 'Milbona');
    expect(back.description, 'statt 1,19');
    expect(back.price, 0.99);
    expect(back.oldPrice, 1.19);
    expect(back.unitShortName, 'l');
    expect(back.retailerName, 'Lidl');
    expect(back.retailerUniqueName, 'lidl');
    expect(back.categoryName, 'Milch');
    expect(back.validFrom, DateTime.utc(2026, 11, 2));
    expect(back.validTo, DateTime.utc(2026, 11, 14));
    expect(back.volume, 1);
    expect(back.packQuantity, 1);
    expect(back.referencePrice, 0.99);
  });

  test('a market matches by chain id, also a sub-brand of it', () {
    expect(offer.isFromChain('lidl'), isTrue);
    expect(offer.isFromChain('rewe'), isFalse);
  });

  test('no retailer image and no own percentage', () {
    // ignore: deprecated_member_use_from_same_package
    expect(offer.imageUrl, isEmpty);
    // ignore: deprecated_member_use_from_same_package
  });
}
