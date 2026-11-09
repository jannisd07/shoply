// W4 review round 1: hidden lists while loading, "Nicht interessiert" by
// swipe with a quick undo, "Neue Liste …" from the offer detail, S15 errors
// and offline, the region keeps no coordinates, S9 for a list that is gone,
// S14 and late flags, and the S10 providers ask nothing while offers are off.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/item_purchase_stats.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/list_store_repository.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/offers/list_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/list_target_menu.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/recipe_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/weekly_offers_screen.dart';
import 'package:shoply/presentation/widgets/deals/offers_setup_step.dart';
import 'package:shoply/routes/route_error_screen.dart';

import 'offer_test_harness.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Counts every snapshot request; answers with [snapshot].
class _CountingSync extends ListOfferSync {
  _CountingSync(this.snapshot) : super(_NoSource());

  final ListOfferSnapshot snapshot;
  int syncs = 0;

  @override
  Future<ListOfferSnapshot> sync({
    required String listId,
    required String chainId,
    required String zip,
    required List<String> itemNames,
    bool force = false,
  }) async {
    syncs++;
    return snapshot;
  }
}

class _NoSource extends Fake implements OfferPriceService {}

/// Counts every search.
class _CountingSource extends Fake implements OfferPriceService {
  int searches = 0;

  @override
  Future<List<StoreOffer>?> trySearchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    searches++;
    return const [];
  }

  @override
  List<StoreOffer>? cachedOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) {
    searches++;
    return null;
  }
}

class _FakeStoreRepo extends Fake implements ListStoreRepository {
  final explicit = <(String, String)>[];

  final saved = <String, StoreGuess>{};

  @override
  Future<void> setExplicit(String listId, String chainId) async {
    explicit.add((listId, chainId));
    saved[listId] = StoreGuess(chainId, StoreSource.user, confirmed: true);
  }

  @override
  StoreGuess? cachedGuess(String listId) => saved[listId];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. "Deine Listen" while the hidden lists load', () {
    test(
      'nothing is fetched until they are known; a hidden list never',
      () async {
        SharedPreferences.setMockInitialValues({
          hiddenOfferListsKeyFor(testAccount): [testListId],
        });
        final sync = _CountingSync(testSnapshot({'Milch': testOffer()}));
        final c = ProviderContainer(
          overrides: [
            ...offersOn(),
            // The real hidden lists, loading from the device.
            offerDealListIdsProvider.overrideWith((ref) => [testListId]),
            offerDealItemsProvider.overrideWith(
              (ref, ids) async => [testItem('a', 'Milch')],
            ),
            listOfferSyncProvider.overrideWithValue(sync),
          ],
        );
        addTearDown(c.dispose);
        c.listen(weeklyListSectionsProvider, (_, __) {});
        expect(c.read(hiddenOfferListsProvider), isNull, reason: 'loading');
        expect(await c.read(weeklyListSectionsProvider.future), isEmpty);
        await _settle();
        await _settle();
        expect(c.read(hiddenOfferListsProvider), {testListId});
        expect(await c.read(weeklyListSectionsProvider.future), isEmpty);
        expect(sync.syncs, 0, reason: 'no request for a hidden list');
      },
    );

    test(
      'lists and search ask nothing with no region or the kill switch',
      () async {
        for (final overrides in [
          offersOn(region: null),
          [...offersOn(), offersRemoteEnabledProvider.overrideWithValue(false)],
          [...offersOn(), offersAvailableProvider.overrideWithValue(false)],
        ]) {
          final sync = _CountingSync(testSnapshot({}));
          final source = _CountingSource();
          var itemReads = 0;
          final c = ProviderContainer(
            overrides: [
              ...overrides,
              offerDealListIdsProvider.overrideWith((ref) => [testListId]),
              offerDealItemsProvider.overrideWith((ref, ids) async {
                itemReads++;
                return [testItem('a', 'Milch')];
              }),
              listOfferSyncProvider.overrideWithValue(sync),
              offerPriceServiceProvider.overrideWithValue(source),
            ],
          );
          addTearDown(c.dispose);
          c.listen(weeklyListSectionsProvider, (_, __) {});
          await _settle();
          expect(await c.read(weeklyListSectionsProvider.future), isEmpty);
          for (final offline in [false, true]) {
            final key = (query: 'Milch', offline: offline);
            c.listen(weeklyOfferSearchProvider(key), (_, __) {});
            expect(
              await c.read(weeklyOfferSearchProvider(key).future),
              isEmpty,
            );
          }
          expect(sync.syncs, 0);
          expect(itemReads, 0);
          expect(source.searches, 0);
        }
      },
    );

