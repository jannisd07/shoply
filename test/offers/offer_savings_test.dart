// The one savings rule for list, checkout, history and Avo (Kap. 12, rule 5):
// "X von Y Artikeln diese Woche bei {Markt} im Angebot, ca. Z € gespart, in
// deiner Region". Savings only against a "statt" price the retailer states,
// over the base price (Grundpreis) and the list quantity, below 0,50 € none,
// otherwise rounded to 10 ct with "ca.". Without a real region no savings.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_savings.dart';

ShoppingItemModel _item(
  String id, {
  double quantity = 1,
  String? unit,
  bool checked = false,
}) {
  final now = DateTime(2026, 11, 8);
  return ShoppingItemModel(
    id: id,
    listId: 'list-1',
    name: 'Artikel $id',
    quantity: quantity,
    unit: unit,
    isChecked: checked,
    createdAt: now,
    updatedAt: now,
  );
}

StoreOffer _offer({
  required double price,
  double? oldPrice,
  String description = '',
  String retailer = 'lidl',
  String? unit,
  double? volume,
  double? packQuantity,
  double? referencePrice,
  bool broad = false,
}) {
  final offer = StoreOffer(
    id: price.hashCode ^ retailer.hashCode,
    productName: 'Produkt',
    brandName: null,
    description: description,
    price: price,
    oldPrice: oldPrice,
    unitShortName: unit,
    retailerName: retailer == 'lidl' ? 'Lidl' : retailer,
    retailerUniqueName: retailer,
    categoryName: null,
    validFrom: null,
    validTo: null,
    volume: volume,
    packQuantity: packQuantity,
    referencePrice: referencePrice,
  );
  return broad ? offer.asBroadMatch() : offer;
}

/// 11 open items, 4 of them on offer at Lidl.
List<ShoppingItemModel> _elevenItems() => [
      for (var i = 1; i <= 11; i++) _item('$i'),
    ];

