// The chain directory turns free text (list names, retailer names from
// offers and checkout) into one chain id, and counts private-label brands.
import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';

void main() {
  group('matchChain', () {
    test('finds the chain as a word in a list name', () {
      expect(matchChain('Lidl Wocheneinkauf'), 'lidl');
      expect(matchChain('Wocheneinkauf bei REWE'), 'rewe');
      expect(matchChain('Lidl-Einkauf'), 'lidl');
    });

    test('tolerates common typos', () {
      expect(matchChain('lidel'), 'lidl');
      expect(matchChain('Liddl'), 'lidl');
      expect(matchChain('Kauflnd'), 'kaufland');
      expect(matchChain('Kaufladn Samstag'), 'kaufland');
    });

    test('knows store formats and spellings of the same chain', () {
      expect(matchChain('REWE City'), 'rewe');
      expect(matchChain('Aldi Süd'), 'aldi-sued');
      expect(matchChain('ALDI SÜD'), 'aldi-sued');
      expect(matchChain('aldi sued'), 'aldi-sued');
      expect(matchChain('Aldi-Nord'), 'aldi-nord');
      expect(matchChain('Netto MD'), 'netto-marken-discount');
      expect(matchChain('Netto Marken-Discount'), 'netto-marken-discount');
      expect(matchChain('PENNY'), 'penny');
      expect(matchChain('E-Center'), 'edeka');
    });

    test('two different chains are no answer', () {
      expect(matchChain('Kaufland/Lidl'), isNull);
      expect(matchChain('Rewe oder Edeka'), isNull);
    });

    test('plain Aldi is ambiguous between Süd and Nord', () {
      expect(matchChain('Aldi'), isNull);
    });

    test('a text naming both Aldis is no answer', () {
      expect(matchChain('Aldi Süd/Nord'), isNull);
      expect(matchChain('Aldi Nord oder Süd'), isNull);
      expect(matchChain('Aldi Süd Nordstadt'), 'aldi-sued');
    });

    test('names that are also ordinary words or first names are marked', () {
      // The name still matches; the decision policy treats it as weak.
      expect(matchChain('Penny Geburtstag'), 'penny');
      expect(StoreChainDirectory.byId('penny')!.nameIsCommonWord, isTrue);
      expect(StoreChainDirectory.byId('globus')!.nameIsCommonWord, isTrue);
      expect(StoreChainDirectory.byId('norma')!.nameIsCommonWord, isTrue);
      expect(StoreChainDirectory.byId('lidl')!.nameIsCommonWord, isFalse);
    });

    test('ordinary words are no chain', () {
      expect(matchChain('Grillabend'), isNull);
      expect(matchChain('Nachkauf'), isNull);
      expect(matchChain('Family Dinner'), isNull);
      expect(matchChain('Penne Abend'), isNull);
      expect(matchChain(''), isNull);
    });

    test('does not find a chain inside another word', () {
      expect(matchChain('Lidlaner'), isNull);
    });
  });

  group('privateLabelHits', () {
    test('counts items of a chain brand', () {
      expect(privateLabelHits(['Milbona Joghurt'])['lidl'], 1);
      expect(
        privateLabelHits(['Milbona Joghurt', 'Pilos Butter', 'Bananen']),
        {'lidl': 2},
      );
    });

    test('counts each item once per chain', () {
      expect(privateLabelHits(['Milbona Pilos Mix']), {'lidl': 1});
    });

    test('a brand two chains share counts for both', () {
      expect(privateLabelHits(['Gut & Günstig Milch']), {
        'edeka': 1,
        'netto-marken-discount': 1,
      });
    });

    test('ja! needs its exclamation mark', () {
      expect(privateLabelHits(['ja! Milch']), {'rewe': 1});
      expect(privateLabelHits(['Ja Milch']), isEmpty);
    });

    test('multi-word brands match as a phrase', () {
      expect(privateLabelHits(['K-Classic Nudeln'])['kaufland'], 1);
      expect(privateLabelHits(['Moser Roth Schokolade'])['aldi-sued'], 1);
      expect(privateLabelHits(['Roth Moser']), isEmpty);
    });

    test('Belbake is Lidl\'s baking brand', () {
      expect(privateLabelHits(['Belbake Mehl']), {'lidl': 1});
    });

    test('a first name is no brand', () {
      expect(privateLabelHits(['Geschenk Saskia']), isEmpty);
    });

    test('no brands, no hits', () {
      expect(privateLabelHits(['Milch', 'Brot']), isEmpty);
      expect(privateLabelHits(const []), isEmpty);
    });
  });

  group('dominantChain', () {
    test('the chain most of the names point to', () {
      expect(dominantChain(['Lidl', 'LIDL', 'REWE']), 'lidl');
    });

    test('a tie or no known chain is no answer', () {
      expect(dominantChain(['Lidl', 'REWE']), isNull);
      expect(dominantChain(['Wochenmarkt']), isNull);
      expect(dominantChain(const []), isNull);
    });
  });

  group('StoreChainDirectory', () {
    test('every chain id is a grocery retailer the offer source knows', () {
      for (final chain in StoreChainDirectory.chains) {
        expect(
          OfferPriceService.groceryRetailers,
          contains(chain.id),
          reason: chain.id,
        );
      }
    });

    test('ids are unique and resolvable', () {
      final ids = [for (final c in StoreChainDirectory.chains) c.id];
      expect(ids.toSet().length, ids.length);
      expect(StoreChainDirectory.byId('lidl')?.displayName, 'Lidl');
      expect(StoreChainDirectory.byId('unknown'), isNull);
    });

    test('brand colours follow the D2 start values', () {
      expect(StoreChainDirectory.byId('lidl')!.brandColor!.toARGB32(),
          0xFF0050AA);
      expect(StoreChainDirectory.byId('rewe')!.brandColor!.toARGB32(),
          0xFFCC071E);
      expect(StoreChainDirectory.byId('edeka')!.brandColor!.toARGB32(),
          0xFFFFD400);
    });

    test('light dots get an outline in light mode, very dark ones in dark '
        'mode', () {
      bool outlined(String id, Brightness b) =>
          StoreChainDirectory.byId(id)!.needsOutlineOn(b);

      expect(outlined('edeka', Brightness.light), isTrue);
      expect(outlined('netto-marken-discount', Brightness.light), isTrue);
      expect(outlined('lidl', Brightness.light), isFalse);
      expect(outlined('aldi-sued', Brightness.light), isFalse);

      expect(outlined('aldi-sued', Brightness.dark), isTrue);
      expect(outlined('edeka', Brightness.dark), isFalse);
      expect(outlined('lidl', Brightness.dark), isFalse);
      expect(outlined('norma', Brightness.dark), isFalse);
    });

    test('every chain matches its own display name', () {
      for (final chain in StoreChainDirectory.chains) {
        expect(matchChain(chain.displayName), chain.id, reason: chain.id);
      }
    });
  });
}
