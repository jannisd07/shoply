import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/calories/log_recipe.dart';
import 'package:shoply/presentation/screens/history/checkout/checkout_flow.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_offer_card.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_count_badge.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_offer_summary.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
import 'package:shoply/presentation/screens/lists/widgets/store_chip.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_offers_card.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/article_image.dart';
import 'package:shoply/presentation/widgets/deals/offers_setup_step.dart';

/// P0.3 (request A-2, contract 3.3): the slot widgets Teil A builds the new
/// screens against. Offer slots stay empty, and never ask the offers source,
/// while offers are off (module, kill switch) or hidden on the list.
void main() {
  const listId = 'list-1';

  final item = ShoppingItemModel(
    id: 'item-1',
    listId: listId,
    name: 'Milch',
    createdAt: DateTime(2026, 11, 7),
    updatedAt: DateTime(2026, 11, 7),
  );

  final recipe = Recipe(
    id: 'recipe-1',
    name: 'Pfannkuchen',
    description: '',
    imageUrl: '',
    prepTimeMinutes: 10,
    cookTimeMinutes: 10,
    defaultServings: 2,
    ingredients: const [Ingredient(name: 'Milch', amount: 250, unit: 'ml')],
    instructions: const [],
    authorId: 'author-1',
    authorName: 'Avo',
    createdAt: DateTime(2026, 11, 7),
    nutrition: const NutritionInfo(calories: 420, proteinG: 12),
  );

  final offer = StoreOffer(
    id: 7,
    productName: 'Weidemilch 1,5 %',
    brandName: null,
    description: '',
    price: 0.99,
    oldPrice: 1.29,
    unitShortName: 'l',
    retailerName: 'Lidl',
    retailerUniqueName: 'lidl',
    categoryName: 'Milch',
    validFrom: DateTime(2026, 11, 2),
    validTo: DateTime(2026, 11, 30),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('offer slots stay empty while offers are unavailable', () {
    late _OfferSourceSpy spy;

    setUp(() => spy = _OfferSourceSpy(offer));

    List<Override> offersOff() => [
      offersAvailableProvider.overrideWithValue(false),
      ...spy.overrides,
    ];

    testWidgets('OfferSuggestionsBar', (tester) async {
      await _pumpSlot(
        tester,
        OfferSuggestionsBar(listId: listId, query: 'milch'),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(OfferSuggestionsBar));
      expect(spy.calls, 0, reason: 'no request to the offers source');
    });

    testWidgets('RecipeOffersCard(recipe:)', (tester) async {
      await _pumpSlot(
        tester,
        RecipeOffersCard(recipe: recipe),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(RecipeOffersCard));
      expect(spy.calls, 0);
    });

    testWidgets('RecipeOfferSummary(recipe:, listId:)', (tester) async {
      await _pumpSlot(
        tester,
        RecipeOfferSummary(recipe: recipe, listId: listId),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(RecipeOfferSummary));
      expect(spy.calls, 0);
    });

    testWidgets('IngredientOfferBadge(listId:, ingredient:)', (tester) async {
      await _pumpSlot(
        tester,
        IngredientOfferBadge(
          listId: listId,
          ingredient: recipe.ingredients.first,
        ),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(IngredientOfferBadge));
      expect(spy.calls, 0);
    });

    testWidgets('ItemOfferBadge', (tester) async {
      await _pumpSlot(
        tester,
        ItemOfferBadge(listId: listId, item: item),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(ItemOfferBadge));
    });

    testWidgets('ListOfferSummary', (tester) async {
      await _pumpSlot(
        tester,
        const ListOfferSummary(listId: listId),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(ListOfferSummary));
    });

    testWidgets('OffersSetupStep', (tester) async {
      await _pumpSlot(
        tester,
        OffersSetupStep(onDone: () {}),
        overrides: offersOff(),
      );
      _expectEmpty(tester, find.byType(OffersSetupStep));
    });
  });

  group('offers hidden on one list', () {
    testWidgets('OfferSuggestionsBar stays empty and asks nothing', (
      tester,
    ) async {
      final spy = _OfferSourceSpy(offer);
      SharedPreferences.setMockInitialValues({
        hiddenOfferListsPrefsKey: [listId],
      });
      await _pumpSlot(
        tester,
        OfferSuggestionsBar(listId: listId, query: 'milch'),
        overrides: [
          offersAvailableProvider.overrideWithValue(true),
          ...spy.overrides,
        ],
      );
      _expectEmpty(tester, find.byType(OfferSuggestionsBar));
      expect(spy.calls, 0);
    });
  });

  group('OfferSuggestionsBar with offers on', () {
    testWidgets('shows the offers of the query', (tester) async {
      final spy = _OfferSourceSpy(offer);
      await _pumpSlot(
        tester,
        OfferSuggestionsBar(listId: listId, query: 'milch'),
        overrides: [
          offersAvailableProvider.overrideWithValue(true),
          ...spy.overrides,
        ],
      );
      expect(find.text('Weidemilch 1,5 %'), findsOneWidget);
    });

    testWidgets('adds the tapped offer to its list', (tester) async {
      final spy = _OfferSourceSpy(offer);
      final items = _RecordingItemsNotifier(listId);
      await _pumpSlot(
        tester,
        const OfferSuggestionsBar(listId: listId, query: 'milch'),
        overrides: [
          offersAvailableProvider.overrideWithValue(true),
          currentUserProvider.overrideWith((ref) async => null),
          itemsNotifierProvider.overrideWith((ref, id) => items),
          ...spy.overrides,
        ],
      );
      await tester.tap(find.text('Weidemilch 1,5 %'));
      await tester.pump();

      expect(items.added, hasLength(1));
      expect(
        items.added.single.name,
        'milch',
        reason: 'the item keeps the name as typed, not the product name',
      );
      expect(items.added.single.price, 0.99);
      expect(items.added.single.retailer, 'Lidl');
      expect(
        items.added.single.autoParse,
        isFalse,
        reason: 'the typed text was parsed already',
      );
    });
  });

  group('offers on, but the source has nothing: the item slots render '
      'nothing', () {
    late _EmptySource source;

    setUp(() => source = _EmptySource());

    /// Kill switch known on, module on, list not hidden, a real region and
    /// Lidl as the confirmed market: only the empty source keeps them empty.
    List<Override> offersOnNoData() => [
      offersRemoteEnabledProvider.overrideWithValue(true),
      offersAvailableProvider.overrideWithValue(true),
      offerAccountIdProvider.overrideWithValue('me'),
      regionLoadedProvider.overrideWithValue(true),
      regionProvider.overrideWithValue(
        const Region(zip: '80331', source: RegionSource.manual),
      ),
      storeForListProvider.overrideWith(
        (ref, listId) =>
            const StoreInfo(id: 'lidl', name: 'Lidl', shortLabel: 'L'),
      ),
      cachedStoreOfListProvider.overrideWith((ref, id) => 'lidl'),
      offerListItemsProvider.overrideWith((ref, id) => [item]),
      offerPriceServiceProvider.overrideWithValue(source),
    ];

    testWidgets('ItemOfferBadge, also compact', (tester) async {
      await _pumpSlot(
        tester,
        Column(
          children: [
            ItemOfferBadge(listId: listId, item: item),
            ItemOfferBadge(listId: listId, item: item, compact: true),
          ],
        ),
        overrides: offersOnNoData(),
      );
      for (final badge in tester.widgetList(find.byType(ItemOfferBadge))) {
        _expectEmpty(tester, find.byWidget(badge));
      }
      expect(source.calls, greaterThan(0), reason: 'the gate was open');
    });

    testWidgets('ItemOfferCard', (tester) async {
      await _pumpSlot(
        tester,
        ItemOfferCard(listId: listId, item: item),
        overrides: offersOnNoData(),
      );
      _expectEmpty(tester, find.byType(ItemOfferCard));
      expect(source.calls, greaterThan(0), reason: 'the gate was open');
    });

    testWidgets('ListOfferCountBadge (nothing cached, nothing asked)', (
      tester,
    ) async {
      await _pumpSlot(
        tester,
        const ListOfferCountBadge(listId: listId),
        overrides: offersOnNoData(),
      );
      _expectEmpty(tester, find.byType(ListOfferCountBadge));
      expect(source.calls, 0, reason: 'a list card reads the cache only');
    });
  });

  testWidgets('StoreChip is core: "Choose store" with offers off too', (
    tester,
  ) async {
    await _pumpSlot(
      tester,
      const StoreChip(listId: listId),
      overrides: [
        offersAvailableProvider.overrideWithValue(false),
        storeGuessForListProvider.overrideWith((ref, id) async => null),
      ],
    );
    expect(find.text('Choose store'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose store'), findsOneWidget);
  });

  testWidgets('OffersSetupStep moves on by itself, exactly once', (
    tester,
  ) async {
    // Kill switch known off: "nothing to show" is onDone within two frames.
    var done = 0;
    await _pumpSlot(
      tester,
      OffersSetupStep(onDone: () => done++),
      overrides: [offersKillSwitchOffProvider.overrideWithValue(true)],
    );
    await tester.pump();
    expect(done, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(done, 1, reason: 'exactly once');
  });

  testWidgets('ArticleImage keeps its final size as a neutral square', (
    tester,
  ) async {
    await _pumpSlot(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArticleImage(item: item),
          ArticleImage(item: item, size: 52, radius: 12),
        ],
      ),
    );
    final sizes = [
      for (final e in find.byType(ArticleImage).evaluate())
        tester.getSize(find.byWidget(e.widget)),
    ];
    expect(sizes, [const Size.square(44), const Size.square(52)]);
  });

  group('offersHiddenForListProvider', () {
    test('is false for a list nobody hid', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(offersHiddenForListProvider(listId)), isFalse);
    });

    testWidgets(
      'setOffersHiddenForList hides and shows again, saved for the account',
      (tester) async {
        final (container, ref) = await _widgetRef(tester);

        await tester.runAsync(() => setOffersHiddenForList(ref, listId, true));
        expect(container.read(offersHiddenForListProvider(listId)), isTrue);
        expect(container.read(offersHiddenForListProvider('other')), isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(hiddenOfferListsKeyFor('me')), [listId]);

        await tester.runAsync(() => setOffersHiddenForList(ref, listId, false));
        expect(container.read(offersHiddenForListProvider(listId)), isFalse);
        expect(prefs.getStringList(hiddenOfferListsKeyFor('me')), isEmpty);
      },
    );

    testWidgets('moves the device-wide choice to the account once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        hiddenOfferListsPrefsKey: ['old-list'],
      });
      final (container, ref) = await _widgetRef(tester);

      await tester.runAsync(() => setOffersHiddenForList(ref, listId, true));

      expect(container.read(offersHiddenForListProvider('old-list')), isTrue);
      expect(container.read(offersHiddenForListProvider(listId)), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(hiddenOfferListsKeyFor('me')),
        unorderedEquals(['old-list', listId]),
      );
      expect(prefs.getStringList(hiddenOfferListsPrefsKey), isNull);
    });
  });

  group('openCheckoutFlow', () {
    testWidgets('pushes a full-screen route and closes it when cancelled', (
      tester,
    ) async {
      final observer = _PushObserver();
      final runs = <String>[];
      await _pumpLauncher(
        tester,
        (context) => openCheckoutFlow(context, listId),
        observer: observer,
        overrides: [
          checkoutRunnerProvider.overrideWithValue((context, ref, id) async {
            runs.add(id);
            return false;
          }),
        ],
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      _expectFullScreenPush(observer);

      await tester.pumpAndSettle();
      expect(runs, [listId]);
      expect(find.text('open'), findsOneWidget, reason: 'back on the list');
      expect(_LauncherResult.last, isFalse);
    });

    testWidgets('closes with true right after the trip was saved', (
      tester,
    ) async {
      await _pumpLauncher(
        tester,
        (context) => openCheckoutFlow(context, listId),
        overrides: [
          checkoutRunnerProvider.overrideWithValue(
            (context, ref, id) async => true,
          ),
        ],
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text('open'),
        findsOneWidget,
        reason: 'no confirmation of its own',
      );
      expect(_LauncherResult.last, isTrue);
    });
  });

  group('openLogRecipe', () {
    testWidgets('pushes the full-screen diary entry', (tester) async {
      final observer = _PushObserver();
      await _pumpLauncher(
        tester,
        (context) => openLogRecipe(context, recipe),
        observer: observer,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      _expectFullScreenPush(observer);
      expect(find.byType(LogRecipeScreen), findsOneWidget);
      expect(find.text('Log to diary'), findsOneWidget);
      expect(find.text('Pfannkuchen'), findsOneWidget);
      expect(find.text('420 kcal'), findsOneWidget);
    });

    testWidgets('servings change in half steps, never below one half', (
      tester,
    ) async {
      await _pumpLauncher(tester, (context) => openLogRecipe(context, recipe));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Half a serving more'));
      await tester.pump();
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('630 kcal'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Half a serving less'));
        await tester.pump();
      }
      expect(find.text('0.5'), findsOneWidget);
      expect(find.text('210 kcal'), findsOneWidget);
    });

    testWidgets('does nothing for a recipe without nutrition values', (
      tester,
    ) async {
      final observer = _PushObserver();
      final plain = recipe.copyWith(nutrition: const NutritionInfo());
      await _pumpLauncher(
        tester,
        (context) => openLogRecipe(context, plain),
        observer: observer,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(observer.pushed, hasLength(1), reason: 'only the home route');
      expect(find.byType(LogRecipeScreen), findsNothing);
    });
  });
}

/// A [WidgetRef] from a mounted [Consumer], as Teil A's list menu has one.
Future<(ProviderContainer, WidgetRef)> _widgetRef(WidgetTester tester) async {
  late WidgetRef captured;
  final container = ProviderContainer(
    overrides: [offerAccountIdProvider.overrideWithValue('me')],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (container, captured);
}

Future<void> _pumpSlot(
  WidgetTester tester,
  Widget slot, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: Center(child: slot)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// What the last launcher call completed with (openCheckoutFlow's bool).
abstract final class _LauncherResult {
  static Object? last;
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open, {
  _PushObserver? observer,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async =>
                    _LauncherResult.last = await open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _expectEmpty(WidgetTester tester, Finder slot) {
  expect(slot, findsOneWidget);
  expect(tester.getSize(slot), Size.zero);
  expect(find.descendant(of: slot, matching: find.byType(Text)), findsNothing);
}

void _expectFullScreenPush(_PushObserver observer) {
  expect(observer.pushed, hasLength(2), reason: 'home route plus one push');
  final route = observer.pushed.last;
  expect(route, isA<PageRoute<dynamic>>(), reason: 'a page, not a sheet');
  expect((route as PageRoute<dynamic>).opaque, isTrue);
  expect(
    route.fullscreenDialog,
    isFalse,
    reason: 'pushed like a screen, never sliding up',
  );
}

class _PushObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

/// Counts every read of the offers source behind the offer slots.
class _OfferSourceSpy {
  _OfferSourceSpy(this.offer);

  final StoreOffer offer;
  int calls = 0;

  /// The kill switch is known to be on, so only [offersAvailableProvider]
  /// (module) decides.
  List<Override> get overrides => [
    offersRemoteEnabledProvider.overrideWithValue(true),
    offerAccountIdProvider.overrideWithValue('me'),
    regionLoadedProvider.overrideWithValue(true),
    regionProvider.overrideWithValue(
      const Region(zip: '80331', source: RegionSource.manual),
    ),
    storeForListProvider.overrideWith(
      (ref, listId) =>
          const StoreInfo(id: 'lidl', name: 'Lidl', shortLabel: 'L'),
    ),
    offerSuggestionsProvider.overrideWith((ref, request) async {
      calls++;
      return [offer];
    }),
    recipeOfferSourceProvider.overrideWithValue(_RecipeSourceSpy(this)),
  ];
}

class _FakeItemRepository extends Fake implements ItemRepository {}

typedef _Added = ({
  String name,
  double? price,
  String? retailer,
  bool autoParse,
});

/// Records adds instead of writing; never loads from the server.
class _RecordingItemsNotifier extends ItemsNotifier {
  _RecordingItemsNotifier(String listId) : super(_FakeItemRepository(), listId);

  final added = <_Added>[];

  @override
  Future<void> loadItems() async {}

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
      price: price,
      retailer: priceRetailer,
      autoParse: autoParse,
    ));
  }
}

/// An offers source that knows nothing; counts every search.
class _EmptySource extends Fake implements OfferPriceService {
  int calls = 0;

  @override
  Future<List<StoreOffer>?> trySearchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    calls++;
    return const [];
  }

  @override
  Future<List<StoreOffer>> searchOffers(
    String query, {
    required String zipCode,
    String? chainId,
    int limit = 30,
  }) async {
    calls++;
    return const [];
  }
}

/// Counts every recipe offer lookup, cached or not.
class _RecipeSourceSpy implements RecipeOfferSource {
  _RecipeSourceSpy(this.spy);

  final _OfferSourceSpy spy;

  @override
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) async {
    spy.calls++;
    return null;
  }

  @override
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
    bool force = false,
  }) async {
    spy.calls++;
    return RecipeOffersResult(
      recipeId: recipeId,
      zipCode: zipCode,
      checkedIngredientCount: 0,
      matches: const [],
      signature: '',
    );
  }
}
