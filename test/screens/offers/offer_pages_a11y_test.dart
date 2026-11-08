// Accessibility checks for the offer screens S9-S14 (angebote.md 3.8, 3.9,
// 3.11): every tap target at least 44 × 44 pt with a label, text contrast
// AA, at the default size on a 390-pt phone, light and dark.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/offers/favorite_markets_screen.dart';
import 'package:shoply/presentation/screens/offers/list_offers_screen.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart';
import 'package:shoply/presentation/screens/offers/weekly_offers_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart';
import 'package:shoply/presentation/widgets/deals/offers_setup_step.dart';

import '../../layout/layout_matrix.dart';
import 'offer_test_harness.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      offerDisplayPrefsKeyFor(testAccount): jsonEncode({
        'favorites': ['lidl', 'rewe'],
      }),
    }),
  );

  final milk = testItem('a', 'Milch', quantity: 2);
  final snapshot = testSnapshot({'Milch': testOffer()});

  final screens = <String, (Widget, List<Override>)>{
    'S9': (
      const ListOffersScreen(listId: testListId),
      offersOn(snapshot: snapshot, items: [milk]),
    ),
    'S10': (
      const WeeklyOffersScreen(),
      [
        ...offersOn(items: [milk]),
        weeklyListSectionsProvider.overrideWith(
          (ref) async => [
            WeeklyListSection(
              listId: testListId,
              listName: 'Wocheneinkauf',
              chainId: 'lidl',
              entries: [
                ListOfferEntry(
                  item: milk,
                  offer: testOffer(product: 'Weidetrunk'),
                ),
              ],
              complete: true,
              fetchedAt: DateTime(2026, 11, 7),
              itemNames: const ['Milch'],
            ),
          ],
        ),
      ],
    ),
    'S10 without a region': (
      const WeeklyOffersScreen(),
      offersOn(region: null),
    ),
    'S11': (
      const RegionScreen(),
      offersWithRegion(
        FakeRegionLookup(
          const Region(
            zip: '79098',
            city: 'Freiburg',
            source: RegionSource.gps,
          ),
        ),
      ),
    ),
    'S12': (
      const OffersSettingsScreen(),
      [
        ...offersOn(),
        offerHiddenListsShownProvider.overrideWith(
          (ref) => [(id: testListId, name: 'Wocheneinkauf')],
        ),
      ],
    ),
    'S13': (const FavoriteMarketsScreen(), offersOn()),
    'S14': (
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: OffersSetupStep(onDone: () {}),
      ),
      offersWithRegion(FakeRegionLookup()),
    ),
  };

  for (final MapEntry(key: name, value: (screen, overrides))
      in screens.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('$name ${brightness.name}: targets, labels, contrast', (
        tester,
      ) async {
        await loadLayoutFonts();
        tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: layoutHarness(
              LayoutCase(width: 390, scale: 1, brightness: brightness),
              Builder(
                builder: (context) => Localizations.override(
                  context: context,
                  locale: const Locale('de'),
                  delegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  child: screen,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }
}
