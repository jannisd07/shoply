// Numbers, packs, dates and spoken forms of offers (angebote.md 3.3, 3.11):
// "0,99 €" / "€0.99", "bis Sa., 14. Nov." / "until Sat, Nov 14", the
// three-day end label, and what VoiceOver says.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';

StoreOffer _offer({
  double price = 0.99,
  double? volume,
  double? packs,
  String? unit,
  double? reference,
  DateTime? to,
  String retailer = 'lidl',
  String? brand,
  String product = 'Frische Vollmilch',
}) => StoreOffer(
  id: 1,
  productName: product,
  brandName: brand,
  description: '',
  price: price,
  oldPrice: null,
  unitShortName: unit,
  retailerName: retailer == 'aldi-sued' ? 'ALDI SÜD' : 'Lidl',
  retailerUniqueName: retailer,
  categoryName: null,
  validFrom: null,
  validTo: to,
  volume: volume,
  packQuantity: packs,
  referencePrice: reference,
);

void main() {
  group('prices', () {
    test('German and English money', () {
      expect(formatEuro(0.99, 'de'), '0,99 €');
      expect(formatEuro(0.99, 'en'), '€0.99');
      expect(formatEuro(3.2, 'de'), '3,20 €');
      expect(formatEuroCents(320, 'de'), '3,20 €');
      expect(formatEuroCents(320, 'en'), '€3.20');
    });

    test('spoken: "0,99 Euro", "99 cents"', () {
      expect(spokenEuro(0.99, 'de'), '0,99 Euro');
      expect(spokenEuro(0.99, 'en'), '99 cents');
      expect(spokenEuro(1.49, 'en'), '€1.49');
    });
  });

  group('packs and unit prices', () {
    test('"1 l" / "1 L", "250 g", "6 × 1,5 l"', () {
      expect(formatPack(_offer(volume: 1, unit: 'l'), 'de'), '1 l');
      expect(formatPack(_offer(volume: 1, unit: 'l'), 'en'), '1 L');
      expect(formatPack(_offer(volume: 250, unit: 'g'), 'de'), '250 g');
      expect(
        formatPack(_offer(volume: 1.5, packs: 6, unit: 'l'), 'de'),
        '6 × 1,5 l',
      );
      expect(
        formatPack(_offer(volume: 1.5, packs: 6, unit: 'l'), 'en'),
        '6 × 1.5 L',
      );
      expect(formatPack(_offer(), 'de'), isNull);
    });

    test('unit price only when it adds something, spoken in full', () {
      final six = _offer(volume: 1.5, packs: 6, unit: 'l', reference: 0.66);
      expect(formatUnitPrice(six, 'de'), '0,66 €/l');
      expect(formatUnitPrice(six, 'en'), '€0.66/L');
      expect(spokenUnitPrice(six, 'de'), '0,66 Euro pro Liter');
      expect(spokenUnitPrice(six, 'en'), '66 cents per litre');
      final one = _offer(volume: 1, unit: 'l', reference: 0.99);
      expect(formatUnitPrice(one, 'de'), isNull);
    });
  });

  group('dates', () {
    final saturday = DateTime(2026, 11, 14, 20);

    test('"Sa., 14. Nov." / "Sat, Nov 14" and the spoken date', () {
      expect(formatOfferDate(saturday, 'de'), 'Sa., 14. Nov.');
      expect(formatOfferDate(saturday, 'en'), 'Sat, Nov 14');
      expect(spokenOfferDate(saturday, 'de'), 'Samstag, 14. November');
      expect(spokenOfferDate(saturday, 'en'), 'Saturday, November 14');
      expect(offerValidUntil(_offer(to: saturday), 'de'), 'bis Sa., 14. Nov.');
      expect(offerValidUntil(_offer(to: saturday), 'en'), 'until Sat, Nov 14');
    });

    test('end label only within three calendar days, no warning words', () {
      final offer = _offer(to: saturday);
      String? at(DateTime now, String lang) =>
          offerEndsLabel(offer, lang, now: now);
      expect(at(DateTime(2026, 11, 14, 9), 'de'), 'endet heute');
      expect(at(DateTime(2026, 11, 13, 23), 'de'), 'endet morgen');
      expect(at(DateTime(2026, 11, 12), 'en'), 'ends Saturday');
      expect(at(DateTime(2026, 11, 11), 'de'), 'endet Samstag');
      expect(at(DateTime(2026, 11, 10), 'de'), isNull);
      expect(at(DateTime(2026, 11, 15), 'de'), isNull);
    });
  });

  test('store names follow the directory', () {
    expect(offerStoreName(_offer()), 'Lidl');
    expect(offerStoreName(_offer(retailer: 'aldi-sued')), 'Aldi Süd');
    expect(offerChainId(_offer(retailer: 'aldi-sued')), 'aldi-sued');
  });

  test('the product title does not repeat the brand', () {
    expect(
      offerProductTitle(_offer(brand: 'Milbona')),
      'Milbona Frische Vollmilch',
    );
    expect(
      offerProductTitle(_offer(brand: 'Milbona', product: 'Milbona Vollmilch')),
      'Milbona Vollmilch',
    );
  });

  test('distances: "120 m", "1,2 km" and spoken', () {
    expect(formatDistance(118, 'de').shown, '120 m');
    expect(formatDistance(118, 'de').spoken, '120 Meter');
    expect(formatDistance(1240, 'de').shown, '1,2 km');
    expect(formatDistance(1240, 'en').spoken, '1.2 kilometres');
  });

  group('OfferSummaryText', () {
    const summary = OfferSummary(
      chainId: 'lidl',
      storeName: 'Lidl',
      matched: 4,
      total: 11,
      savingsCents: 320,
    );

    test('head, detail and sentence in the mandatory wording', () {
      final de = offerSummaryText(summary, 'de');
      expect(de.head, '4 von 11 Artikeln diese Woche bei Lidl im Angebot');
      expect(
        de.detail,
        'ca. 3,20 € gespart · in deiner Region · Preise laut Händler',
      );
      expect(
        de.sentence,
        '4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € '
        'gespart, in deiner Region',
      );
      final en = offerSummaryText(summary, 'en');
      expect(en.head, '4 of 11 items on offer at Lidl this week');
      expect(
        en.detail,
        'about €3.20 saved · in your area · prices as stated by the retailer',
      );
    });

    test('without savings the second line keeps region and source only', () {
      const plain = OfferSummary(
        chainId: 'lidl',
        storeName: 'Lidl',
        matched: 1,
        total: 1,
      );
      final de = offerSummaryText(plain, 'de');
      expect(de.head, '1 von 1 Artikel diese Woche bei Lidl im Angebot');
      expect(de.detail, 'in deiner Region · Preise laut Händler');
      expect(de.sentence, isNot(contains('gespart')));
    });
  });

  group('price taken from an offer', () {
    ShoppingItemModel item({double? price, String? retailer}) =>
        ShoppingItemModel(
          id: 'a',
          listId: 'l',
          name: 'Milch',
          createdAt: DateTime(2026, 11, 8),
          updatedAt: DateTime(2026, 11, 8),
          price: price,
          priceRetailer: retailer,
        );

    test('same price at the same market counts as taken', () {
      final offer = _offer();
      expect(
        isOfferPriceTaken(item(price: 0.99, retailer: 'Lidl'), offer),
        isTrue,
      );
      expect(
        isOfferPriceTaken(item(price: 0.99, retailer: 'lidl'), offer),
        isTrue,
      );
      expect(
        isOfferPriceTaken(item(price: 1.09, retailer: 'Lidl'), offer),
        isFalse,
      );
      expect(
        isOfferPriceTaken(item(price: 0.99, retailer: 'REWE'), offer),
        isFalse,
      );
      expect(isOfferPriceTaken(item(), offer), isFalse);
    });

    test('the item price stores the market as the directory spells it', () {
      final price = offerItemPrice(
        _offer(retailer: 'aldi-sued', volume: 1, unit: 'l'),
      );
      expect(price.price, 0.99);
      expect(price.retailer, 'Aldi Süd');
      expect(price.currency, 'EUR');
    });
  });

  group('display prefs', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ISO weeks', () {
      expect(weekKey(DateTime(2026, 11, 8)), '2026-W45');
      expect(weekKey(DateTime(2026, 11, 9)), '2026-W46');
      expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
      expect(weekKey(DateTime(2024, 12, 30)), '2025-W01');
    });

    test(
      'a declined offer holds until it ends, the week hide only that week',
      () {
        final now = DateTime(2026, 11, 10);
        final prefs = OfferDisplayPrefs.fromJson({
          'off': ['listSavings'],
          'summaryHiddenWeek': {'a': weekKey(now), 'b': '2026-W01'},
          'declined': {
            'x': {
              'offer': 7,
              'until': DateTime(2026, 11, 14).toIso8601String(),
            },
            'y': {'offer': 8, 'until': DateTime(2026, 11, 1).toIso8601String()},
          },
          'noStoreHintUntil': {'l': DateTime(2026, 11, 12).toIso8601String()},
        }, now);
        expect(prefs.isOn(OfferSurface.listSavings), isFalse);
        expect(prefs.isOn(OfferSurface.itemOffers), isTrue);
        expect(prefs.summaryHiddenWeek, {'a': weekKey(now)});
        expect(prefs.isDeclined('x', 7, now), isTrue);
        expect(prefs.isDeclined('x', 9, now), isFalse);
        expect(prefs.declined.containsKey('y'), isFalse);
        expect(prefs.noStoreHintUntil.keys, ['l']);
      },
    );

    test('Aldi of the region orders the market menu', () {
      expect(aldiForZip('79098'), 'aldi-sued');
      expect(aldiForZip('20095'), 'aldi-nord');
      expect(aldiForZip('50667'), 'aldi-sued');
      expect(popularChainIds(null), containsAll(['aldi-sued', 'aldi-nord']));
      expect(popularChainIds('79098').first, 'lidl');
    });
  });
}
