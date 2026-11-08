// Layout matrix (widths 320-440 pt, text 1.0-3.1, bold, dark, contrast) for
// the offer slots, the B building blocks and the screens "Markt wählen" and
// "Angebot" (angebote.md 3.10): no overflow, no clipped text, in German,
// where the texts are longest.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_card.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_count_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/store_chip.dart';
import 'package:shoply/presentation/screens/offers/offer_detail_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/store_picker_screen.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_summary_card.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

import '../../../screens/offers/offer_test_harness.dart';
import '../../layout_matrix.dart';

/// [child] in German with the providers of [overrides].
Widget _de(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: const Locale('de'),
          delegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          child: child,
        ),
      ),
    );

/// Inside a screen-wide column, as the hosts place the slots.
Widget _inScreen(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final milk = testItem('a', 'Haferdrink ungesüßt Barista Edition');
  final long = testOffer(
    product: 'Haferdrink Barista Edition ungesüßt mit Calcium',
    brand: 'Vemondo',
    volume: 1,
    referencePrice: 1.29,
    price: 1.29,
    oldPrice: 1.79,
  );
  final snapshot = testSnapshot({milk.name: long});
  final items = [
    milk,
    for (var i = 0; i < 10; i++) testItem('x$i', 'Artikel $i'),
  ];

  layoutMatrix('StoreChip: market, suggestion, none', (context) {
    return Wrap(
      spacing: 8,
      children: [
        _de(const StoreChip(listId: testListId), overrides: offersOn()),
        _de(
          const StoreChip(listId: testListId),
          overrides: offersOn(chainId: 'aldi-sued', confirmed: false),
        ),
        _de(
          const StoreChip(listId: testListId),
          overrides: offersOn(chainId: null),
        ),
      ],
    );
  });

  layoutMatrix('StoreMark sizes and StoreLabel', (context) {
    return _de(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StoreMark.chain('lidl'),
          StoreMark.chain('aldi-sued', size: 20),
          StoreMark.chain('edeka', size: 28),
          StoreMark.custom('Bio Kaiser', size: 28),
          const StoreLabel(chainId: 'netto-marken-discount', name: 'Netto'),
        ],
      ),
    );
  });

  layoutMatrix('OfferPriceTag small and large', (context) {
    return _de(
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OfferPriceTag(price: '0,99 €'),
          OfferPriceTag(price: '0,99 €', store: 'Aldi Süd'),
          OfferPriceTag(price: '12,49 €', uncertain: true),
          OfferPriceTag(price: '0,99 €', size: OfferPriceTagSize.large),
        ],
      ),
    );
  });

  layoutMatrix(
    'ItemRow with the offer pill (S3)',
    (context) {
      return _de(
        InsetSection(
          children: [
            ItemRow(
              title: milk.name,
              subtitle: '2 Stück',
              onToggle: (_) {},
              onTap: () {},
              trailing: ItemOfferBadge(listId: testListId, item: milk),
            ),
            ItemRow(
              title: milk.name,
              onToggle: (_) {},
              size: ItemRowSize.large,
              trailing: ItemOfferBadge(
                listId: testListId,
                item: milk,
                compact: true,
              ),
            ),
          ],
        ),
        overrides: offersOn(snapshot: snapshot, items: items),
      );
    },
    scrollable: true,
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(find.text('1,29 €'), findsWidgets);
    },
  );

  layoutMatrix(
    'ItemOfferCard (S4)',
    (context) {
      return _inScreen(
        _de(
          ItemOfferCard(listId: testListId, item: milk),
          overrides: offersOn(snapshot: snapshot, items: items),
        ),
      );
    },
    scrollable: true,
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(find.text('ANGEBOT'), findsWidgets);
    },
  );

  layoutMatrix('OfferRow compact and full', (context) {
    return _de(
      InsetSection(
        children: [
          OfferRow(
            compact: true,
            title: 'Vemondo Haferdrink Barista Edition ungesüßt mit Calcium',
            lines: const ['Lidl · 1 l · bis Sa.'],
            price: '1,29 €',
            symbol: Icons.local_drink_outlined,
            semanticLabel: 'Haferdrink',
            onTap: () {},
          ),
          OfferRow(
            title: 'Weidemilch 3,8 %',
            lines: const [
              '1 l · 0,99 €/l',
              'laut Händler statt 1,19 €',
              'endet morgen',
            ],
            price: '0,99 €',
            uncertain: true,
            semanticLabel: 'Weidemilch',
            onTap: () {},
          ),
        ],
      ),
    );
  }, scrollable: true);

  layoutMatrix(
    'OfferSuggestionsBar (S6)',
    (context) {
      return _inScreen(
        _de(
          const OfferSuggestionsBar(listId: testListId, query: '2 Haferdrink'),
          overrides: offersOn(suggestions: [long, testOffer(broad: true)]),
        ),
      );
    },
    scrollable: true,
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(
        find.text('Vemondo Haferdrink Barista Edition ungesüßt mit Calcium'),
        findsWidgets,
      );
    },
  );

  layoutMatrix('OfferSummaryCard list and still', (context) {
    return _inScreen(
      _de(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OfferSummaryCard(
              head: '4 von 11 Artikeln diese Woche bei Aldi Süd im Angebot',
              detail:
                  'ca. 3,20 € gespart · in deiner Region · Preise laut Händler',
              semanticLabel: 'Satz',
              onHideWeek: () {},
              onNever: () {},
            ),
            const SizedBox(height: 14),
            const OfferSummaryCard(
              head: '4 von 11 Artikeln diese Woche bei Aldi Süd im Angebot',
              detail: 'in deiner Region · Preise laut Händler',
              semanticLabel: 'Satz',
            ),
          ],
        ),
      ),
    );
  }, scrollable: true);

  layoutMatrix(
    'ListOfferSummary (S7)',
    (context) {
      return _inScreen(
        _de(
          const ListOfferSummary(listId: testListId),
          overrides: offersOn(snapshot: snapshot, items: items),
        ),
      );
    },
    scrollable: true,
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(
        find.textContaining('diese Woche bei Lidl im Angebot'),
        findsWidgets,
      );
    },
  );

  layoutMatrix(
    'ListOfferCountBadge (S8)',
    (context) {
      return _de(
        const ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: EdgeInsets.all(10),
            child: ListOfferCountBadge(listId: testListId),
          ),
        ),
        overrides: [
          ...offersOn(),
          cachedStoreOfListProvider.overrideWith((ref, id) => 'lidl'),
          listOfferBadgeCountProvider.overrideWith((ref, id) async => 12),
        ],
      );
    },
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(find.text('12 Angebote'), findsWidgets);
    },
  );

  layoutMatrix(
    'OffersSourceFootnote',
    (context) => _de(const OffersSourceFootnote()),
    scrollable: true,
  );

  layoutMatrix(
    'StorePickerScreen (S2)',
    (context) {
      return SizedBox.expand(
        child: _de(
          const StorePickerScreen(listId: testListId),
          overrides: [
            ...offersOn(),
            listStoreHistoryProvider.overrideWith((ref, id) async => ['rewe']),
            nearbyStoreOptionsProvider.overrideWith(
              (ref) async => const [
                NearbyStoreOption(
                  chainId: 'aldi-sued',
                  distanceMeters: 1240,
                  street: 'Kaiser-Joseph-Straße',
                ),
              ],
            ),
          ],
        ),
      );
    },
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(
        find.text('Kaiser-Joseph-Straße · 1,2 km', skipOffstage: false),
        findsWidgets,
      );
    },
  );

  layoutMatrix(
    'OfferDetailScreen (S5)',
    (context) {
      return SizedBox.expand(
        child: _de(
          const OfferDetailScreen(
            offerId: 7,
            listId: testListId,
            itemId: 'a',
            mode: OfferDetailMode.take,
          ),
          overrides: [
            ...offersOn(snapshot: snapshot, items: items),
            cachedMoreOffersProvider.overrideWith(
              (ref, key) => [long, testOffer(id: 9, broad: true)],
            ),
            offerByIdProvider.overrideWith((ref, key) => long),
          ],
        ),
      );
    },
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Vemondo Haferdrink Barista Edition ungesüßt mit Calcium',
          skipOffstage: false,
        ),
        findsWidgets,
      );
    },
  );

  layoutMatrix(
    'OfferDetailScreen, similar product and ended',
    (context) {
      final ended = testOffer(broad: true, validTo: DateTime.utc(2026, 1, 2));
      return SizedBox.expand(
        child: _de(
          const OfferDetailScreen(offerId: 7, listId: testListId, itemId: 'a'),
          overrides: [
            ...offersOn(items: items),
            offerByIdProvider.overrideWith((ref, key) => ended),
          ],
        ),
      );
    },
    afterPump: (tester) async {
      // Saved choices and the market load over a few frames.
      await tester.pumpAndSettle();
      expect(
        find.text('Milbona Frische Vollmilch 3,5 %', skipOffstage: false),
        findsWidgets,
      );
    },
  );
}
