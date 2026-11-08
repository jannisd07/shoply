// "Markt wählen" (S2, /stores/pick) and "Angebot" (S5, /offers/offer/:id):
// full screens above the tab bar, never sheets; what they show, what they
// save, and how they close.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/list_store_repository.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_detail_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/store_picker_screen.dart';
import 'package:shoply/routes/app_branch.dart';
import 'package:shoply/routes/app_router.dart';
import 'package:shoply/routes/route_error_screen.dart';

import 'offer_test_harness.dart';

/// Opens [location] from a button on `/` and settles.
Future<GoRouter> _open(
  WidgetTester tester,
  String location, {
  List<Override> overrides = const [],
  Locale locale = const Locale('de'),
}) async {
  late GoRouter router;
  router = await pumpOffers(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => context.push(location),
        child: const Text('open'),
      ),
    ),
    overrides: overrides,
    locale: locale,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return router;
}

/// Records the market writes of the list.
class _Repo extends ListStoreRepository {
  _Repo() : super(remote: _Remote(), currentUserId: () => 'me');

  final picked = <String?>[];

  @override
  Future<void> setExplicit(String listId, String chainId) async =>
      picked.add(chainId);

  @override
  Future<void> clearExplicit(String listId) async => picked.add(null);
}

class _Remote implements ListStoreRemote {
  @override
  Future<void> deleteAssignment(String listId) async {}
  @override
  Future<String?> fetchUserChainId(String listId) async => null;
  @override
  Future<List<List<String>>> recentTripRetailers(
    String listId, {
    int limit = 3,
  }) async => const [];
  @override
  Future<void> saveUserChainId(String listId, String chainId) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('S2 Markt wählen', () {
    testWidgets('a full screen with close, search and all sections', (
      tester,
    ) async {
      await _open(
        tester,
        storePickerLocation(listId: testListId),
        overrides: [
          ...offersOn(),
          listStoreHistoryProvider.overrideWith((ref, id) async => ['rewe']),
          nearbyStoreOptionsProvider.overrideWith(
            (ref) async => const [
              NearbyStoreOption(
                chainId: 'edeka',
                distanceMeters: 340,
                street: 'Bertoldstraße',
              ),
            ],
          ),
        ],
      );
      expect(find.byType(StorePickerScreen), findsOneWidget);
      expect(find.text('Markt'), findsOneWidget);
      expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
      expect(find.text('DEINE MÄRKTE'), findsOneWidget);
      expect(find.text('IN DER NÄHE'), findsOneWidget);
      expect(find.text('Bertoldstraße · 340 m'), findsOneWidget);
      expect(find.text('ALLE MÄRKTE'), findsOneWidget);
      final route = ModalRoute.of(
        tester.element(find.byType(StorePickerScreen)),
      );
      expect(route, isA<PageRoute<dynamic>>());
      expect((route! as PageRoute<dynamic>).fullscreenDialog, isFalse);
    });

    testWidgets('without location "In der Nähe" is not there, no question', (
      tester,
    ) async {
      await _open(tester, storePickerLocation(), overrides: offersOn());
      expect(find.text('IN DER NÄHE'), findsNothing);
      expect(find.text('ALLE MÄRKTE'), findsOneWidget);
    });

    testWidgets('search forgives typos, no hit offers an own market', (
      tester,
    ) async {
      await _open(tester, storePickerLocation(), overrides: offersOn());
      await tester.enterText(find.byType(EditableText), 'lidel');
      await tester.pumpAndSettle();
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('REWE'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'Bio Kaiser');
      await tester.pumpAndSettle();
      expect(
        find.text('Kein Markt mit „Bio Kaiser“ gefunden.'),
        findsOneWidget,
      );
      expect(
        find.text('„Bio Kaiser“ als eigenen Markt verwenden'),
        findsOneWidget,
      );
    });

    testWidgets('with a list a tap saves, closes and offers undo', (
      tester,
    ) async {
      final repo = _Repo();
      await _open(
        tester,
        storePickerLocation(listId: testListId),
        overrides: [
          ...offersOn(chainId: null),
          listStoreRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.enterText(find.byType(EditableText), 'rewe');
      await tester.pumpAndSettle();
      await tester.tap(find.text('REWE'));
      await tester.pumpAndSettle();
      expect(find.byType(StorePickerScreen), findsNothing);
      expect(repo.picked, ['rewe']);
      expect(find.text('Markt: REWE'), findsOneWidget);
      expect(find.text('Widerrufen'), findsOneWidget);
    });
  });

  group('S5 Angebot', () {
    final milk = testItem('a', 'Milch');

    List<Override> withOffer(
      StoreOffer offer, {
      List<StoreOffer> more = const [],
      RecordingItemsNotifier? notifier,
    }) => [
      ...offersOn(
        snapshot: testSnapshot({'Milch': offer}),
        items: [milk],
        notifier: notifier,
      ),
      // "Weitere Angebote" come from the device only.
      cachedMoreOffersProvider.overrideWith((ref, key) => more),
      offerSuggestionsProvider.overrideWith((ref, request) async {
        fail('the offer detail never searches');
      }),
      offerByIdProvider.overrideWith(
        (ref, key) => key.offerId == offer.id ? offer : null,
      ),
    ];

    String take(StoreOffer offer) => offerDetailLocation(
      offer.id,
      listId: testListId,
      itemId: 'a',
      mode: OfferDetailMode.take,
    );

    testWidgets('head, big price, values, footnote and "Preis übernehmen"', (
      tester,
    ) async {
      final offer = testOffer(referencePrice: 0.66, volume: 1.5);
      await _open(tester, take(offer), overrides: withOffer(offer));
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      expect(find.text('Angebot'), findsOneWidget);
      expect(find.text('Milbona Frische Vollmilch 3,5 %'), findsOneWidget);
      expect(find.text('0,99 €'), findsOneWidget);
      expect(find.text('laut Händler statt'), findsOneWidget);
      expect(find.text('1,19 €'), findsOneWidget);
      expect(find.text('Grundpreis'), findsOneWidget);
      expect(find.text('0,66 €/l'), findsOneWidget);
      expect(find.text('bis Sa., 14. Nov.'), findsOneWidget);
      expect(find.text('79098 Freiburg'), findsOneWidget);
      expect(find.textContaining('Quelle: Händlerprospekte.'), findsOneWidget);
      expect(find.text('Preis übernehmen'), findsOneWidget);
      expect(find.text('Nicht dieses Angebot'), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget, reason: 'only 3,5 %');
    });

    testWidgets('"Preis übernehmen" writes the price, closes, offers undo', (
      tester,
    ) async {
      final offer = testOffer();
      final notifier = RecordingItemsNotifier([milk]);
      await _open(
        tester,
        take(offer),
        overrides: withOffer(offer, notifier: notifier),
      );
      await tester.tap(find.text('Preis übernehmen'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsNothing);
      expect(notifier.updates.single.$2['price'], 0.99);
      expect(notifier.updates.single.$2['price_retailer'], 'Lidl');
      expect(find.text('Preis für Milch übernommen'), findsOneWidget);
      await tester.tap(find.text('Widerrufen'));
      await tester.pumpAndSettle();
      expect(notifier.updates.last.$2['price'], isNull);
    });

    testWidgets('a failed save says so with "Erneut versuchen"', (
      tester,
    ) async {
      final offer = testOffer();
      final notifier = RecordingItemsNotifier([milk], fail: true);
      await _open(
        tester,
        take(offer),
        overrides: withOffer(offer, notifier: notifier),
      );
      await tester.tap(find.text('Preis übernehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Preis nicht gespeichert'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });

    testWidgets('an ended offer disables the main action', (tester) async {
      final offer = testOffer(validTo: DateTime.utc(2026, 1, 2));
      await _open(tester, take(offer), overrides: withOffer(offer));
      expect(find.text('abgelaufen'), findsOneWidget);
      expect(find.text('Angebot abgelaufen'), findsOneWidget);
      await tester.tap(find.text('Angebot abgelaufen'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsOneWidget);
    });

    testWidgets('a similar product says so', (tester) async {
      final offer = testOffer(broad: true);
      await _open(tester, take(offer), overrides: withOffer(offer));
      expect(
        find.text(
          'Ähnliches Produkt. Prüf vor dem Kauf, ob es zu „Milch“ passt.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Nicht dieses Angebot" hides it for the item', (tester) async {
      final offer = testOffer();
      final container = await _open(
        tester,
        take(offer),
        overrides: withOffer(offer),
      );
      expect(container, isNotNull);
      await tester.tap(find.text('Nicht dieses Angebot'));
      await tester.pumpAndSettle();
      expect(find.text('Angebot für Milch ausgeblendet'), findsOneWidget);
      final scope = ProviderScope.containerOf(
        tester.element(find.text('open')),
      );
      final prefs = scope.read(offerDisplayPrefsProvider)!;
      expect(prefs.isDeclined('a', offer.id, DateTime.now()), isTrue);
    });

    testWidgets('more offers of the market swap in', (tester) async {
      final offer = testOffer();
      final other = testOffer(id: 9, product: 'Weidemilch', price: 1.09);
      await _open(
        tester,
        take(offer),
        overrides: withOffer(offer, more: [offer, other]),
      );
      expect(find.text('WEITERE ANGEBOTE BEI LIDL'), findsOneWidget);
      // Past the floating main action, which covers the bottom edge.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('1,09 €'), findsOneWidget, reason: 'in the row');
      await tester.tap(find.text('Milbona Weidemilch'));
      await tester.pumpAndSettle();
      // The head now shows the other offer (scrolled out of view above).
      expect(
        find.text('Milbona Weidemilch', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Milbona Frische Vollmilch 3,5 %'),
        findsOneWidget,
        reason: 'the first offer moved into "Weitere Angebote"',
      );
      expect(find.byType(OfferDetailScreen), findsOneWidget);
    });

    testWidgets('an offer that is no longer saved', (tester) async {
      await _open(
        tester,
        offerDetailLocation(1234, listId: testListId),
        overrides: [
          ...offersOn(),
          offerByIdProvider.overrideWith((ref, key) => null),
        ],
      );
      expect(
        find.text('Dieses Angebot ist nicht mehr gespeichert.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(OfferDetailScreen), findsNothing);
    });

    testWidgets('the kill switch shows the error page', (tester) async {
      final offer = testOffer();
      await _open(
        tester,
        take(offer),
        overrides: [
          ...withOffer(offer),
          offersRemoteEnabledProvider.overrideWithValue(false),
        ],
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.textContaining('Angebot'), findsNothing);
    });

    testWidgets('"Auf die Liste" puts it on the list under the typed name', (
      tester,
    ) async {
      final offer = testOffer();
      final notifier = RecordingItemsNotifier(const []);
      await _open(
        tester,
        offerDetailLocation(
          offer.id,
          listId: testListId,
          mode: OfferDetailMode.add,
          name: 'Milch',
        ),
        overrides: withOffer(offer, notifier: notifier),
      );
      await tester.tap(find.text('Auf die Liste'));
      await tester.pumpAndSettle();
      expect(notifier.added.single.name, 'Milch');
      expect(find.text('Milch auf Wocheneinkauf'), findsOneWidget);
    });
  });

  group('S5 when offers switch off while it is open', () {
    final module = StateProvider<bool>((ref) => true);
    final kill = StateProvider<bool>((ref) => true);

    Future<ProviderContainer> openLive(WidgetTester tester) async {
      final offer = testOffer();
      await _open(
        tester,
        offerDetailLocation(
          offer.id,
          listId: testListId,
          itemId: 'a',
          mode: OfferDetailMode.take,
        ),
        overrides: [
          ...offersOn(
            snapshot: testSnapshot({'Milch': offer}),
            items: [testItem('a', 'Milch')],
          ),
          offerByIdProvider.overrideWith((ref, key) => offer),
          moduleEnabledProvider.overrideWith((ref, m) => ref.watch(module)),
          offersRemoteEnabledProvider.overrideWith((ref) => ref.watch(kill)),
          offersAvailableProvider.overrideWith(
            (ref) => ref.watch(module) && ref.watch(kill),
          ),
        ],
      );
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      return ProviderScope.containerOf(
        tester.element(find.byType(OfferDetailScreen)),
      );
    }

    void expectQuiet() {
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RouteErrorScreen), findsNothing);
      expect(find.textContaining('ausgeschaltet'), findsNothing);
    }

    testWidgets('module off elsewhere: closes silently, no dialog', (
      tester,
    ) async {
      final container = await openLive(tester);
      container.read(module.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expectQuiet();
      await tester.pumpAndSettle();
      expectQuiet();
      expect(find.byType(OfferDetailScreen), findsNothing);
      expect(find.text('open').hitTestable(), findsOneWidget);
    });

    testWidgets('kill switch: closes silently, no error page', (tester) async {
      final container = await openLive(tester);
      container.read(kill.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expectQuiet();
      await tester.pumpAndSettle();
      expectQuiet();
      expect(find.byType(OfferDetailScreen), findsNothing);
      expect(find.text('open').hitTestable(), findsOneWidget);
    });

    testWidgets('opened while the module is off: A asks first', (tester) async {
      final offer = testOffer();
      await _open(
        tester,
        offerDetailLocation(offer.id, listId: testListId),
        overrides: [
          ...offersOn(),
          offerByIdProvider.overrideWith((ref, key) => offer),
          moduleEnabledProvider.overrideWith((ref, m) => false),
        ],
      );
      expect(find.byType(OfferDetailScreen), findsNothing);
      expect(find.textContaining('ausgeschaltet'), findsWidgets);
    });
  });

  group('S5 finds an offer only where offers may show', () {
    testWidgets('without a real region: "nicht mehr gespeichert"', (
      tester,
    ) async {
      final offer = testOffer();
      await _open(
        tester,
        offerDetailLocation(offer.id, listId: testListId),
        overrides: [
          ...offersOn(region: null),
          offerCacheProvider.overrideWith(
            (ref) => OfferCache()..remember(offer),
          ),
        ],
      );
      expect(
        find.text('Dieses Angebot ist nicht mehr gespeichert.'),
        findsOneWidget,
      );
    });

    testWidgets('on a list with hidden offers: "nicht mehr gespeichert"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        hiddenOfferListsKeyFor(testAccount): [testListId],
      });
      final offer = testOffer();
      await _open(
        tester,
        offerDetailLocation(offer.id, listId: testListId),
        overrides: [
          ...offersOn(),
          offersVisibleForListProvider.overrideWith(
            (ref, id) =>
                !(ref.watch(hiddenOfferListsProvider)?.contains(id) ?? true),
          ),
          offerCacheProvider.overrideWith(
            (ref) => OfferCache()..remember(offer),
          ),
        ],
      );
      expect(
        find.text('Dieses Angebot ist nicht mehr gespeichert.'),
        findsOneWidget,
      );
    });

    testWidgets('with region and a visible list the cached offer opens', (
      tester,
    ) async {
      final offer = testOffer();
      await _open(
        tester,
        offerDetailLocation(offer.id, listId: testListId),
        overrides: [
          ...offersOn(),
          offerCacheProvider.overrideWith(
            (ref) => OfferCache()..remember(offer),
          ),
        ],
      );
      expect(find.text('Milbona Frische Vollmilch 3,5 %'), findsOneWidget);
      expect(find.text('Auf die Liste'), findsOneWidget);
    });
  });

  test('/offers/offer/:id is a full screen above the shell', () {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: buildAppRoutes(),
    );
    addTearDown(router.dispose);
    final match = router.configuration.findMatch('/offers/offer/7?list=l');
    expect(match.isError, isFalse);
    final last = match.matches.last;
    expect((last.route as GoRoute).path, offerDetailPattern);
    expect(match.matches, hasLength(1), reason: 'not inside the tab shell');

    final picker = router.configuration.findMatch(storePickerLocation());
    expect((picker.matches.last.route as GoRoute).path, storePickerPath);
    expect(router.configuration.findMatch('/offers').isError, isFalse);
  });

  test('every store choice compares by value', () {
    expect(const ChainStoreChoice('lidl'), const ChainStoreChoice('lidl'));
    expect(const CustomStoreChoice('Bio'), const CustomStoreChoice('Bio'));
    expect(const NoStoreChoice(), const NoStoreChoice());
    expect(storeInfoForChain('lidl')?.name, 'Lidl');
    expect(OfferSurface.values, hasLength(3));
  });
}