    test('S9 looks regulars up only at its own market', () async {
      final source = _CountingSource();
      final c = ProviderContainer(
        overrides: [
          offersRemoteEnabledProvider.overrideWithValue(true),
          offersAvailableProvider.overrideWithValue(true),
          offerAccountIdProvider.overrideWithValue(testAccount),
          regionProvider.overrideWithValue(testRegion),
          offerPriceServiceProvider.overrideWithValue(source),
          offerOpenItemNamesProvider.overrideWith((ref) async => <String>{}),
          offerPurchaseStatsProvider.overrideWith(
            (ref) async => [
              _stats('kaffee', 'REWE'),
              _stats('tee', 'REWE'),
              _stats('milch', 'Lidl'),
            ],
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(offerDisplayPrefsProvider, (_, __) {});
      await _settle();
      c.listen(regularOffersAtProvider('lidl'), (_, __) {});
      await c.read(regularOffersAtProvider('lidl').future);
      expect(source.searches, 1, reason: 'only "milch" is bought at Lidl');
    });
  });

  group('2. "Nicht interessiert" by swipe', () {
    testWidgets('the row leaves at once; a quick undo brings it back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final regular = RegularOffer(
        name: 'Haferflocken',
        offer: testOffer(id: 40, product: 'Zarte Haferflocken', brand: null),
        chainId: 'lidl',
        averageDays: 10,
      );
      var builds = 0;
      await pumpOfferScreen(
        tester,
        const WeeklyOffersScreen(regulars: true),
        overrides: [
          ...offersOn(),
          weeklyListSectionsProvider.overrideWith((ref) async => const []),
          regularOffersProvider.overrideWith((ref) async {
            builds++;
            return RegularOffers(hasStats: true, offers: [regular]);
          }),
        ],
      );
      expect(find.text('Zarte Haferflocken'), findsOneWidget);
      await tester.drag(find.text('Zarte Haferflocken'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no dismissed row left');
      expect(find.text('Zarte Haferflocken'), findsNothing);
      expect(find.textContaining('Ausgeblendet bis'), findsOneWidget);
      expect(builds, 1, reason: 'hiding searches nothing again');

      await tester.tap(find.text('Widerrufen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Zarte Haferflocken'), findsOneWidget);
    });
  });

  group('3. "Neue Liste …" from the offer detail', () {
    testWidgets('the new list gets the market and the item, with undo', (
      tester,
    ) async {
      final repo = _FakeStoreRepo();
      final notifier = RecordingItemsNotifier(const []);
      final offer = testOffer(
        id: 61,
        product: 'Haferflocken zart',
        brand: null,
      );
      final router = await pumpOfferScreen(
        tester,
        const Text('Start'),
        overrides: [
          ...offersOn(notifier: notifier),
          offerCacheProvider.overrideWith(
            (ref) => OfferCache()..remember(offer),
          ),
          offerTargetListsProvider.overrideWith((ref) => const []),
          listStoreRepositoryProvider.overrideWithValue(repo),
          // A's editor saves the preselected market itself.
          newListOpenerProvider.overrideWithValue((
            context, {
            storeChainId,
          }) async {
            if (storeChainId != null) {
              await repo.setExplicit('new-list', storeChainId);
            }
            return ShoppingListModel(
              id: 'new-list',
              name: 'Vorrat',
              ownerId: 'me',
              createdAt: DateTime(2026, 11, 9),
              updatedAt: DateTime(2026, 11, 9),
            );
          }),
        ],
      );
      router.push(offerDetailLocation(offer.id, name: 'Haferflocken'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auf die Liste'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Liste …'));
      await tester.pumpAndSettle();
      expect(repo.explicit, [('new-list', 'lidl')]);
      expect(notifier.added.single.name, 'Haferflocken');
      expect(notifier.added.single.price, offer.price);
      expect(find.text('Haferflocken auf Vorrat'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget, reason: 'S5 closed');
    });
  });

  group('4. "Angebote für {Rezept}" when a search failed', () {
    final recipe = Recipe(
      id: 'r1',
      name: 'Shakshuka',
      description: '',
      imageUrl: '',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      defaultServings: 2,
      ingredients: const [Ingredient(name: 'Paprika', amount: 1, unit: '')],
      instructions: const [],
      authorId: 'a',
      authorName: 'Avo',
      createdAt: DateTime(2026, 11, 8),
    );
    final paprika = RecipeIngredientOffer.fromStoreOffer(
      'Paprika',
      testOffer(id: 50, product: 'Paprika rot', brand: null),
    );

    Future<_RecipeSource> open(
      WidgetTester tester, {
      required List<RecipeIngredientOffer> matches,
      required bool complete,
      bool offline = false,
    }) async {
      final source = _RecipeSource(matches: matches, complete: complete);
      await pumpOfferScreen(
        tester,
        RecipeOffersScreen(
          recipeId: recipe.id,
          listId: testListId,
          recipe: recipe,
        ),
        overrides: [
          ...offersOn(),
          recipeOfferSourceProvider.overrideWithValue(source),
          isOfflineProvider.overrideWithValue(offline),
        ],
      );
      return source;
    }

    testWidgets('nothing came: "nicht geladen" with "Erneut versuchen"', (
      tester,
    ) async {
      final source = await open(tester, matches: const [], complete: false);
      expect(
        find.text('Angebote konnten gerade nicht geladen werden.'),
        findsOneWidget,
      );
      expect(find.text('Gerade nichts im Angebot.'), findsNothing);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(source.forced, 1, reason: 'past the 6-h cache');
    });

    testWidgets('some came: "nicht aktualisiert" above the rows', (
      tester,
    ) async {
      await open(tester, matches: [paprika], complete: false);
      expect(
        find.text('Angebote konnten gerade nicht aktualisiert werden.'),
        findsOneWidget,
      );
      expect(find.text('Paprika · 1'), findsOneWidget);
    });

    testWidgets('offline: the offline row, never "nichts im Angebot"', (
      tester,
    ) async {
      await open(tester, matches: const [], complete: false, offline: true);
      expect(
        find.text('Offline. Es werden nur gespeicherte Angebote gezeigt.'),
        findsOneWidget,
      );
      expect(find.text('Gerade nichts im Angebot.'), findsNothing);
    });

    testWidgets('complete and empty: "Gerade nichts im Angebot."', (
      tester,
    ) async {
      await open(tester, matches: const [], complete: true);
      expect(find.text('Gerade nichts im Angebot.'), findsOneWidget);
    });
  });

  group('5. the region keeps no coordinates', () {
    test('"Region entfernen" deletes the remembered location too', () async {
      SharedPreferences.setMockInitialValues({
        'offers_zip_code_v2': '79098',
        'offers_lat_v1': 47.99,
        'offers_lon_v1': 7.85,
        'offers_coords_fetched_at_v1': DateTime.now().toIso8601String(),
      });
      await UserLocationService.instance.removeRegion();
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'offers_zip_code_v2',
        'offers_lat_v1',
        'offers_lon_v1',
        'offers_coords_fetched_at_v1',
      ]) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      expect(prefs.getBool('offers_region_removed_v1'), isTrue);
    });

    test('stored coordinates from before go when the region is read', () async {
      SharedPreferences.setMockInitialValues({
        'offers_zip_manual': '79098',
        'offers_lat_v1': 47.99,
        'offers_lon_v1': 7.85,
        'offers_coords_fetched_at_v1': DateTime.now().toIso8601String(),
      });
      final region = await UserLocationService.instance.getRegion();
      expect(region?.zip, '79098');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('offers_lat_v1'), isFalse);
      expect(prefs.containsKey('offers_lon_v1'), isFalse);
      expect(prefs.containsKey('offers_coords_fetched_at_v1'), isFalse);
    });
  });

  testWidgets('S9 for a list that is gone shows A\'s error page', (
    tester,
  ) async {
    await pumpOfferScreen(
      tester,
      const ListOffersScreen(listId: 'gone'),
      overrides: [
        ...offersOn(),
        offerListExistsProvider.overrideWith((ref, id) => false),
      ],
    );
    expect(find.byType(RouteErrorScreen), findsOneWidget);
    expect(find.textContaining('Für welchen Markt'), findsNothing);
  });

  group('S14 and the flags', () {
    testWidgets('flags not known yet: content at once, no onDone, no timer', (
      tester,
    ) async {
      var done = 0;
      await pumpOfferScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: OffersSetupStep(onDone: () => done++),
          ),
        ),
        overrides: [
          ...offersWithRegion(FakeRegionLookup()),
          offersFlagsKnownProvider.overrideWithValue(false),
          offersRemoteEnabledProvider.overrideWithValue(false),
          offersAvailableProvider.overrideWithValue(false),
        ],
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('REGION'), findsOneWidget, reason: 'first frames');
      expect(done, 0);
      await tester.pumpAndSettle();
      expect(done, 0);
    });

    testWidgets('kill switch known off or module off: onDone in two frames', (
      tester,
    ) async {
      for (final overrides in [
        [
          ...offersWithRegion(FakeRegionLookup()),
          offersRemoteEnabledProvider.overrideWithValue(false),
          offersAvailableProvider.overrideWithValue(false),
        ],
        [
          ...offersWithRegion(FakeRegionLookup()),
          offersFlagsKnownProvider.overrideWithValue(false),
          offersRemoteEnabledProvider.overrideWithValue(false),
          offersAvailableProvider.overrideWithValue(false),
          moduleEnabledProvider.overrideWith((ref, m) => false),
        ],
      ]) {
        var done = 0;
        await pumpOfferScreen(
          tester,
          Scaffold(body: OffersSetupStep(onDone: () => done++)),
          overrides: overrides,
          settle: false,
        );
        await tester.pump();
        await tester.pump();
        expect(done, 1);
        expect(find.text('REGION'), findsNothing);
      }
    });

    testWidgets('"Weiter" with a half-typed postcode says what is missing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var done = 0;
      final lookup = FakeRegionLookup();
      await pumpOfferScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: OffersSetupStep(onDone: () => done++),
          ),
        ),
        overrides: offersWithRegion(lookup),
      );
      await tester.enterText(find.byType(EditableText), '791');
      await tester.pump();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte 5 Ziffern eingeben.'), findsOneWidget);
      expect(done, 0);
      expect(lookup.saved, isEmpty);
    });
  });
}

ItemPurchaseStats _stats(String name, String market) => ItemPurchaseStats(
  id: name,
  userId: testAccount,
  itemName: name,
  purchaseCount: 4,
  firstPurchase: DateTime(2026, 9, 1),
  lastPurchase: DateTime.now().subtract(const Duration(days: 7)),
  purchaseDates: const [],
  averageDaysBetween: 7,
  preferredRetailer: market,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

class _RecipeSource implements RecipeOfferSource {
  _RecipeSource({required this.matches, required this.complete});

  final List<RecipeIngredientOffer> matches;
  bool complete;
  int forced = 0;

  RecipeOffersResult _result(String recipeId, String zip) => RecipeOffersResult(
    recipeId: recipeId,
    zipCode: zip,
    checkedIngredientCount: 3,
    matches: matches,
    signature: 's',
    complete: complete,
  );

  @override
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) async => null;

  @override
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
    bool force = false,
  }) async {
    if (force) forced++;
    return _result(recipeId, zipCode);
  }
}
