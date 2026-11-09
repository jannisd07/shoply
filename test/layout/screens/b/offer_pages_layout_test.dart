// Layout matrix (widths 320-440 pt, text 1.0-3.1, bold, dark, contrast) for
// the offer screens S9-S15 and their B building blocks (angebote.md 3.10):
// no overflow, no clipped text, in German, where the texts are longest.
// Each case also checks that the screen really rendered its content.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/offers/favorite_markets_screen.dart';
import 'package:shoply/presentation/screens/offers/list_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/recipe_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart';
import 'package:shoply/presentation/screens/offers/weekly_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_entry_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_filter_chip.dart';
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_offers_card.dart';
import 'package:shoply/presentation/widgets/deals/offers_setup_step.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

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

/// Saved choices and providers load over a few frames; then [text] is there.
Future<void> Function(WidgetTester) _shows(String text) => (tester) async {
  await tester.pumpAndSettle();
  expect(find.textContaining(text, skipOffstage: false), findsWidgets);
};

const _gps = Region(
  zip: '79098',
  city: 'Freiburg im Breisgau',
  source: RegionSource.gps,
);

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      offerDisplayPrefsKeyFor(testAccount): jsonEncode({
        'favorites': ['lidl', 'netto-marken-discount', 'aldi-sued'],
      }),
    }),
  );

  final milk = testItem(
    'a',
    'Haferdrink ungesüßt Barista Edition',
    quantity: 2,
  );
  final long = testOffer(
    product: 'Haferdrink Barista Edition ungesüßt mit Calcium',
    brand: 'Vemondo',
    referencePrice: 1.29,
    price: 1.29,
    oldPrice: 1.79,
    validTo: DateTime.now().add(const Duration(days: 1)),
  );
  final snapshot = testSnapshot({milk.name: long});
  final items = [
    milk,
    for (var i = 0; i < 10; i++) testItem('x$i', 'Artikel $i'),
  ];
  final regular = RegularOffer(
    name: 'Kichererbsen',
    offer: testOffer(
      id: 41,
      product: 'Kichererbsen in Bio-Qualität, abgetropft',
      brand: 'Freshona',
      retailer: 'netto-marken-discount',
      price: 0.79,
      oldPrice: null,
    ),
    chainId: 'netto-marken-discount',
    averageDays: 14,
  );

  layoutMatrix('S9 ListOffersScreen', (context) {
    return SizedBox.expand(
      child: _de(
        const ListOffersScreen(listId: testListId),
        overrides: [
          ...offersOn(snapshot: snapshot, items: items),
          regularOffersAtProvider.overrideWith(
            (ref, chain) async => RegularOffers(
              hasStats: true,
              offers: [
                RegularOffer(
                  name: 'Kichererbsen',
                  offer: regular.offer,
                  chainId: 'lidl',
                  averageDays: 14,
                ),
              ],
            ),
          ),
          regularOffersProvider.overrideWith(
            (ref) async => RegularOffers(
              hasStats: true,
              offers: [
                RegularOffer(
                  name: 'Kichererbsen',
                  offer: regular.offer,
                  chainId: 'lidl',
                  averageDays: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }, afterPump: _shows('Angebote bei Lidl'));

  layoutMatrix('S9 without a region', (context) {
    return SizedBox.expand(
      child: _de(
        const ListOffersScreen(listId: testListId),
        overrides: offersOn(region: null),
      ),
    );
  }, afterPump: _shows('Für Angebote brauchst du eine Region.'));

  WeeklyListSection section() => WeeklyListSection(
    listId: testListId,
    listName: 'Wocheneinkauf für die ganze Familie',
    chainId: 'lidl',
    entries: [ListOfferEntry(item: milk, offer: long)],
    complete: true,
    fetchedAt: DateTime(2026, 11, 7, 9, 30),
    itemNames: [milk.name],
  );

  layoutMatrix('S10 WeeklyOffersScreen, Deine Listen', (context) {
    return SizedBox.expand(
      child: _de(
        const WeeklyOffersScreen(),
        overrides: [
          ...offersOn(region: _gps),
          weeklyListSectionsProvider.overrideWith((ref) async => [section()]),
        ],
      ),
    );
  }, afterPump: _shows('In deiner Region · 79098 Freiburg im Breisgau'));

  layoutMatrix('S10 Oft gekauft', (context) {
    return SizedBox.expand(
      child: _de(
        const WeeklyOffersScreen(regulars: true),
        overrides: [
          ...offersOn(),
          weeklyListSectionsProvider.overrideWith((ref) async => const []),
          regularOffersProvider.overrideWith(
            (ref) async => RegularOffers(hasStats: true, offers: [regular]),
          ),
        ],
      ),
    );
  }, afterPump: _shows('Kaufst du etwa alle 14 Tage'));

  layoutMatrix('S10 without a region', (context) {
    return SizedBox.expand(
      child: _de(const WeeklyOffersScreen(), overrides: offersOn(region: null)),
    );
  }, afterPump: _shows('Wo kaufst du ein?'));

  layoutMatrix('S10 search without a hit', (context) {
    return SizedBox.expand(
      child: _de(
        const WeeklyOffersScreen(query: 'Kichererbsen-Hummus mit Paprika'),
        overrides: [
          ...offersOn(),
          weeklyListSectionsProvider.overrideWith((ref) async => const []),
          weeklyOfferSearchProvider.overrideWith((ref, key) async => const []),
        ],
      ),
    );
  }, afterPump: _shows('Kein Angebot für'));

  layoutMatrix('S11 RegionScreen with a region', (context) {
    return SizedBox.expand(
      child: _de(
        const RegionScreen(fullScreen: true),
        overrides: offersWithRegion(FakeRegionLookup(_gps)),
      ),
    );
  }, afterPump: _shows('79098 · Freiburg im Breisgau'));

  layoutMatrix('S11 RegionScreen with an unknown postcode', (context) {
    return SizedBox.expand(
      child: _de(
        const RegionScreen(),
        overrides: offersWithRegion(
          FakeRegionLookup(
            const Region(zip: '00999', source: RegionSource.manual),
          ),
        ),
      ),
    );
  }, afterPump: _shows('Diese Postleitzahl kennen wir nicht.'));

  layoutMatrix('S12 OffersSettingsScreen', (context) {
    return SizedBox.expand(
      child: _de(
        const OffersSettingsScreen(),
        overrides: [
          ...offersOn(region: null),
          offerHiddenListsShownProvider.overrideWith(
            (ref) => [(id: testListId, name: 'Wocheneinkauf für die Familie')],
          ),
        ],
      ),
    );
  }, afterPump: _shows('Nicht festgelegt'));

  layoutMatrix('S12 with the kill switch', (context) {
    return SizedBox.expand(
      child: _de(
        const OffersSettingsScreen(),
        overrides: [
          ...offersOn(),
          offersRemoteEnabledProvider.overrideWithValue(false),
          offerHiddenListsShownProvider.overrideWith((ref) => const []),
        ],
      ),
    );
  }, afterPump: _shows('Für Markt-Vorschläge'));

  layoutMatrix('S13 FavoriteMarketsScreen', (context) {
    return SizedBox.expand(
      child: _de(const FavoriteMarketsScreen(), overrides: offersOn()),
    );
  }, afterPump: _shows('WEITERE MÄRKTE'));

  layoutMatrix(
    'S14 OffersSetupStep in the step frame',
    (context) {
      return _de(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OffersSetupStep(onDone: () {}),
        ),
        overrides: offersWithRegion(FakeRegionLookup(_gps)),
      );
    },
    scrollable: true,
    afterPump: _shows('Wähl, wo du meistens einkaufst.'),
  );

  final recipe = Recipe(
    id: 'r1',
    name: 'Shakshuka mit gerösteter Paprika und Feta',
    description: '',
    imageUrl: '',
    prepTimeMinutes: 10,
    cookTimeMinutes: 25,
    defaultServings: 2,
    ingredients: const [
      Ingredient(name: 'rote Spitzpaprika', amount: 2, unit: ''),
      Ingredient(name: 'passierte Tomaten', amount: 400, unit: 'g'),
      Ingredient(name: 'Eier', amount: 4, unit: ''),
    ],
    instructions: const [],
    authorId: 'a',
    authorName: 'Avo',
    createdAt: DateTime(2026, 11, 8),
  );
  final matches = [
    RecipeIngredientOffer.fromStoreOffer('rote Spitzpaprika', long),
    RecipeIngredientOffer.fromStoreOffer(
      'passierte Tomaten',
      testOffer(id: 8, product: 'Passierte Tomaten', brand: 'Baresa'),
    ),
  ];
  final source = _Source(
    RecipeOffersResult(
      recipeId: recipe.id,
      zipCode: testRegion.zip,
      checkedIngredientCount: 3,
      matches: matches,
      signature: 's',
    ),
  );

  layoutMatrix(
    'S15 RecipeOfferSummary in the ingredients group',
    (context) {
      return _de(
        InsetSection(
          children: [RecipeOfferSummary(recipe: recipe, listId: testListId)],
        ),
        overrides: [
          ...offersOn(listName: 'Wocheneinkauf für die Familie'),
          recipeOfferSourceProvider.overrideWithValue(source),
        ],
      );
    },
    scrollable: true,
    afterPump: _shows('2 Zutaten diese Woche bei Lidl im Angebot'),
  );

  layoutMatrix('S15 RecipeOffersScreen', (context) {
    return SizedBox.expand(
      child: _de(
        RecipeOffersScreen(
          recipeId: recipe.id,
          listId: testListId,
          recipe: recipe,
        ),
        overrides: [
          ...offersOn(),
          recipeOfferSourceProvider.overrideWithValue(source),
          recipeServingsProvider.overrideWith((ref, id) => 4),
        ],
      ),
    );
  }, afterPump: _shows('2 von 3 Zutaten'));

  layoutMatrix(
    'StoreFilterChip and an OfferRow with plus',
    (context) {
      return _de(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                StoreFilterChip(
                  chainId: 'netto-marken-discount',
                  label: 'Netto',
                  distance: '1,2 km',
                  selected: true,
                  multiple: true,
                  onTap: () {},
                ),
                StoreFilterChip(
                  chainId: 'aldi-sued',
                  label: 'Aldi Süd',
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
            InsetSection(
              children: [
                Builder(
                  builder: (context) => offerEntryRow(
                    context,
                    offer: long,
                    title: offerLongTitle,
                    lines: [
                      OfferLines.details(long, 'de')!,
                      OfferLines.flag(long, 'de')!,
                    ],
                    onTap: () {},
                    onAdd: (_) {},
                    addLabel: 'Auf die Liste',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
    scrollable: true,
    afterPump: _shows('endet morgen'),
  );
}

const offerLongTitle =
    'Vemondo Haferdrink Barista Edition ungesüßt mit Calcium';

class _Source implements RecipeOfferSource {
  _Source(this.result);

  final RecipeOffersResult result;

  @override
  Future<RecipeOffersResult?> cachedOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
  }) async => result;

  @override
  Future<RecipeOffersResult> getOffers({
    required String recipeId,
    required List<String> ingredientNames,
    required String zipCode,
    String? chainId,
    bool force = false,
  }) async => result;
}
