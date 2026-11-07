// Parsing an item must never invent words.
//
// A real list in the app ended up with "Tiefkühlerbsen erbsen" stored in the
// database: the model was asked to split "Tiefkühlerbsen" into name/amount/
// unit and returned an expanded name, which was then trusted. That name goes
// on to drive price lookups and purchase statistics, so the damage outlives
// the one row.
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/gemini_categorization_service.dart';

String clean(String input, String? parsed) =>
    GeminiCategorizationService.sanitizeParsedName(input, parsed);

void main() {
  group('rejects invented words', () {
    test('the Tiefkühlerbsen case', () {
      expect(clean('Tiefkühlerbsen', 'Tiefkühlerbsen erbsen'), 'Tiefkühlerbsen');
    });

    test('a completely different product is rejected', () {
      expect(clean('Olivenöl', 'Sonnenblumenöl'), 'Olivenöl');
    });

    test('an added descriptor is rejected', () {
      expect(clean('Milch', 'frische Vollmilch'), 'Milch');
    });
  });

  group('accepts legitimate extraction', () {
    test('quantity and unit are stripped', () {
      expect(clean('500g Hähnchen', 'Hähnchen'), 'Hähnchen');
      expect(clean('2 cups flour', 'flour'), 'flour');
      expect(clean('1kg Kartoffeln', 'Kartoffeln'), 'Kartoffeln');
    });

    test('case normalisation is allowed', () {
      expect(clean('tomaten', 'Tomaten'), 'Tomaten');
    });

    test('plural normalisation is allowed', () {
      expect(clean('3 Eier', 'Ei'), 'Ei');
    });

    test('a multi-word product survives intact', () {
      expect(clean('2 Rote Beete', 'Rote Beete'), 'Rote Beete');
    });
  });

  group('degenerate input', () {
    test('an empty parse falls back to the input', () {
      expect(clean('Brot', ''), 'Brot');
      expect(clean('Brot', null), 'Brot');
    });

    test('whitespace-only parse falls back', () {
      expect(clean('Brot', '   '), 'Brot');
    });
  });
}