void main() {
  group('roundedSavingsCents', () {
    test('below 50 ct there is no savings figure', () {
      expect(roundedSavingsCents(0), isNull);
      expect(roundedSavingsCents(49), isNull);
    });

    test('from 50 ct it is rounded to 10 ct', () {
      expect(roundedSavingsCents(50), 50);
      expect(roundedSavingsCents(317), 320);
      expect(roundedSavingsCents(314), 310);
      expect(roundedSavingsCents(315), 320);
    });
  });

  group('summarizeListOffers', () {
    test('4 of 11 with 3,17 € reads "ca. 3,20 € gespart"', () {
      final offers = {
        '1': _offer(price: 1.00, oldPrice: 2.00),
        '2': _offer(price: 1.00, oldPrice: 2.00),
        '3': _offer(price: 0.83, oldPrice: 2.00),
        '4': _offer(price: 0.99),
      };

      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: _elevenItems(),
        offersByItemId: offers,
        realRegion: true,
      )!;

      expect(summary.matched, 4);
      expect(summary.total, 11);
      expect(summary.savingsCents, 320);
      expect(
        formatOfferSummary(summary, 'de'),
        '4 von 11 Artikeln diese Woche bei Lidl im Angebot, '
        'ca. 3,20 € gespart, in deiner Region',
      );
      expect(
        formatOfferSummary(summary, 'en'),
        '4 of 11 items on offer at Lidl this week, about €3.20 saved, '
        'in your area',
      );
    });

    test('0,49 € of savings leaves the savings part out', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: _elevenItems(),
        offersByItemId: {'1': _offer(price: 1.00, oldPrice: 1.49)},
        realRegion: true,
      )!;

      expect(summary.savingsCents, isNull);
      expect(
        formatOfferSummary(summary, 'de'),
        '1 von 11 Artikeln diese Woche bei Lidl im Angebot, in deiner Region',
      );
      expect(
        formatOfferSummary(summary, 'en'),
        '1 of 11 items on offer at Lidl this week, in your area',
      );
    });

    test('without a real region there is no savings part', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: _elevenItems(),
        offersByItemId: {'1': _offer(price: 1.00, oldPrice: 5.00)},
        realRegion: false,
      )!;

      expect(summary.matched, 1);
      expect(summary.savingsCents, isNull);
      expect(formatOfferSummary(summary, 'de'), isNot(contains('gespart')));
    });

    test('one of one item reads in the singular', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1')],
        offersByItemId: {'1': _offer(price: 0.99)},
        realRegion: true,
      )!;

      expect(
        formatOfferSummary(summary, 'de'),
        '1 von 1 Artikel diese Woche bei Lidl im Angebot, in deiner Region',
      );
      expect(
        formatOfferSummary(summary, 'en'),
        '1 of 1 item on offer at Lidl this week, in your area',
      );
    });

    test('500 g on the list against a 1 kg pack counts half the base price',
        () {
      // 1 kg flour 1,00 € statt 2,20 €: Grundpreis 1,00 €/kg statt 2,20 €/kg.
      // 500 g on the list saves 0,60 €, not the 1,20 € of a whole pack.
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1', quantity: 500, unit: 'g')],
        offersByItemId: {
          '1': _offer(
            price: 1.00,
            oldPrice: 2.20,
            unit: 'kg',
            volume: 1,
            referencePrice: 1.00,
          ),
        },
        realRegion: true,
      )!;

      expect(summary.savingsCents, 60);
    });

    test('2 kg on the list against a 1 kg pack counts twice', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1', quantity: 2, unit: 'kg')],
        offersByItemId: {
          '1': _offer(price: 1.00, oldPrice: 1.40, unit: 'kg', volume: 1),
        },
        realRegion: true,
      )!;

      expect(summary.savingsCents, 80);
    });

    test('without a comparable unit it counts the pack difference per piece',
        () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1', quantity: 3)],
        offersByItemId: {
          '1': _offer(price: 0.99, oldPrice: 1.19, unit: 'l', volume: 1),
        },
        realRegion: true,
      )!;

      expect(summary.savingsCents, 60);
    });

    test('a measured quantity in another unit counts one pack', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1', quantity: 500, unit: 'g')],
        offersByItemId: {
          '1': _offer(price: 0.99, oldPrice: 1.79, unit: 'l', volume: 1),
        },
        realRegion: true,
      )!;

      expect(summary.savingsCents, 80);
    });

    test('a UVP in the description is not a "statt" price', () {
      final offer = _offer(price: 0.99, description: 'UVP 2,99');
      expect(offer.regularPrice, isNull);

      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1')],
        offersByItemId: {'1': offer},
        realRegion: true,
      )!;

      expect(summary.matched, 1);
      expect(summary.savingsCents, isNull);
    });

    test('a "statt" price the retailer states in the description counts', () {
      final offer = _offer(price: 0.99, description: 'statt 1,99');
      expect(offer.regularPrice, 1.99);
    });

    test('offers of another market never count', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: _elevenItems(),
        offersByItemId: {
          '1': _offer(price: 0.99, oldPrice: 3.00, retailer: 'rewe'),
        },
        realRegion: true,
      );

      expect(summary, isNull);
    });

    test('a similar product counts as on offer but saves nothing', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1')],
        offersByItemId: {
          '1': _offer(price: 0.99, oldPrice: 3.00, broad: true),
        },
        realRegion: true,
      )!;

      expect(summary.matched, 1);
      expect(summary.savingsCents, isNull);
    });

    test('checked items are not part of "von Y"', () {
      final summary = summarizeListOffers(
        chainId: 'lidl',
        openItems: [_item('1'), _item('2', checked: true)],
        offersByItemId: {'1': _offer(price: 0.99)},
        realRegion: true,
      )!;

      expect(summary.total, 1);
    });

    test('nothing on offer gives no summary', () {
      expect(
        summarizeListOffers(
          chainId: 'lidl',
          openItems: _elevenItems(),
          offersByItemId: const {},
          realRegion: true,
        ),
        isNull,
      );
    });
  });
}
