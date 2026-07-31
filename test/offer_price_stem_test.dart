// Guards the query-broadening used when a price lookup finds too few stores.
//
// The stem decides which offers may be matched to an item, so getting it
// wrong shows up directly as a wrong price in the app. Two regressions this
// pins down:
//   * a 5-character *prefix* turned "Olivenöl" into "olive", which then
//     matched a jar of olives;
//   * splitting at the head noun instead ("vollmilch" -> "milch") drifts the
//     other way and prices fat-free milk as whole milk.
// A single word is therefore left untouched, which makes searchOffers skip
// broadening entirely — it only broadens when the stem differs from the query.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/offer_price_service.dart';

void main() {
  final service = OfferPriceService.instance;
  String? stem(String q) => service.debugGenericTerm(q.toLowerCase());

  group('single words are never shortened', () {
    test('Olivenöl keeps its head noun instead of becoming "olive"', () {
      expect(stem('Olivenöl'), 'olivenöl');
    });

    test('Schweinerippe is not truncated to a prefix', () {
      expect(stem('Schweinerippe'), 'schweinerippe');
    });

    test('Vollkornbrot is not broadened to any bread', () {
      expect(stem('Vollkornbrot'), 'vollkornbrot');
    });

    test('Butter stays Butter', () => expect(stem('Butter'), 'butter'));
    test('Oliven stays Oliven', () => expect(stem('Oliven'), 'oliven'));
  });

  group('qualifiers and quantities are stripped, head word kept', () {
    test('brand prefix drops away', () {
      expect(stem('Golden Toast'), 'toast');
    });

    test('bio + percentage drop away, product stays specific', () {
      // "bio" is a stopword and "3,5%" a quantity, leaving one real word —
      // which must survive intact rather than collapsing to "milch".
      expect(stem('Bio Vollmilch 3,5%'), 'vollmilch');
    });

    test('multi-word keeps the last, most specific word', () {
      expect(stem('Frische Vollmilch'), 'vollmilch');
    });
  });

  test('nothing meaningful left yields null', () {
    expect(stem('bio frisch'), isNull);
  });
}
