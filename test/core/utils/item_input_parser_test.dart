import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/utils/item_input_parser.dart';

void main() {
  void expectItem(
    String input,
    String name,
    double quantity, {
    String? unit,
    String? note,
    bool? given,
    String lang = 'de',
  }) {
    final p = parseSingleItem(input, lang: lang);
    expect(p, isNotNull, reason: input);
    expect(p!.name, name, reason: input);
    expect(p.quantity, quantity, reason: input);
    expect(p.unit, unit, reason: input);
    expect(p.note, note, reason: input);
    if (given != null) expect(p.quantityGiven, given, reason: input);
  }

  group('quantity first or last', () {
    for (final s in [
      '2 Milch',
      'Milch 2',
      '2x Milch',
      '2 x Milch',
      '2× Milch',
      'Milch x2',
      'Milch 2x',
      '  2   Milch  ',
    ]) {
      test(s, () => expectItem(s, 'Milch', 2, given: true));
    }
  });

  group('units', () {
    for (final s in [
      '500 g Mehl',
      '500g Mehl',
      'Mehl 500 g',
      'Mehl 500g',
      '500 gr Mehl',
    ]) {
      test(s, () => expectItem(s, 'Mehl', 500, unit: 'g'));
    }
    for (final s in [
      '1,5 l Milch',
      '1.5l Milch',
      '1,5 L Milch',
      'Milch 1,5 l',
    ]) {
      test(s, () => expectItem(s, 'Milch', 1.5, unit: 'l'));
    }
    test(
      'kg',
      () => expectItem('1 kg Kartoffeln', 'Kartoffeln', 1, unit: 'kg'),
    );
    test('Pck.', () => expectItem('2 Pck. Butter', 'Butter', 2, unit: 'pack'));
    test(
      'Packungen',
      () => expectItem('2 Packungen Butter', 'Butter', 2, unit: 'pack'),
    );
    test(
      'Dosen after',
      () => expectItem('Tomaten 2 Dosen', 'Tomaten', 2, unit: 'can'),
    );
    test(
      'Flaschen',
      () => expectItem('3 Flaschen Wasser', 'Wasser', 3, unit: 'bottle'),
    );
    test(
      'Bund',
      () => expectItem('1 Bund Bananen', 'Bananen', 1, unit: 'bunch'),
    );
    test(
      'Stück is no unit',
      () => expectItem('3 Stück Äpfel', 'Äpfel', 3, unit: null),
    );
  });

  group('number words and fractions', () {
    test('ein', () => expectItem('ein Brot', 'Brot', 1, given: true));
    test('eine', () => expectItem('eine Gurke', 'Gurke', 1, given: true));
    test('zwei', () => expectItem('zwei Gurken', 'Gurken', 2));
    test('zwölf', () => expectItem('zwölf Eier', 'Eier', 12));
    test('ein Dutzend', () => expectItem('ein Dutzend Eier', 'Eier', 12));
    test('Dutzend', () => expectItem('Dutzend Eier', 'Eier', 12));
    test('a dozen', () => expectItem('a dozen eggs', 'eggs', 12, lang: 'en'));
    test(
      '1/2 kg',
      () => expectItem('1/2 kg Hackfleisch', 'Hackfleisch', 0.5, unit: 'kg'),
    );
    test('½ l', () => expectItem('½ l Sahne', 'Sahne', 0.5, unit: 'l'));
    test(
      '1 1/2 kg',
      () => expectItem('1 1/2 kg Äpfel', 'Äpfel', 1.5, unit: 'kg'),
    );
    test('1½ kg', () => expectItem('1½ kg Äpfel', 'Äpfel', 1.5, unit: 'kg'));
    test('¼', () => expectItem('¼ Wassermelone', 'Wassermelone', 0.25));
    test('eine halbe', () => expectItem('eine halbe Melone', 'Melone', 0.5));
  });

  group('notes and names that start with numbers', () {
    test(
      'note',
      () => expectItem('Milch (laktosefrei)', 'Milch', 1, note: 'laktosefrei'),
    );
    test(
      'quantity and note',
      () =>
          expectItem('2 Milch (laktosefrei)', 'Milch', 2, note: 'laktosefrei'),
    );
    test(
      'percent stays in the name',
      () => expectItem('Milch 1,5 %', 'Milch 1,5 %', 1, given: false),
    );
    test(
      'percent glued',
      () => expectItem('Milch 3,5%', 'Milch 3,5%', 1, given: false),
    );
    test('7Up', () => expectItem('7Up', '7Up', 1, given: false));
    test(
      'known name with leading number',
      () => expectItem('4 Jahreszeiten Pizza', '4 Jahreszeiten Pizza', 1),
    );
    test('plain name', () => expectItem('Milch', 'Milch', 1, given: false));
    test('zero is no quantity', () => expectItem('0 Milch', '0 Milch', 1));
    test(
      'huge is no quantity',
      () => expectItem('10000 Milch', '10000 Milch', 1),
    );
  });

  group('English', () {
    test('2 eggs', () => expectItem('2 eggs', 'eggs', 2, lang: 'en'));
    test('one onion', () => expectItem('one onion', 'onion', 1, lang: 'en'));
    test(
      '500 g flour',
      () => expectItem('500 g flour', 'flour', 500, unit: 'g', lang: 'en'),
    );
    test('milk x2', () => expectItem('milk x2', 'milk', 2, lang: 'en'));
  });

  group('nothing to add', () {
    for (final s in ['', '   ', '2', '2 kg', '½']) {
      test('"$s"', () => expect(parseSingleItem(s), isNull));
    }
  });

  group('several items', () {
    test('comma list', () {
      final items = parseItemInput('Milch, Eier, Butter');
      expect(items.map((i) => i.name), ['Milch', 'Eier', 'Butter']);
      expect(items.every((i) => i.quantity == 1), isTrue);
    });
    test('lines', () {
      expect(parseItemInput('Milch\nEier\nButter').length, 3);
    });
    test('decimal comma does not split', () {
      final items = parseItemInput('1,5 l Milch, 2 Eier');
      expect(items.length, 2);
      expect(items[0].name, 'Milch');
      expect(items[0].quantity, 1.5);
      expect(items[0].unit, 'l');
      expect(items[1].name, 'Eier');
      expect(items[1].quantity, 2);
    });
    test('a lone quantity part is dropped', () {
      final items = parseItemInput('Mehl, 500 g');
      expect(items.map((i) => i.name), ['Mehl']);
    });
    test('comma inside brackets does not split', () {
      final items = parseItemInput('Milch (fettarm, laktosefrei)');
      expect(items.single.note, 'fettarm, laktosefrei');
    });
  });

  group('properties', () {
    const samples = [
      '2 Milch',
      'Milch 2',
      '500 g Mehl',
      'eine halbe Melone',
      '7Up',
      'Milch (laktosefrei)',
      '1½ kg Äpfel',
      'Tomaten 2 Dosen',
      'a dozen eggs',
    ];
    test('names are never empty and quantities positive', () {
      for (final s in samples) {
        final p = parseSingleItem(s)!;
        expect(p.name.trim(), isNotEmpty, reason: s);
        expect(p.quantity, greaterThan(0), reason: s);
      }
    });
    test('parsing the display form again gives the same item', () {
      for (final s in samples) {
        final p = parseSingleItem(s)!;
        final again = parseSingleItem(p.displayInput)!;
        expect(again.name, p.name, reason: s);
        expect(again.quantity, p.quantity, reason: s);
        expect(again.unit, p.unit, reason: s);
      }
    });
    test('same item ignores case and treats no unit as pieces', () {
      expect(
        sameItem(parseSingleItem('milch')!, parseSingleItem('2 Milch')!),
        isTrue,
      );
      expect(
        sameItem(parseSingleItem('Mehl')!, parseSingleItem('500 g Mehl')!),
        isFalse,
      );
    });
  });
}
