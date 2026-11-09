// Teil B, angebote.md S9 "Angebote bei {Markt}", S10 "Angebote der Woche"
// with the menu "Auf welche Liste?", S15 recipe row and "Angebote für
// {Rezept}", S7's tap and the routes of S9-S15.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/recipe_offer_service.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart';
import 'package:shoply/presentation/screens/offers/list_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/list_target_menu.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/weekly_offers_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_offers_card.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/areas/offers_routes.dart';

import 'offer_test_harness.dart';

final _milk = testItem('a', 'Milch', quantity: 2);
final _bread = testItem('b', 'Brot');
final _offer = testOffer();

/// The S9 route with a stand-in list, as in the Listen tab.
final List<RouteBase> _offerRoutes = [
  GoRoute(
    path: '/lists/:listId',
    builder: (context, state) => const Text('Liste'),
  ),
  GoRoute(path: '/offers', builder: buildOffersRoot, routes: offersChildRoutes),
];

RegularOffer _regular({
  String name = 'Haferflocken',
  String chain = 'lidl',
  int id = 40,
}) => RegularOffer(
  name: name,
  offer: testOffer(
    id: id,
    product: 'Zarte Haferflocken',
    brand: 'Crownfield',
    price: 0.59,
    oldPrice: null,
    retailer: chain,
    volume: 0.5,
    unit: 'kg',
  ),
  chainId: chain,
  averageDays: 10,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('S9 Angebote bei Lidl', () {
    List<Override> on({
      ListOfferSnapshot? snapshot,
      RegularOffers regulars = RegularOffers.none,
      RecordingItemsNotifier? notifier,
      String? chainId = 'lidl',
    }) => [
      ...offersOn(
        snapshot: snapshot ?? testSnapshot({'Milch': _offer}),
        items: [_milk, _bread],
        notifier: notifier,
        chainId: chainId,
      ),
      regularOffersAtProvider.overrideWith(
        (ref, chain) async => RegularOffers(
          hasStats: regulars.hasStats,
          offers: [
            for (final r in regulars.offers)
              if (r.chainId == chain) r,
          ],
        ),
      ),
    ];

    testWidgets('title, sentence, the list\'s offers in its order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(),
      );
      expect(find.text('Angebote bei Lidl'), findsOneWidget);
      expect(
        find.text(
          '1 von 2 Artikeln diese Woche bei Lidl im Angebot, in deiner Region',
        ),
        findsOneWidget,
      );
      expect(find.text('AUF DEINER LISTE'), findsOneWidget);
      expect(find.text('Milch · 2'), findsOneWidget);
      expect(find.text('laut Händler statt 1,19 €'), findsOneWidget);
      expect(find.text('0,99 €'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Milch, 2, Milbona Frische Vollmilch 3,5 Prozent, 1 Liter, '
            r'bis .*, laut Händler statt 1,19 Euro, im Angebot 0,99 Euro '
            'laut Händler',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Alle Angebote der Woche'), findsOneWidget);
      expect(find.text('Angebote für diese Liste ausblenden'), findsOneWidget);
      expect(
        find.textContaining('„Gespart“ ist der Unterschied'),
        findsOneWidget,
      );
      expect(find.textContaining('Quelle: Händlerprospekte'), findsOneWidget);
      expect(find.byType(AvoFigure), findsNothing, reason: 'no figure (money)');
      handle.dispose();
    });

    testWidgets('a row opens the offer with "Preis übernehmen"', (
      tester,
    ) async {
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(),
      );
      await tester.tap(find.text('Milch · 2'));
      await tester.pumpAndSettle();
      expect(find.text('Preis übernehmen'), findsOneWidget);
    });

    testWidgets('a regular goes on with its offer and joins the list group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final notifier = RecordingItemsNotifier([_milk, _bread]);
      _tall(tester);
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(
          notifier: notifier,
          regulars: RegularOffers(
            hasStats: true,
            offers: [
              _regular(),
              _regular(name: 'Kaffee', chain: 'rewe', id: 41),
            ],
          ),
        ),
      );
      expect(find.text('DIESE WOCHE BEI LIDL, OFT GEKAUFT'), findsOneWidget);
      expect(find.text('Haferflocken'), findsOneWidget);
      expect(find.text('Kaffee'), findsNothing, reason: 'other market');
      await tester.tap(
        find.bySemanticsLabel('Haferflocken auf Wocheneinkauf setzen'),
      );
      await tester.pumpAndSettle();
      expect(notifier.added.single.name, 'Haferflocken');
      expect(notifier.added.single.price, 0.59);
      expect(find.text('Haferflocken auf Wocheneinkauf'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('"ausblenden" hides the list\'s offers, says so and closes', (
      tester,
    ) async {
      final router = await pumpOfferScreen(
        tester,
        const Text('Liste'),
        overrides: on(),
        routes: _offerRoutes,
      );
      router.push(offerListLocation(testListId));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Angebote für diese Liste ausblenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Angebote für Wocheneinkauf ausgeblendet'),
        findsOneWidget,
      );
      expect(find.byType(ListOffersScreen), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hiddenOfferListsKeyFor(testAccount)), [
        testListId,
      ]);
    });

    testWidgets('back from S9 leads to the list, not to S10', (tester) async {
      final router = await pumpOfferScreen(
        tester,
        const Text('Start'),
        overrides: on(),
        routes: _offerRoutes,
      );
      router.go('/lists/$testListId');
      await tester.pumpAndSettle();
      router.push(offerListLocation(testListId));
      await tester.pumpAndSettle();
      expect(find.byType(ListOffersScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Zurück'));
      await tester.pumpAndSettle();
      expect(find.text('Liste'), findsOneWidget);
      expect(find.byType(WeeklyOffersScreen), findsNothing);
    });

    testWidgets('states: empty, failed refresh, offline, loading', (
      tester,
    ) async {
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(snapshot: testSnapshot({})),
      );
      expect(find.text('Gerade nichts im Angebot.'), findsOneWidget);
      expect(find.byType(AvoFigure), findsNothing);

      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(
          snapshot: ListOfferSnapshot(
            chainId: 'lidl',
            zip: testRegion.zip,
            fetchedAt: DateTime(2026, 11, 7, 9, 30),
            offersByName: {offerNameKey('Milch'): _offer},
            complete: false,
          ),
        ),
      );
      expect(
        find.text('Angebote konnten gerade nicht aktualisiert werden.'),
        findsOneWidget,
      );
      expect(find.text('Milch · 2'), findsOneWidget, reason: 'content stays');

      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: [
          ...on(
            snapshot: ListOfferSnapshot(
              chainId: 'lidl',
              zip: testRegion.zip,
              fetchedAt: DateTime(2026, 11, 7, 9, 30),
              offersByName: {offerNameKey('Milch'): _offer},
            ),
          ),
          isOfflineProvider.overrideWithValue(true),
        ],
      );
      expect(
        find.text('Offline. Angebote vom Stand Sa., 7. Nov., 9:30.'),
        findsOneWidget,
      );

      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: [
          ...on(),
          listOfferSnapshotProvider.overrideWith(
            (ref, id) => Completer<ListOfferSnapshot?>().future,
          ),
        ],
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonSection), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no region, hidden list, list without a market', (
      tester,
    ) async {
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: offersOn(region: null),
      );
      expect(
        find.text('Für Angebote brauchst du eine Region.'),
        findsOneWidget,
      );
      expect(find.text('Postleitzahl festlegen'), findsOneWidget);

      SharedPreferences.setMockInitialValues({
        hiddenOfferListsKeyFor(testAccount): [testListId],
      });
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(),
      );
      expect(
        find.text('Angebote sind für Wocheneinkauf ausgeblendet.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Einblenden'));
      await tester.pumpAndSettle();
      expect(find.text('Milch · 2'), findsOneWidget);

      SharedPreferences.setMockInitialValues({});
      await pumpOfferScreen(
        tester,
        const ListOffersScreen(listId: testListId),
        overrides: on(chainId: null),
      );
      expect(find.text('Angebote für Wocheneinkauf'), findsOneWidget);
      expect(find.text('Markt wählen'), findsOneWidget);
    });
  });

  testWidgets('S7: the savings card opens "Angebote bei Lidl"', (tester) async {
    final router = await pumpOfferScreen(
      tester,
      const Scaffold(body: ListOfferSummary(listId: testListId)),
      overrides: [
        ...offersOn(
          snapshot: testSnapshot({'Milch': _offer}),
          items: [_milk, _bread],
        ),
      ],
      routes: _offerRoutes,
    );
    expect(router, isNotNull);
    await tester.tap(find.textContaining('1 von 2 Artikeln'));
    await tester.pumpAndSettle();
    expect(find.byType(ListOffersScreen), findsOneWidget);
  });

  group('S10 Angebote der Woche', () {
    WeeklyListSection section({List<ListOfferEntry>? entries}) =>
        WeeklyListSection(
          listId: testListId,
          listName: 'Wocheneinkauf',
          chainId: 'lidl',
          entries:
              entries ??
              [
                ListOfferEntry(
                  item: _milk,
                  offer: testOffer(product: 'Weidetrunk 1,5 %', brand: null),
                ),
              ],
          complete: true,
          fetchedAt: DateTime(2026, 11, 7, 9, 30),
          itemNames: const ['Milch', 'Brot'],
        );

    List<Override> on({
      List<WeeklyListSection>? sections,
      RegularOffers regulars = RegularOffers.none,
      RecordingItemsNotifier? notifier,
      List<StoreOffer> search = const [],
    }) => [
      ...offersOn(items: [_milk, _bread], notifier: notifier),
      weeklyListSectionsProvider.overrideWith(
        (ref) async => sections ?? [section()],
      ),
      regularOffersProvider.overrideWith((ref) async => regulars),
      weeklyOfferSearchProvider.overrideWith((ref, key) async => search),
      offerTargetListsProvider.overrideWith(
        (ref) => const [
          OfferTargetList(id: testListId, name: 'Wocheneinkauf'),
          OfferTargetList(id: 'list-2', name: 'Drogerie'),
        ],
      ),
      cachedStoreOfListProvider.overrideWith(
        (ref, id) => id == testListId ? 'lidl' : null,
      ),
    ];

    testWidgets('without a region: "Wo kaufst du ein?", nothing asked', (
      tester,
    ) async {
      var asked = 0;
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(),
        overrides: [
          ...offersOn(region: null),
          weeklyListSectionsProvider.overrideWith((ref) async {
            asked++;
            return const [];
          }),
          regularOffersProvider.overrideWith((ref) async {
            asked++;
            return RegularOffers.none;
          }),
        ],
      );
      expect(find.text('Wo kaufst du ein?'), findsOneWidget);
      expect(find.text('Standort verwenden'), findsOneWidget);
      expect(find.text('Postleitzahl eingeben'), findsOneWidget);
      expect(find.text('Angebote suchen'), findsNothing);
      expect(find.byType(AvoFigure), findsNothing);
      expect(asked, 0);
    });

    testWidgets('"Deine Listen": area, segments, chips, the list\'s offers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final notifier = RecordingItemsNotifier([_milk, _bread]);
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(),
        overrides: on(notifier: notifier),
      );
      expect(find.text('Angebote der Woche'), findsOneWidget);
      expect(find.text('In deiner Region · 79098 Freiburg'), findsOneWidget);
      expect(find.text('Deine Listen'), findsOneWidget);
      expect(find.text('Oft gekauft'), findsOneWidget);
      expect(find.text('WOCHENEINKAUF · LIDL'), findsOneWidget);
      expect(find.text('Für „Milch“ auf Wocheneinkauf'), findsOneWidget);
      // The plus puts it straight on the section's list.
      await tester.tap(find.bySemanticsLabel('Milch auf Wocheneinkauf setzen'));
      await tester.pumpAndSettle();
      expect(notifier.updates.single.$1, _milk.id, reason: 'attached');
      expect(
        find.text('Angebot an Milch auf Wocheneinkauf angehängt'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('"Oft gekauft": rhythm, the list menu, offer not valid there', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: on(
          regulars: RegularOffers(
            hasStats: true,
            offers: [_regular(chain: 'rewe')],
          ),
        ),
      );
      expect(find.text('REWE · Kaufst du etwa alle 10 Tage'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Haferflocken, Auf die Liste'));
      await tester.pumpAndSettle();
      expect(find.text('Wocheneinkauf'), findsWidgets);
      expect(find.text('Lidl · Angebot gilt dort nicht'), findsOneWidget);
      expect(find.text('Neue Liste …'), findsOneWidget);
      await tester.tap(find.text('Lidl · Angebot gilt dort nicht'));
      await tester.pumpAndSettle();
      expect(
        find.text('Haferflocken auf Wocheneinkauf · Angebot gilt nur bei REWE'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('"Nicht interessiert" hides the offer until it ends', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: on(
          regulars: RegularOffers(hasStats: true, offers: [_regular()]),
        ),
      );
      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('^Crownfield Zarte Haferflocken')),
        CustomSemanticsAction(label: 'Nicht interessiert'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ausgeblendet bis'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(offerDisplayPrefsKeyFor(testAccount)),
        contains('"notInterested":{"40"'),
      );
      handle.dispose();
    });

    testWidgets('"Oft gekauft" empty and without enough trips', (tester) async {
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: on(regulars: RegularOffers.none),
      );
      expect(
        find.textContaining('Nach ein paar Einkäufen siehst du hier'),
        findsOneWidget,
      );
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: on(
          regulars: const RegularOffers(hasStats: true, offers: []),
        ),
      );
      expect(
        find.text('Gerade ist nichts im Angebot, was du oft kaufst.'),
        findsOneWidget,
      );
    });

    testWidgets('search groups by market; nothing found: Avo thinks along', (
      tester,
    ) async {
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(query: 'Milch'),
        overrides: on(
          search: [
            testOffer(id: 1, retailer: 'rewe', product: 'Milch REWE'),
            testOffer(id: 2, product: 'Milch Lidl'),
          ],
        ),
      );
      expect(find.text('Deine Listen'), findsNothing, reason: 'no segments');
      final lidl = tester.getTopLeft(find.text('LIDL')).dy;
      final rewe = tester.getTopLeft(find.text('REWE')).dy;
      expect(lidl, lessThan(rewe), reason: 'the list\'s market first');

      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(query: 'Hummus'),
        overrides: on(),
      );
      expect(
        find.text('Kein Angebot für „Hummus“ in deiner Region.'),
        findsOneWidget,
      );
      expect(find.byType(AvoFigure), findsOneWidget);
    });

    testWidgets('"Spar-Hinweise" off: no segment "Oft gekauft"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount): '{"off":["homeTips"]}',
      });
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: on(),
      );
      expect(find.text('Oft gekauft'), findsNothing);
      expect(find.text('WOCHENEINKAUF · LIDL'), findsOneWidget);
    });
  });

  test('groupOffersByMarket: lists, favourites, then A-Z; never by price', () {
    final groups = groupOffersByMarket(
      'milch',
      [
        testOffer(id: 1, retailer: 'penny', price: 0.5),
        testOffer(id: 2, retailer: 'rewe', product: 'Bio Joghurt mit Milch'),
        testOffer(id: 3, retailer: 'rewe', product: 'Joghurt'),
        testOffer(id: 4, retailer: 'edeka'),
        testOffer(id: 5, retailer: 'lidl'),
      ],
      listMarkets: const ['lidl'],
      favorites: const ['rewe'],
    );
    expect(
      [for (final g in groups) g.chainId],
      ['lidl', 'rewe', 'edeka', 'penny'],
    );
    expect([for (final o in groups[1].offers) o.id], [2, 3]);
  });

  group('S15 recipe offers', () {
    final recipe = Recipe(
      id: 'r1',
      name: 'Shakshuka',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      defaultServings: 2,
      ingredients: const [
        Ingredient(name: 'Paprika', amount: 1, unit: ''),
        Ingredient(name: 'Tomaten', amount: 400, unit: 'g'),
        Ingredient(name: 'Salz', amount: 1, unit: 'Prise'),
        Ingredient(name: 'Eier', amount: 4, unit: ''),
      ],
      instructions: const [],
      authorId: 'a',
      authorName: 'Avo',
      createdAt: DateTime(2026, 11, 8),
    );
    final paprika = RecipeIngredientOffer.fromStoreOffer(
      'Paprika',
      testOffer(id: 50, product: 'Paprika rot', brand: null, oldPrice: null),
    );

    List<Override> on(_Source source, {String? chainId = 'lidl'}) => [
      ...offersOn(chainId: chainId),
      recipeOfferSourceProvider.overrideWithValue(source),
      recipeServingsProvider.overrideWith((ref, id) => 4),
    ];

    testWidgets('the row shows what was cached and opens the screen', (
      tester,
    ) async {
      final source = _Source(cached: _result(recipe, [paprika]));
      await pumpOfferScreen(
        tester,
        Scaffold(
          body: Column(
            children: [
              RecipeOfferSummary(recipe: recipe, listId: testListId),
              IngredientOfferBadge(
                listId: testListId,
                ingredient: recipe.ingredients.first,
              ),
            ],
          ),
        ),
        overrides: on(source),
      );
      expect(
        find.text(
          '1 Zutat diese Woche bei Lidl im Angebot · für Wocheneinkauf, '
          'in deiner Region',
        ),
        findsOneWidget,
      );
      expect(find.text('0,99 €'), findsOneWidget, reason: 'ingredient pill');
      expect(source.fetches, 0);

      await tester.tap(find.textContaining('1 Zutat diese Woche'));
      await tester.pumpAndSettle();
      expect(find.text('Angebote für Shakshuka'), findsOneWidget);
      expect(
        find.text(
          '1 von 3 Zutaten diese Woche bei Lidl im Angebot, für '
          'Wocheneinkauf, in deiner Region',
        ),
        findsOneWidget,
      );
      expect(find.text('ZUTATEN IM ANGEBOT'), findsOneWidget);
      expect(find.text('Paprika · 2'), findsOneWidget, reason: '4 servings');
      expect(find.textContaining('gespart'), findsNothing);
      expect(find.textContaining('Quelle: Händlerprospekte'), findsOneWidget);
    });

    testWidgets('nothing cached: no row now, looked up for next time', (
      tester,
    ) async {
      final source = _Source();
      await pumpOfferScreen(
        tester,
        RecipeOfferSummary(recipe: recipe, listId: testListId),
        overrides: on(source),
      );
      expect(find.textContaining('Zutat'), findsNothing);
      expect(source.fetches, 1);
      expect(source.chains, ['lidl'], reason: 'only the list\'s market');
    });

    testWidgets('a list without a market: no row, nothing asked', (
      tester,
    ) async {
      final source = _Source(cached: _result(recipe, [paprika]));
      await pumpOfferScreen(
        tester,
        RecipeOfferSummary(recipe: recipe, listId: testListId),
        overrides: on(source, chainId: null),
      );
      expect(find.textContaining('Zutat'), findsNothing);
      expect(source.reads + source.fetches, 0);
    });

    test('pantry staples never count', () {
      expect(
        RecipeOfferService.eligibleIngredientNames([
          'Salz',
          'Pfeffer',
          'Wasser',
          'Öl',
          'Olivenöl',
          'Zucker',
          'Paprika',
        ]),
        ['Paprika'],
      );
    });
  });

  test('routes: S9 in the Listen tab, S15 and region above it, settings', () {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: buildAppRoutes(),
    );
    addTearDown(router.dispose);
    final list = router.configuration.findMatch(offerListLocation('l1'));
    expect(list.isError, isFalse);
    expect(list.matches.single, isA<ShellRouteMatch>(), reason: 'in the tab');

    final recipe = router.configuration.findMatch(
      offerRecipeLocation('r1', listId: 'l1'),
    );
    expect(recipe.matches.single, isNot(isA<ShellRouteMatch>()));
    expect((recipe.matches.single.route as GoRoute).path, offerRecipePattern);

    final region = router.configuration.findMatch(storeRegionLocation());
    expect(region.matches.single, isNot(isA<ShellRouteMatch>()));
    expect((region.matches.single.route as GoRoute).path, storeRegionPath);

    for (final path in [
      offersSettingsPath,
      offersSettingsRegionPath,
      offersSettingsMarketsPath,
    ]) {
      expect(
        router.configuration.findMatch(path).isError,
        isFalse,
        reason: path,
      );
    }
    expect(AppBranch.values, contains(AppBranch.profile));
  });
}

/// A phone-wide, very tall screen, so every section is laid out.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

RecipeOffersResult _result(
  Recipe recipe,
  List<RecipeIngredientOffer> matches,
) => RecipeOffersResult(
  recipeId: recipe.id,
  zipCode: testRegion.zip,
  checkedIngredientCount: 3,
  matches: matches,
  signature: 'x',
);

class _Source implements RecipeOfferSource {
  _Source({this.cached});

  final RecipeOffersResult? cached;
  int reads = 0;
  int fetches = 0;
  final chains = <String?>[];

  @override
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) async {
    reads++;
    return cached;
  }

  @override
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
    bool force = false,
  }) async {
    fetches++;
    chains.add(chainId);
    return cached ??
        RecipeOffersResult(
          recipeId: recipeId,
          zipCode: zipCode,
          checkedIngredientCount: 3,
          matches: const [],
          signature: '',
        );
  }
}
