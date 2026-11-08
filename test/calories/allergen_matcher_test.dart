import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/services/allergen_matcher.dart';

void main() {
  group('resolving what the user entered', () {
    test('accepts stored ids, German labels, keywords and English names', () {
      expect(AllergenMatcher.resolve('nuts'), AllergyType.nuts);
      expect(AllergenMatcher.resolve('Nüsse'), AllergyType.nuts);
      expect(AllergenMatcher.resolve('nüsse'), AllergyType.nuts);
      expect(AllergenMatcher.resolve('Milch'), AllergyType.milk);
      expect(AllergenMatcher.resolve('lactose'), AllergyType.lactose);
      expect(AllergenMatcher.resolve('Gluten'), AllergyType.gluten);
      expect(AllergenMatcher.resolve('peanut'), AllergyType.peanuts);
      expect(AllergenMatcher.resolve('Erdnussallergie'), AllergyType.peanuts);
      expect(AllergenMatcher.resolve('dairy'), AllergyType.milk);
      expect(AllergenMatcher.resolve('Kiwi'), isNull);
    });
  });

  group('German compounds and plurals', () {
    test('Nüsse finds Haselnuss, Walnüsse and Haselnusskerne', () {
      const m = AllergenMatcher(['Nüsse']);
      expect(m.contains('Haselnuss'), isTrue);
      expect(m.contains('gehackte Walnüsse'), isTrue);
      expect(m.contains('200 g Haselnusskerne'), isTrue);
      expect(m.contains('Mandeln'), isTrue);
      expect(m.contains('Muskatnuss'), isFalse);
      expect(m.contains('Kokosnuss'), isFalse);
      expect(m.contains('Butternut-Kürbis'), isFalse);
    });

    test('Milch finds Vollmilch but not plant drinks or peanut butter', () {
      const m = AllergenMatcher(['milk']);
      expect(m.contains('Vollmilch'), isTrue);
      expect(m.contains('Milchschokolade'), isTrue);
      expect(m.contains('Bergkäse'), isTrue);
      expect(m.contains('Schlagsahne'), isTrue);
      expect(m.contains('Butter'), isTrue);
      expect(m.contains('Hafermilch'), isFalse);
      expect(m.contains('Kokosmilch'), isFalse);
      expect(m.contains('Erdnussbutter'), isFalse);
      expect(m.contains('coconut milk'), isFalse);
      expect(m.contains('whole milk'), isTrue);
    });

    test('Gluten finds Weizenmehl, Dinkel and pasta but not Buchweizen', () {
      const m = AllergenMatcher(['Gluten']);
      expect(m.contains('Weizenmehl Type 405'), isTrue);
      expect(m.contains('Dinkelvollkornmehl'), isTrue);
      expect(m.contains('Spaghetti'), isTrue);
      expect(m.contains('Semmelbrösel'), isTrue);
      expect(m.contains('wheat flour'), isTrue);
      expect(m.contains('Buchweizen'), isFalse);
      expect(m.contains('Reismehl'), isFalse);
    });

    test('short words only match whole words', () {
      const m = AllergenMatcher(['eggs']);
      expect(m.contains('2 Eier'), isTrue);
      expect(m.contains('1 Ei'), isTrue);
      expect(m.contains('Eigelb'), isTrue);
      expect(m.contains('Rührei'), isTrue);
      expect(m.contains('Reis'), isFalse);
      expect(m.contains('Haferbrei'), isFalse);
      expect(m.contains('Weizen'), isFalse);
    });

    test('peanuts are found in German and English', () {
      const m = AllergenMatcher(['peanuts']);
      expect(m.contains('Erdnüsse, geröstet'), isTrue);
      expect(m.contains('Erdnussbutter'), isTrue);
      expect(m.contains('peanut butter'), isTrue);
    });
  });

  test('free-text allergies still match their own word and plural', () {
    const m = AllergenMatcher(['Kiwi']);
    expect(m.contains('2 Kiwis'), isTrue);
    expect(m.contains('Apfel'), isFalse);
  });

  test('reports every matching allergy once with the matched word', () {
    const m = AllergenMatcher(['nuts', 'milk']);
    final hits = m.matches('Haselnuss-Milchschokolade');
    expect(hits.map((h) => h.allergy), ['nuts', 'milk']);
    expect(hits.first.type, AllergyType.nuts);
    expect(hits.first.matchedText, isNotEmpty);
  });

  test('checks a list of ingredients', () {
    const m = AllergenMatcher(['Nüsse']);
    expect(m.anyIngredient(['Mehl', 'Zucker', 'gemahlene Haselnüsse']), isTrue);
    expect(m.anyIngredient(['Mehl', 'Zucker']), isFalse);
    expect(const AllergenMatcher([]).contains('Haselnuss'), isFalse);
  });
}
