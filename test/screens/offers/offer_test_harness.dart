// Shared fakes for the offer slot and screen tests (Teil B, S1-S16).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/data/services/user_location_service.dart'
    show RegionLookup;
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/areas/offers_routes.dart';

const String testListId = 'list-1';

/// The signed-in account in the offer tests.
const String testAccount = 'user-a';
const Region testRegion = Region(
  zip: '79098',
  city: 'Freiburg',
  source: RegionSource.manual,
);

/// An offer of Lidl valid until far in the future.
StoreOffer testOffer({
  int id = 7,
  String product = 'Frische Vollmilch 3,5 %',
  String? brand = 'Milbona',
  double price = 0.99,
  double? oldPrice = 1.19,
  String retailer = 'lidl',
  DateTime? validTo,
  double? volume = 1,
  String? unit = 'l',
  double? referencePrice,
  bool broad = false,
}) {
  final offer = StoreOffer(
    id: id,
    productName: product,
    brandName: brand,
    description: '',
    price: price,
    oldPrice: oldPrice,
    unitShortName: unit,
    retailerName: retailer == 'lidl' ? 'Lidl' : retailer.toUpperCase(),
    retailerUniqueName: retailer,
    categoryName: null,
    validFrom: DateTime.utc(2026, 1, 1),
    validTo: validTo ?? DateTime.utc(2099, 11, 14, 22),
    volume: volume,
    referencePrice: referencePrice,
  );
  return broad ? offer.asBroadMatch() : offer;
}

ShoppingItemModel testItem(
  String id,
  String name, {
  double quantity = 1,
  bool checked = false,
  double? price,
  String? retailer,
}) => ShoppingItemModel(
  id: id,
  listId: testListId,
  name: name,
  quantity: quantity,
  isChecked: checked,
  createdAt: DateTime(2026, 11, 8),
  updatedAt: DateTime(2026, 11, 8),
  price: price,
  priceRetailer: retailer,
);

/// A snapshot of Lidl that was on the device before any test started.
ListOfferSnapshot testSnapshot(Map<String, StoreOffer> byName) =>
    ListOfferSnapshot(
      chainId: 'lidl',
      zip: testRegion.zip,
      fetchedAt: DateTime(2026, 1, 1),
      offersByName: {
        for (final e in byName.entries) offerNameKey(e.key): e.value,
      },
    );

class _FakeItemRepository extends Fake implements ItemRepository {}

/// The items notifier of a list, without a server: records every write.
class RecordingItemsNotifier extends ItemsNotifier {
  RecordingItemsNotifier(List<ShoppingItemModel> items, {this.fail = false})
    : super(_FakeItemRepository(), testListId) {
    state = AsyncData(items);
  }

  /// Every write throws (a failed save).
  final bool fail;
  final updates = <(String, Map<String, dynamic>)>[];
  final added =
      <
        ({
          String name,
          double quantity,
          String? unit,
          double? price,
          String? retailer,
        })
      >[];
  final deleted = <String>[];

  @override
  Future<void> loadItems() async {}

  @override
  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    this.updates.add((itemId, updates));
    if (fail) throw Exception('offline');
  }

  /// Tokens passed to [undoPrice].
  final undonePrices = <String>[];

  /// Prices go through A's `setPrice` / `clearPrice`; recorded with the
  /// columns they write, like [updateItem].
  @override
  Future<String> setPrice(String itemId, ItemPrice price) async {
    updates.add((itemId, price.toColumns()));
    if (fail) throw Exception('offline');
    return 'price-${updates.length}';
  }

  @override
  Future<String> clearPrice(String itemId) async {
    updates.add((itemId, ItemPrice.clearedColumns));
    if (fail) throw Exception('offline');
    return 'price-${updates.length}';
  }

  @override
  Future<void> undoPrice(String token) async => undonePrices.add(token);

  @override
  Future<void> deleteItem(String itemId) async => deleted.add(itemId);

  @override
  Future<void> addItem({
    required String name,
    double quantity = 1.0,
    String? unit,
    String? category,
    String? notes,
    bool isDietWarning = false,
    String? barcode,
    double? price,
    String? priceCurrency,
    String? priceRetailer,
    String? priceUnit,
    double? priceOldValue,
    bool autoParse = true,
  }) async {
    added.add((
      name: name,
      quantity: quantity,
      unit: unit,
      price: price,
      retailer: priceRetailer,
    ));
    if (fail) throw Exception('offline');
  }
}

