// The offer slots with content (angebote.md S1, S3, S4, S6, S7, S8): what
// they show, what a tap does, what VoiceOver hears, and that they stay
// empty without a region or with their switch off.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_card.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_count_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/store_chip.dart';
import 'package:shoply/presentation/screens/offers/offer_detail_screen.dart';
import 'package:shoply/presentation/screens/offers/store_picker_screen.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

import 'offer_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final milk = testItem('a', 'Milch');
  final bread = testItem('b', 'Brot');
  final offer = testOffer();
  final snapshot = testSnapshot({'Milch': offer});

  group('no region, offers off or kill switch: nothing is shown or asked', () {
    for (final (name, overrides) in [
      ('no region', offersOn(region: null)),
      (
        'module off',
        [
          ...offersOn(),
          offersAvailableProvider.overrideWithValue(false),
          offersVisibleForListProvider.overrideWith((ref, id) => false),
        ],
      ),
      (
        'kill switch',
        [...offersOn(), offersRemoteEnabledProvider.overrideWithValue(false)],
      ),
    ]) {
      testWidgets(name, (tester) async {
        var asked = 0;
        await pumpOffers(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemOfferBadge(listId: testListId, item: milk),
              ItemOfferCard(listId: testListId, item: milk),
              const ListOfferSummary(listId: testListId),
              const ListOfferCountBadge(listId: testListId),
              const OfferSuggestionsBar(listId: testListId, query: 'milch'),
            ],
          ),
          overrides: [
            ...overrides,
            listOfferSnapshotProvider.overrideWith((ref, id) {
              asked++;
              return snapshot;
            }),
            offerSuggestionsProvider.overrideWith((ref, request) async {
              asked++;
              return [offer];
            }),
            // The real counter; only its cache read is watched.
            cachedStoreOfListProvider.overrideWith((ref, id) => 'lidl'),
            listOfferSyncProvider.overrideWith(
              (ref) =>
                  _CachedSync({testListId: snapshot}, onRead: () => asked++),
            ),
          ],
        );
        final noRegion = name == 'no region';
        for (final type in [
          ItemOfferBadge,
          ItemOfferCard,
          if (!noRegion) ListOfferSummary,
          ListOfferCountBadge,
          if (!noRegion) OfferSuggestionsBar,
        ]) {
          expect(tester.getSize(find.byType(type)), Size.zero, reason: '$type');
        }
        // Without a region the list and the add field only say where to
        // set one (3.4); no offer, no number.
        expect(
          find.text('Für Angebote in deiner Region: Postleitzahl festlegen'),
          noRegion ? findsNWidgets(2) : findsNothing,
        );
        expect(find.textContaining('€'), findsNothing);
        expect(asked, 0, reason: 'no request to the offers source');
      });
    }
  });

  group('S3 ItemOfferBadge', () {
    testWidgets('shows the price and adds its sentence to the row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        Semantics(
          container: true,
          label: 'Milch',
          child: ItemOfferBadge(listId: testListId, item: milk),
        ),
        overrides: offersOn(snapshot: snapshot, items: [milk, bread]),
      );
      expect(find.text('0,99 €'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('im Angebot 0,99 Euro laut Händler')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a tap opens the offer to take its price', (tester) async {
      await pumpOffers(
        tester,
        ItemOfferBadge(listId: testListId, item: milk),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      final target = tester.getSize(find.byType(GestureDetector).first);
      expect(target.height, greaterThanOrEqualTo(44));
      expect(target.width, greaterThanOrEqualTo(44));
      await tester.tap(find.text('0,99 €'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      expect(find.text('Preis übernehmen'), findsOneWidget);
    });

    testWidgets('compact (shopping mode) is not tappable on its own', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        ItemOfferBadge(listId: testListId, item: milk, compact: true),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      expect(find.text('0,99 €'), findsOneWidget);
      await tester.tap(find.text('0,99 €'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsNothing);
    });

    // The call Teil A makes in its list and shopping-mode rows (request
    // A-C1 in the BAB1 report).
    Widget row({required bool shopping}) => Consumer(
      builder: (context, ref, _) {
        final extras = itemOfferRowExtras(
          context,
          ref,
          listId: testListId,
          item: milk,
          shoppingMode: shopping,
        );
        return ItemRow(
          title: 'Milch',
          onToggle: (_) {},
          size: shopping ? ItemRowSize.large : ItemRowSize.regular,
          trailing: ItemOfferBadge(
            listId: testListId,
            item: milk,
            compact: shopping,
          ),
          trailingSemanticsLabel: extras?.semanticsLabel,
          trailingActions: extras?.actions ?? const {},
          contextMenuItems: extras?.menuItems ?? const [],
        );
      },
    );

    testWidgets('row extras: one VoiceOver stop with "Angebot ansehen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        row(shopping: false),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      final label = find.bySemanticsLabel(
        RegExp('Milch.*im Angebot 0,99 Euro laut Händler'),
      );
      expect(label, findsOneWidget);
      expect(
        find.bySemanticsLabel('im Angebot 0,99 Euro laut Händler'),
        findsNothing,
        reason: 'the pill is no second stop',
      );
      tester.semantics.customAction(
        find.semantics.byLabel(
          RegExp('Milch.*im Angebot 0,99 Euro laut Händler'),
        ),
        CustomSemanticsAction(label: 'Angebot ansehen'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      handle.dispose();
    });

    testWidgets('row extras in shopping mode: long press "Angebot ansehen"', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        row(shopping: true),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      await tester.longPress(find.text('Milch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Angebot ansehen'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
    });

    testWidgets('row extras are null while the pill shows nothing', (
      tester,
    ) async {
      ItemOfferRowExtras? seen;
      var built = false;
      await pumpOffers(
        tester,
        Consumer(
          builder: (context, ref, _) {
            built = true;
            seen = itemOfferRowExtras(
              context,
              ref,
              listId: testListId,
              item: bread,
            );
            return const SizedBox.shrink();
          },
        ),
        overrides: offersOn(snapshot: snapshot, items: [bread]),
      );
      expect(built, isTrue);
      expect(seen, isNull);
    });

    testWidgets('a similar product carries the question mark sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        Semantics(
          container: true,
          child: ItemOfferBadge(listId: testListId, item: milk),
        ),
        overrides: offersOn(
          snapshot: testSnapshot({'Milch': testOffer(broad: true)}),
          items: [milk],
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('ähnliches Produkt im Angebot')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('nothing without a region, for a checked item, or when off', (
      tester,
    ) async {
      final checked = testItem('a', 'Milch', checked: true);
      for (final overrides in [
        offersOn(snapshot: snapshot, items: [milk], region: null),
        offersOn(snapshot: snapshot, items: [milk], chainId: null),
      ]) {
        await pumpOffers(
          tester,
          ItemOfferBadge(listId: testListId, item: milk),
          overrides: overrides,
        );
        expect(tester.getSize(find.byType(ItemOfferBadge)), Size.zero);
      }
      await pumpOffers(
        tester,
        ItemOfferBadge(listId: testListId, item: checked),
        overrides: offersOn(snapshot: snapshot, items: [checked]),
      );
      expect(tester.getSize(find.byType(ItemOfferBadge)), Size.zero);

      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount): '{"off":["itemOffers"]}',
      });
      await pumpOffers(
        tester,
        ItemOfferBadge(listId: testListId, item: milk),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      expect(tester.getSize(find.byType(ItemOfferBadge)), Size.zero);
    });

    testWidgets('"Nicht dieses Angebot" hides the offer for the item', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount):
            '{"declined":{"a":{"offer":7,"until":"2099-12-31T00:00:00.000"}}}',
      });
      await pumpOffers(
        tester,
        ItemOfferBadge(listId: testListId, item: milk),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      expect(find.text('0,99 €'), findsNothing);
    });
  });

  group('S4 ItemOfferCard', () {
    testWidgets('kicker, market and price, product, "laut Händler statt"', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        ItemOfferCard(listId: testListId, item: milk),
        overrides: offersOn(snapshot: snapshot, items: [milk]),
      );
      expect(find.text('ANGEBOT'), findsOneWidget);
      expect(find.text('Lidl · 0,99 €'), findsOneWidget);
      expect(find.text('Milbona Frische Vollmilch 3,5 %, 1 l'), findsOneWidget);
      expect(find.textContaining('laut Händler statt 1,19 €'), findsOneWidget);
      expect(find.textContaining('bis Sa., 14. Nov.'), findsOneWidget);
      expect(find.text('Preis übernommen'), findsNothing);
      final link = tester.getSize(
        find
            .ancestor(
              of: find.text('Angebot ansehen'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(link.height, greaterThanOrEqualTo(44));

      await tester.tap(find.text('Angebot ansehen'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
    });

    testWidgets('"Preis übernommen" once the item has the offer price', (
      tester,
    ) async {
      final priced = testItem('a', 'Milch', price: 0.99, retailer: 'Lidl');
      await pumpOffers(
        tester,
        ItemOfferCard(listId: testListId, item: priced),
        overrides: offersOn(snapshot: snapshot, items: [priced]),
      );
      expect(find.text('Preis übernommen'), findsOneWidget);
    });

    testWidgets('nothing without an offer', (tester) async {
      await pumpOffers(
        tester,
        ItemOfferCard(listId: testListId, item: bread),
        overrides: offersOn(snapshot: snapshot, items: [bread]),
      );
      expect(tester.getSize(find.byType(ItemOfferCard)), Size.zero);
    });
  });

  group('S8 ListOfferCountBadge', () {
    List<Override> counted({List<String> open = const ['Milch', 'Brot']}) => [
      ...offersOn(),
      cachedStoreOfListProvider.overrideWith((ref, id) => 'lidl'),
      cachedOpenItemsProvider.overrideWith(
        (ref, id) => [
          for (final name in open) testItem(name.toLowerCase(), name),
        ],
      ),
      listOfferSyncProvider.overrideWith(
        (ref) => _CachedSync({
          testListId: testSnapshot({
            'Milch': offer,
            'Brot': testOffer(id: 8, product: 'Bauernbrot'),
          }),
        }),
      ),
    ];

    testWidgets('"2 Angebote" from the cache, said as a sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        const ListOfferCountBadge(listId: testListId),
        overrides: counted(),
      );
      expect(find.text('2 Angebote'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Artikel im Angebot'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('counts open items only, singular for one', (tester) async {
      await pumpOffers(
        tester,
        const ListOfferCountBadge(listId: testListId),
        overrides: counted(open: ['Milch']),
        locale: const Locale('en'),
      );
      expect(find.text('1 on offer'), findsOneWidget);
    });

    testWidgets('nothing without a region', (tester) async {
      await pumpOffers(
        tester,
        const ListOfferCountBadge(listId: testListId),
        overrides: [...counted(), ...offersOn(region: null)],
      );
      expect(tester.getSize(find.byType(ListOfferCountBadge)), Size.zero);
    });
  });

  group('S7 ListOfferSummary', () {
    final items = [
      milk,
      bread,
      for (var i = 0; i < 9; i++) testItem('x$i', 'Artikel $i'),
    ];

    testWidgets('two lines in the list, the sentence in one piece for '
        'VoiceOver', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: offersOn(snapshot: snapshot, items: items),
      );
      expect(
        find.text('1 von 11 Artikeln diese Woche bei Lidl im Angebot'),
        findsOneWidget,
      );
      expect(
        find.text('in deiner Region · Preise laut Händler'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '1 von 11 Artikeln diese Woche bei Lidl im Angebot, in deiner '
          'Region. Preise laut Händler',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final shopped in [testListId, 'other-list']) {
      testWidgets('shopping mode on $shopped: still card only for its list', (
        tester,
      ) async {
        await pumpOffers(
          tester,
          const ListOfferSummary(listId: testListId),
          overrides: [
            ...offersOn(snapshot: snapshot, items: items),
            shoppingModeSessionProvider.overrideWith(
              (ref) => ShoppingModeSession(
                listId: shopped,
                startedAt: DateTime(2026, 11, 9),
              ),
            ),
          ],
        );
        expect(
          find.text('1 von 11 Artikeln diese Woche bei Lidl im Angebot'),
          findsOneWidget,
        );
        final close = find.byWidgetPredicate(
          (w) => w is AvoIcon && w.icon == AvoIcons.xmark,
        );
        expect(close, shopped == testListId ? findsNothing : findsOneWidget);
      });
    }

    testWidgets('savings from 0,50 € with "ca."', (tester) async {
      final sale = testSnapshot({
        'Milch': testOffer(oldPrice: 2.00),
        'Brot': testOffer(id: 8, product: 'Brot', price: 1, oldPrice: 2.2),
      });
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: offersOn(snapshot: sale, items: items),
      );
      expect(
        find.text(
          'ca. 2,20 € gespart · in deiner Region · Preise laut Händler',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Diese Woche ausblenden" hides it with undo', (tester) async {
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: offersOn(snapshot: snapshot, items: items),
      );
      await tester.tap(
        find.byWidgetPredicate((w) => w is AvoIcon && w.icon == AvoIcons.xmark),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('diese Woche bei Lidl'), findsNothing);
      expect(
        find.text('Ersparnis-Zeile für diese Woche ausgeblendet'),
        findsOneWidget,
      );
      await tester.tap(find.text('Widerrufen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('diese Woche bei Lidl'), findsOneWidget);
    });

    testWidgets('offers found after opening wait for the next opening', (
      tester,
    ) async {
      final fresh = ListOfferSnapshot(
        chainId: 'lidl',
        zip: testRegion.zip,
        fetchedAt: DateTime(2100),
        offersByName: {'milch': offer},
      );
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: offersOn(snapshot: fresh, items: items),
      );
      expect(find.textContaining('im Angebot'), findsNothing);
    });

    const hint =
        'Für welchen Markt ist Wocheneinkauf? Dann siehst du dessen Angebote.';

    testWidgets('a list without a market asks which one, at most once a week', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 10, 9);
      List<Override> overrides() => [
        ...offersOn(snapshot: snapshot, items: items, chainId: null),
        offerClockProvider.overrideWithValue(() => now),
      ];
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: overrides(),
      );
      expect(find.text(hint), findsOneWidget);
      expect(find.text('Markt wählen'), findsOneWidget);

      // Opened again the same week: not again.
      now = DateTime(2026, 11, 13, 18);
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: overrides(),
      );
      expect(find.text(hint), findsNothing);

      // Next week it may ask once more.
      now = DateTime(2026, 11, 17, 9);
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: overrides(),
      );
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('closing the hint keeps it away for 7 days', (tester) async {
      var now = DateTime(2026, 11, 10, 9);
      List<Override> overrides() => [
        ...offersOn(snapshot: snapshot, items: items, chainId: null),
        offerClockProvider.overrideWithValue(() => now),
      ];
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: overrides(),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(HintRow),
              matching: find.byWidgetPredicate(
                (w) => w is GestureDetector && w.onTap != null,
              ),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);

      now = DateTime(2026, 11, 16, 9); // next week, but within 7 days
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: overrides(),
      );
      expect(find.text(hint), findsNothing);
    });

    testWidgets('no hint while the market of the list is still loading', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: [
          ...offersOn(snapshot: snapshot, items: items),
          storeGuessForListProvider.overrideWith(
            (ref, id) => Completer<StoreGuess?>().future,
          ),
        ],
      );
      expect(find.text(hint), findsNothing);
      expect(tester.getSize(find.byType(ListOfferSummary)), Size.zero);
    });

    testWidgets('nothing with "Ersparnis in der Liste" off', (tester) async {
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount): '{"off":["listSavings"]}',
      });
      await pumpOffers(
        tester,
        const ListOfferSummary(listId: testListId),
        overrides: offersOn(snapshot: snapshot, items: items),
      );
      expect(tester.getSize(find.byType(ListOfferSummary)), Size.zero);
    });
  });

  group('S6 OfferSuggestionsBar', () {
    testWidgets('rows without header, the item keeps the typed name', (
      tester,
    ) async {
      final notifier = RecordingItemsNotifier([bread]);
      var cleared = 0;
      await pumpOffers(
        tester,
        OfferSuggestionsBar(
          listId: testListId,
          query: '2 Milch',
          onAdded: () => cleared++,
        ),
        overrides: offersOn(
          items: [bread],
          notifier: notifier,
          suggestions: [offer],
        ),
      );
      expect(find.text('Milbona Frische Vollmilch 3,5 %'), findsOneWidget);
      expect(find.text('Lidl · 1 l · bis Sa.'), findsOneWidget);
      expect(find.text('0,99 €'), findsOneWidget);
      expect(find.textContaining('Spare'), findsNothing);

      await tester.tap(find.text('Milbona Frische Vollmilch 3,5 %'));
      await tester.pumpAndSettle();
      expect(notifier.added.single.name, 'Milch');
      expect(notifier.added.single.quantity, 2);
      expect(notifier.added.single.price, 0.99);
      expect(notifier.added.single.retailer, 'Lidl');
      expect(cleared, 1);
    });

    testWidgets('an open item of that name gets the offer attached', (
      tester,
    ) async {
      final notifier = RecordingItemsNotifier([milk]);
      await pumpOffers(
        tester,
        OfferSuggestionsBar(listId: testListId, query: 'milch'),
        overrides: offersOn(
          items: [milk],
          notifier: notifier,
          suggestions: [offer],
        ),
      );
      await tester.tap(find.text('Milbona Frische Vollmilch 3,5 %'));
      await tester.pumpAndSettle();
      expect(notifier.added, isEmpty);
      expect(notifier.updates.single.$1, 'a');
      expect(notifier.updates.single.$2['price'], 0.99);
      expect(find.text('Angebot an Milch angehängt'), findsOneWidget);
    });

    testWidgets('a long press opens the offer to put it on the list', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        OfferSuggestionsBar(listId: testListId, query: 'milch'),
        overrides: offersOn(suggestions: [offer]),
      );
      await tester.longPress(find.text('Milbona Frische Vollmilch 3,5 %'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      expect(find.text('Auf die Liste'), findsOneWidget);
    });

    testWidgets('a failed add says so and keeps the field', (tester) async {
      final notifier = RecordingItemsNotifier(const [], fail: true);
      var cleared = 0;
      await pumpOffers(
        tester,
        OfferSuggestionsBar(
          listId: testListId,
          query: 'milch',
          onAdded: () => cleared++,
        ),
        overrides: offersOn(notifier: notifier, suggestions: [offer]),
      );
      await tester.tap(find.text('Milbona Frische Vollmilch 3,5 %'));
      await tester.pumpAndSettle();
      expect(find.text('Nicht hinzugefügt'), findsOneWidget);
      expect(cleared, 0);
    });

    testWidgets('a failed attach keeps the typed text', (tester) async {
      final notifier = RecordingItemsNotifier([milk], fail: true);
      var cleared = 0;
      await pumpOffers(
        tester,
        OfferSuggestionsBar(
          listId: testListId,
          query: 'milch',
          onAdded: () => cleared++,
        ),
        overrides: offersOn(
          items: [milk],
          notifier: notifier,
          suggestions: [offer],
        ),
      );
      await tester.tap(find.text('Milbona Frische Vollmilch 3,5 %'));
      await tester.pumpAndSettle();
      expect(notifier.updates, hasLength(1));
      expect(find.text('Preis nicht gespeichert'), findsOneWidget);
      expect(cleared, 0);
    });

    testWidgets('nothing with "Vorschläge beim Tippen" off or one letter', (
      tester,
    ) async {
      await pumpOffers(
        tester,
        OfferSuggestionsBar(listId: testListId, query: 'm'),
        overrides: offersOn(suggestions: [offer]),
      );
      expect(tester.getSize(find.byType(OfferSuggestionsBar)), Size.zero);
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount): '{"off":["typingSuggestions"]}',
      });
      await pumpOffers(
        tester,
        OfferSuggestionsBar(listId: testListId, query: 'milch'),
        overrides: offersOn(suggestions: [offer]),
      );
      expect(tester.getSize(find.byType(OfferSuggestionsBar)), Size.zero);
    });
  });

  group('S1 StoreChip', () {
    testWidgets('the market with its tile, read as "Markt: Lidl, ändern"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        const StoreChip(listId: testListId),
        overrides: offersOn(),
      );
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.bySemanticsLabel('Markt: Lidl, ändern'), findsOneWidget);
      expect(
        tester.getSize(find.byType(StoreChip)).height,
        greaterThanOrEqualTo(44),
      );
      handle.dispose();
    });

    testWidgets('a suggestion reads "Lidl?" and asks', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOffers(
        tester,
        const StoreChip(listId: testListId),
        overrides: offersOn(confirmed: false),
      );
      expect(find.text('Lidl?'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Vorschlag: Lidl. Bestätigen oder ändern'),
        findsOneWidget,
      );
      await tester.tap(find.text('Lidl?'));
      await tester.pumpAndSettle();
      expect(find.text('Ja, Lidl'), findsOneWidget);
      expect(find.text('Nicht fragen'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the menu lists the common chains, "Anderer Markt …" opens '
        'the picker', (tester) async {
      await pumpOffers(
        tester,
        const StoreChip(listId: testListId),
        overrides: offersOn(chainId: null),
      );
      expect(find.text('Markt wählen'), findsOneWidget);
      await tester.tap(find.text('Markt wählen'));
      await tester.pumpAndSettle();
      expect(find.text('REWE'), findsOneWidget);
      expect(find.text('Aldi Süd'), findsOneWidget, reason: 'PLZ 79098');
      expect(find.text('Kein fester Markt'), findsOneWidget);
      await tester.ensureVisible(find.text('Anderer Markt …'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anderer Markt …'));
      await tester.pumpAndSettle();
      expect(find.byType(StorePickerScreen), findsOneWidget);
    });
  });
}

/// A sync that only has what is cached; it never fetches.
class _CachedSync extends ListOfferSync {
  _CachedSync(this.snapshots, {this.onRead}) : super(_NoService());

  final Map<String, ListOfferSnapshot> snapshots;

  /// Called on every read of the cache or the source.
  final VoidCallback? onRead;

  @override
  Future<ListOfferSnapshot?> cached(String listId) async {
    onRead?.call();
    return snapshots[listId];
  }

  @override
  Future<ListOfferSnapshot> sync({
    required String listId,
    required String chainId,
    required String zip,
    required List<String> itemNames,
    bool force = false,
  }) async {
    onRead?.call();
    return snapshots[listId]!;
  }
}

class _NoService extends Fake implements OfferPriceService {}
