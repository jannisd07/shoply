// Covers the two pure steps where a wrong price could slip in: deciding
// which Open Food Facts hits are relevant, and condensing crowdsourced
// observations into one number.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shelf_price.dart';
import 'package:shoply/data/services/open_prices_service.dart';

PriceObservation obs(
  double price, {
  String country = 'DE',
  int daysAgo = 10,
  bool discounted = false,
  String? retailer,
}) =>
    PriceObservation(
      price: price,
      currency: 'EUR',
      date: DateTime.now().subtract(Duration(days: daysAgo)),
      countryCode: country,
      barcode: '123',
      retailer: retailer,
      isDiscounted: discounted,
    );

void main() {
  group('relevance guard on search hits', () {
    test('keeps products whose name contains the query', () {
      final codes = OpenPricesService.hitsToBarcodes([
        {'code': '1', 'product_name': 'Jordan Olivenöl Nativ Extra'},
        {'code': '2', 'product_name_de': 'Bio Olivenöl'},
      ], 'olivenöl');
      expect(codes, ['1', '2']);
    });

    test('drops unrelated hits the fuzzy search throws in', () {
      // The search endpoint returns loosely related products; without this
      // guard "Olivenöl" would end up priced as Nutella.
      final codes = OpenPricesService.hitsToBarcodes([
        {'code': '1', 'product_name': 'Nutella'},
        {'code': '2', 'product_name': 'Maggi Würze'},
        {'code': '3', 'product_name': 'Olivenöl Extra Vergine'},
      ], 'olivenöl');
      expect(codes, ['3']);
    });

    test('ignores hits without a barcode', () {
      final codes = OpenPricesService.hitsToBarcodes([
        {'product_name': 'Olivenöl'},
      ], 'olivenöl');
      expect(codes, isEmpty);
    });

    test('caps the number of candidates', () {
      final codes = OpenPricesService.hitsToBarcodes([
        for (var i = 0; i < 20; i++)
          {'code': '$i', 'product_name': 'Olivenöl $i'},
      ], 'olivenöl');
      expect(codes.length, 5);
    });
  });

  group('category selection', () {
    // Real tag list from an Open Food Facts olive oil, general -> specific.
    const oliveOilTags = [
      'en:plant-based-foods-and-beverages',
      'en:plant-based-foods',
      'en:fats',
      'en:vegetable-fats',
      'en:olive-tree-products',
      'en:vegetable-oils',
      'en:olive-oils',
      'en:extra-virgin-olive-oils',
      'en:virgin-olive-oils',
    ];

    test('picks a narrow category, never a top-level one', () {
      final tag = OpenPricesService.pickCategoryTag([
        {'product_name_de': 'Olivenöl', 'categories_tags': oliveOilTags},
        {'product_name_de': 'Bio Olivenöl', 'categories_tags': oliveOilTags},
      ], 'olivenöl');
      // en:plant-based-foods has ~62k prices and would price olive oil as
      // any plant-based food at all.
      expect(tag, isNot('en:plant-based-foods'));
      expect(tag, isNot('en:fats'));
      expect(oliveOilTags.indexOf(tag!), greaterThanOrEqualTo(6));
    });

    test('ignores categories of irrelevant hits', () {
      final tag = OpenPricesService.pickCategoryTag([
        {'product_name': 'Nutella', 'categories_tags': ['en:spreads', 'en:cocoa-spreads']},
        {'product_name_de': 'Olivenöl', 'categories_tags': oliveOilTags},
      ], 'olivenöl');
      expect(tag, isNot('en:cocoa-spreads'));
    });

    test('returns null when no hit is relevant', () {
      final tag = OpenPricesService.pickCategoryTag([
        {'product_name': 'Nutella', 'categories_tags': ['en:spreads']},
      ], 'olivenöl');
      expect(tag, isNull);
    });

    test('copes with hits that carry no categories', () {
      final tag = OpenPricesService.pickCategoryTag([
        {'product_name_de': 'Olivenöl'},
      ], 'olivenöl');
      expect(tag, isNull);
    });
  });

  group('aggregation', () {
    test('uses the median so a single outlier cannot skew the price', () {
      // A multipack logged as one unit (27.70) must not move the result.
      final result = OpenPricesService.aggregate(
          [obs(3.99), obs(4.19), obs(4.29), obs(27.70)]);
      expect(result!.price, closeTo(4.24, 0.001));
    });

    test('ignores non-German observations', () {
      final result = OpenPricesService.aggregate([
        obs(7.15, country: 'NL'),
        obs(3.99),
        obs(4.01),
      ]);
      expect(result!.price, closeTo(4.0, 0.001));
      expect(result.sampleSize, 2);
    });

    test('prefers regular prices over discounted ones', () {
      final result = OpenPricesService.aggregate([
        obs(1.99, discounted: true),
        obs(3.49),
        obs(3.49),
      ]);
      expect(result!.price, closeTo(3.49, 0.001));
      expect(result.sampleSize, 2);
    });

    test('falls back to discounted data when that is all there is', () {
      final result = OpenPricesService.aggregate([obs(1.99, discounted: true)]);
      expect(result!.price, closeTo(1.99, 0.001));
    });

    test('drops observations older than a year', () {
      expect(OpenPricesService.aggregate([obs(3.99, daysAgo: 400)]), isNull);
    });

    test('reports the newest observation date and retailer', () {
      final result = OpenPricesService.aggregate([
        obs(3.99, daysAgo: 200, retailer: 'Aldi'),
        obs(4.49, daysAgo: 2, retailer: 'REWE'),
      ]);
      expect(result!.retailer, 'REWE');
      expect(DateTime.now().difference(result.observedAt).inDays, lessThan(5));
    });

    test('returns null when nothing usable remains', () {
      expect(OpenPricesService.aggregate([]), isNull);
      expect(OpenPricesService.aggregate([obs(2.0, country: 'FR')]), isNull);
    });
  });

  group('staleness', () {
    test('a months-old price is flagged rather than shown as current', () {
      final old = ShelfPrice(
        price: 3.99,
        currency: 'EUR',
        observedAt: DateTime.now().subtract(const Duration(days: 200)),
        barcode: '1',
      );
      expect(old.isStale, isTrue);
    });

    test('a recent price is not stale', () {
      final fresh = ShelfPrice(
        price: 3.99,
        currency: 'EUR',
        observedAt: DateTime.now().subtract(const Duration(days: 3)),
        barcode: '1',
      );
      expect(fresh.isStale, isFalse);
    });
  });
}