/// Offers on: kill switch known on, module on, list not hidden, a real
/// region, Lidl as the confirmed market, [snapshot] cached for the list.
List<Override> offersOn({
  ListOfferSnapshot? snapshot,
  List<ShoppingItemModel> items = const [],
  RecordingItemsNotifier? notifier,
  String? chainId = 'lidl',
  bool confirmed = true,
  Region? region = testRegion,
  List<StoreOffer> suggestions = const [],
  String listName = 'Wocheneinkauf',
}) => [
  offersRemoteEnabledProvider.overrideWithValue(true),
  offersFlagsKnownProvider.overrideWithValue(true),
  offersAvailableProvider.overrideWithValue(true),
  offerAccountIdProvider.overrideWithValue(testAccount),
  offersVisibleForListProvider.overrideWith((ref, id) => true),
  regionProvider.overrideWithValue(region),
  regionLoadedProvider.overrideWithValue(true),
  storeGuessForListProvider.overrideWith(
    (ref, id) async => chainId == null
        ? null
        : StoreGuess(chainId, StoreSource.user, confirmed: confirmed),
  ),
  listStoreHistoryProvider.overrideWith((ref, id) async => const []),
  nearbyStoreOptionsProvider.overrideWith((ref) async => const []),
  listOfferSnapshotProvider.overrideWith((ref, id) => snapshot),
  offerListItemsProvider.overrideWith((ref, id) => items),
  itemsNotifierProvider.overrideWith(
    (ref, id) => notifier ?? RecordingItemsNotifier(items),
  ),
  offerSuggestionsProvider.overrideWith((ref, request) async => suggestions),
  offerCategoryOfProvider.overrideWithValue((name) => 'dairy'),
  offerListNameProvider.overrideWith((ref, id) => listName),
  offerListExistsProvider.overrideWith((ref, id) => true),
  moduleEnabledProvider.overrideWith((ref, module) => true),
  isOfflineProvider.overrideWithValue(false),
  regularOffersProvider.overrideWith((ref) async => RegularOffers.none),
  regularOffersAtProvider.overrideWith(
    (ref, chainId) async => RegularOffers.none,
  ),
];

/// Pumps [child] at `/` of a router that also knows Teil B's offer routes,
/// in [locale] (German by default, the app's main language).
Future<GoRouter> pumpOffers(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('de'),
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SafeArea(child: Center(child: child)),
        ),
      ),
      ...offersRootRoutes,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      // A fresh container per pump, so saved choices load again.
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AvoToastHost(child: child!),
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: TargetPlatform.iOS),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}

/// Pumps the full screen [screen] at `/` (a stand-in list at
/// `/lists/:listId` and Teil B's offer routes next to it), so pushes and
/// pops behave as in the app.
Future<GoRouter> pumpOfferScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Locale locale = const Locale('de'),
  bool settle = true,
  List<RouteBase> routes = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
      ...routes,
      ...offersRootRoutes,
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AvoToastHost(child: child!),
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(platform: TargetPlatform.iOS),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return router;
}

/// A region source without location services: records what was saved and
/// answers "Standort verwenden" with [locateResult].
class FakeRegionLookup implements RegionLookup {
  FakeRegionLookup([this.region]);

  Region? region;
  LocateResult locateResult = const LocateResult(LocateOutcome.unavailable);
  final saved = <String>[];
  final located = <Region>[];
  var removed = 0;
  var locates = 0;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  }) async => region;

  @override
  Future<void> setManualZipCode(String zip) async {
    saved.add(zip);
    region = zip.isEmpty ? null : Region(zip: zip, source: RegionSource.manual);
  }

  @override
  Future<LocateResult> locate() async {
    locates++;
    return locateResult;
  }

  @override
  Future<void> saveLocatedRegion(Region next) async {
    located.add(next);
    region = next;
  }

  @override
  Future<void> removeRegion() async {
    removed++;
    region = null;
  }
}

/// Offers on with the real region controller over [lookup] (S11, S14).
List<Override> offersWithRegion(
  FakeRegionLookup lookup, {
  bool remote = true,
  String? account = testAccount,
}) => [
  offersRemoteEnabledProvider.overrideWithValue(remote),
  offersFlagsKnownProvider.overrideWithValue(true),
  offersAvailableProvider.overrideWithValue(remote),
  offerAccountIdProvider.overrideWithValue(account),
  regionLookupProvider.overrideWithValue(lookup),
  moduleEnabledProvider.overrideWith((ref, module) => true),
  isOfflineProvider.overrideWithValue(false),
];
