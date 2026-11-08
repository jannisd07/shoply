// Which item names of a list the 6-h offer sync asks the source for: one
// search per distinct name, short real names like "Ei" included, pantry
// staples too (it is on the list, so its offer counts), capped per list.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

void main() {
  group('ListOfferSync.namesToCheck', () {
    test('skips one-letter names but keeps short real names like "Ei"', () {
      expect(ListOfferSync.namesToCheck(['Ei', 'X', 'Milch']), ['Ei', 'Milch']);
    });

    test('keeps pantry staples, unlike recipe ingredient matching', () {
      expect(ListOfferSync.namesToCheck(['Salz', 'Wasser']), ['Salz', 'Wasser']);
    });

    test('de-duplicates case-insensitively, keeping the first spelling', () {
      expect(
        ListOfferSync.namesToCheck(
          ['Tomaten', 'tomaten', ' TOMATEN ', 'Zwiebeln'],
        ),
        ['Tomaten', 'Zwiebeln'],
      );
    });

    test('caps at maxItems, preserving order', () {
      final names = ListOfferSync.namesToCheck([
        for (var i = 0; i < 40; i++) 'Artikel$i',
      ]);

      expect(names, hasLength(ListOfferSync.maxItems));
      expect(names.first, 'Artikel0');
      expect(names.last, 'Artikel${ListOfferSync.maxItems - 1}');
    });

    test('empty input yields empty output', () {
      expect(ListOfferSync.namesToCheck(const []), isEmpty);
    });
  });
}
