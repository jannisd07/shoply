// Teil B, angebote.md S11 Region, S12 "Preise & Angebote", S13
// Lieblingsmärkte, S14 the onboarding step, S16 "Änderungen verwerfen?".
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/user_location_service.dart'
    show UserCoordinates;
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/offers/favorite_markets_screen.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart';
import 'package:shoply/presentation/widgets/deals/offers_setup_step.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

import 'offer_test_harness.dart';

const _freiburg = Region(
  zip: '79098',
  city: 'Freiburg',
  source: RegionSource.gps,
);

/// The prefs of [testAccount] as saved.
Future<Map<String, dynamic>> _savedPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(offerDisplayPrefsKeyFor(testAccount));
  return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
}

/// A phone-wide, tall screen, so every section is laid out.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 2000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('S11 Region', () {
    Future<void> openRegion(
      WidgetTester tester,
      FakeRegionLookup lookup, {
      bool remote = true,
      List<Override> extra = const [],
    }) async {
      final router = await pumpOfferScreen(
        tester,
        const Text('Start'),
        overrides: [
          ...offersWithRegion(lookup, remote: remote),
          ...extra,
        ],
      );
      router.push(storeRegionLocation());
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the region, "Fertig" waits for a change', (
      tester,
    ) async {
      await openRegion(tester, FakeRegionLookup(_freiburg));
      expect(find.text('Region'), findsOneWidget);
      expect(
        find.textContaining('Angebote gelten für eine Region'),
        findsOneWidget,
      );
      expect(find.text('Standort verwenden'), findsOneWidget);
      expect(find.text('Aktuell: 79098 Freiburg'), findsOneWidget);
      expect(find.text('79098'), findsOneWidget);
      expect(find.text('79098 · Freiburg'), findsOneWidget);
      expect(find.text('Region entfernen'), findsOneWidget);
      expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      expect(
        find.byType(RegionScreen),
        findsOneWidget,
        reason: 'nothing changed',
      );
      expect(find.byType(AvoFigure), findsNothing);
    });

    testWidgets('a typed zip is saved with "Fertig" and said with undo', (
      tester,
    ) async {
      final lookup = FakeRegionLookup(_freiburg);
      await openRegion(tester, lookup);
      await tester.enterText(find.byType(CupertinoTextField), '10115');
      await tester.pump();
      expect(find.text('PLZ 10115'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      expect(lookup.saved, ['10115']);
      expect(find.byType(RegionScreen), findsNothing);
      expect(find.text('Region: 10115'), findsOneWidget);
      expect(find.text('Widerrufen'), findsOneWidget);
    });

    testWidgets('five digits, and no zone 00', (tester) async {
      final lookup = FakeRegionLookup();
      await openRegion(tester, lookup);
      await tester.enterText(find.byType(CupertinoTextField), '7909');
      await tester.pump();
      expect(find.text('Bitte 5 Ziffern eingeben.'), findsNothing);
      await tester.tap(find.text('Postleitzahl'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Bitte 5 Ziffern eingeben.'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), '00123');
      await tester.pump();
      expect(find.text('Diese Postleitzahl kennen wir nicht.'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      expect(lookup.saved, isEmpty);
      expect(find.text('Region entfernen'), findsNothing, reason: 'none set');
    });

    testWidgets(
      '"Standort verwenden" fills the field, saves only on "Fertig"',
      (tester) async {
        final lookup = FakeRegionLookup()
          ..locateResult = const LocateResult(
            LocateOutcome.found,
            region: Region(zip: '89077', city: 'Ulm', source: RegionSource.gps),
          );
        await openRegion(tester, lookup);
        await tester.tap(find.text('Standort verwenden'));
        await tester.pumpAndSettle();
        expect(lookup.locates, 1);
        expect(find.text('89077'), findsOneWidget);
        expect(find.text('Aktuell: 89077 Ulm'), findsOneWidget);
        expect(lookup.located, isEmpty);
        await tester.tap(find.text('Fertig'));
        await tester.pumpAndSettle();
        expect(lookup.located.single.zip, '89077');
        expect(find.text('Region: 89077 Ulm'), findsOneWidget);
      },
    );

    testWidgets('location declined, unavailable, abroad', (tester) async {
      var settings = 0;
      final lookup = FakeRegionLookup()
        ..locateResult = const LocateResult(LocateOutcome.denied);
      await openRegion(
        tester,
        lookup,
        extra: [
          openAppSettingsProvider.overrideWithValue(() async => settings++),
        ],
      );
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Standort ist aus. In Einstellungen erlauben'),
        findsOneWidget,
      );
      await tester.tap(find.text('Einstellungen'));
      expect(settings, 1);
      expect(find.byType(CupertinoTextField), findsOneWidget, reason: 'usable');

      lookup.locateResult = const LocateResult(LocateOutcome.unavailable);
      await openRegion(tester, lookup);
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Standort gerade nicht verfügbar. Gib deine Postleitzahl ein.',
        ),
        findsOneWidget,
      );

      lookup.locateResult = const LocateResult(LocateOutcome.abroad);
      await openRegion(tester, lookup);
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Angebote gibt es nur für Deutschland.'),
        findsOneWidget,
      );
    });

    testWidgets('"Region entfernen" asks nothing, offers undo, stays open', (
      tester,
    ) async {
      final lookup = FakeRegionLookup(_freiburg);
      await openRegion(tester, lookup);
      await tester.tap(find.text('Region entfernen'));
      await tester.pumpAndSettle();
      expect(lookup.removed, 1);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('Region entfernt'), findsOneWidget);
      expect(find.byType(RegionScreen), findsOneWidget);
      expect(find.text('79098'), findsNothing, reason: 'the field is empty');
      await tester.tap(find.text('Widerrufen'));
      await tester.pumpAndSettle();
      expect(lookup.located.single, _freiburg);
    });

    testWidgets('closing with an unsaved change asks "Änderungen verwerfen?"', (
      tester,
    ) async {
      await openRegion(tester, FakeRegionLookup(_freiburg));
      await tester.enterText(find.byType(CupertinoTextField), '10115');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Schließen'));
      await tester.pumpAndSettle();
      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Weiter bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.byType(RegionScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Schließen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();
      expect(find.byType(RegionScreen), findsNothing);
    });

    testWidgets('kill switch: "Standort", not one word about offers', (
      tester,
    ) async {
      final lookup = FakeRegionLookup()
        ..locateResult = const LocateResult(LocateOutcome.abroad);
      await openRegion(tester, lookup, remote: false);
      expect(find.text('Standort'), findsOneWidget);
      expect(
        find.text(
          'Mit deinem Standort kann Avo Märkte in deiner Nähe vorschlagen.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Avo kennt bisher nur Märkte in Deutschland.'),
        findsOneWidget,
      );
      expect(find.textContaining('Angebot'), findsNothing);
    });
  });

  group('S12 Preise & Angebote', () {
    List<Override> on({
      bool module = true,
      bool remote = true,
      Region? region = testRegion,
      List<({String id, String name})> hidden = const [],
    }) => [
      ...offersOn(region: region),
      offersRemoteEnabledProvider.overrideWithValue(remote),
      moduleEnabledProvider.overrideWith((ref, m) => module),
      offerHiddenListsShownProvider.overrideWith((ref) => hidden),
    ];

    testWidgets('module on: switches, markets, region', (tester) async {
      _tall(tester);
      SharedPreferences.setMockInitialValues({
        offerDisplayPrefsKeyFor(testAccount): jsonEncode({
          'favorites': ['lidl', 'rewe'],
        }),
      });
      await pumpOfferScreen(
        tester,
        const OffersSettingsScreen(),
        overrides: on(),
      );
      expect(find.text('Preise & Angebote'), findsNWidgets(2));
      expect(
        find.text('Angebote deiner Märkte in Listen und beim Hinzufügen'),
        findsOneWidget,
      );
      expect(find.textContaining('Quelle: Händlerprospekte'), findsOneWidget);
      expect(find.text('ANZEIGEN'), findsOneWidget);
      for (final title in [
        'Angebote an Artikeln',
        'Vorschläge beim Tippen',
        'Ersparnis in der Liste',
        'Spar-Hinweise auf der Startseite',
        'Ersparnis im Verlauf und nach dem Einkauf',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('MEINE MÄRKTE'), findsOneWidget);
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('REWE'), findsOneWidget);
      expect(find.text('+ Markt'), findsOneWidget);
      expect(find.text('Markt automatisch erkennen'), findsOneWidget);
      expect(find.text('79098 Freiburg'), findsOneWidget);

      await tester.tap(find.text('Vorschläge beim Tippen'));
      await tester.pumpAndSettle();
      expect((await _savedPrefs())['off'], contains('typingSuggestions'));
      await tester.tap(find.text('Markt automatisch erkennen'));
      await tester.pumpAndSettle();
      expect((await _savedPrefs())['detectOff'], isTrue);
    });

    testWidgets('module off: "Anzeigen" folds away, markets and region stay', (
      tester,
    ) async {
      _tall(tester);
      await pumpOfferScreen(
        tester,
        const OffersSettingsScreen(),
        overrides: on(
          module: false,
          hidden: [(id: testListId, name: 'Wocheneinkauf')],
        ),
      );
      expect(find.text('ANZEIGEN'), findsNothing);
      expect(find.text('AUSGEBLENDET FÜR'), findsNothing);
      expect(find.text('MEINE MÄRKTE'), findsOneWidget);
      expect(find.text('Noch keine Lieblingsmärkte'), findsOneWidget);
      expect(find.text('Region'), findsOneWidget);
    });

    testWidgets('kill switch: "Märkte", without offers', (tester) async {
      _tall(tester);
      await pumpOfferScreen(
        tester,
        const OffersSettingsScreen(),
        overrides: on(remote: false),
      );
      expect(find.text('Märkte'), findsOneWidget);
      expect(find.text('Standort'), findsOneWidget);
      expect(find.text('Für Markt-Vorschläge'), findsOneWidget);
      expect(find.text('ANZEIGEN'), findsNothing);
      expect(find.textContaining('Angebot'), findsNothing);
      expect(find.textContaining('Händler'), findsNothing);
    });

    testWidgets('no region: "Nicht festgelegt" with a warning, said so', (
      tester,
    ) async {
      _tall(tester);
      final handle = tester.ensureSemantics();
      await pumpOfferScreen(
        tester,
        const OffersSettingsScreen(),
        overrides: on(region: null),
      );
      expect(find.text('Nicht festgelegt'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Region')).value,
        'nicht festgelegt, Warnung',
      );
      handle.dispose();
    });

    testWidgets('hidden lists come back with "Einblenden"', (tester) async {
      _tall(tester);
      SharedPreferences.setMockInitialValues({
        'offers_hidden_lists_v1:$testAccount': [testListId],
      });
      await pumpOfferScreen(
        tester,
        const OffersSettingsScreen(),
        overrides: on(hidden: [(id: testListId, name: 'Wocheneinkauf')]),
      );
      expect(find.text('AUSGEBLENDET FÜR'), findsOneWidget);
      await tester.tap(find.text('Einblenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Angebote für Wocheneinkauf eingeblendet'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('offers_hidden_lists_v1:$testAccount'),
        isEmpty,
      );
    });
  });

  group('S13 Lieblingsmärkte', () {
    testWidgets('pick, order, remove with undo', (tester) async {
      _tall(tester);
      final handle = tester.ensureSemantics();
      await pumpOfferScreen(
        tester,
        const FavoriteMarketsScreen(),
        overrides: offersOn(),
      );
      expect(find.text('Lieblingsmärkte'), findsOneWidget);
      expect(find.text('Noch keine Lieblingsmärkte.'), findsOneWidget);
      expect(find.text('WEITERE MÄRKTE'), findsOneWidget);
      expect(find.text('Markt suchen'), findsOneWidget, reason: '13 chains');

      await tester.tap(find.text('Lidl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REWE'));
      await tester.pumpAndSettle();
      expect(find.text('DEINE MÄRKTE'), findsOneWidget);
      // A's ReorderableInsetSection: the handle carries name, position and
      // the move actions; the SelectCircle is a switch named after the
      // market.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lidl umsortieren')),
        matchesSemantics(
          label: 'Lidl umsortieren',
          value: 'Position 1 von 2',
          customActions: [const CustomSemanticsAction(label: 'Nach unten')],
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lidl')),
        matchesSemantics(
          label: 'Lidl',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect((await _savedPrefs())['favorites'], ['lidl', 'rewe']);

      tester.semantics.customAction(
        find.semantics.byLabel('Lidl umsortieren'),
        CustomSemanticsAction(label: 'Nach unten'),
      );
      await tester.pumpAndSettle();
      expect((await _savedPrefs())['favorites'], ['rewe', 'lidl']);

      await tester.tap(find.text('REWE'));
      await tester.pumpAndSettle();
      expect(find.text('REWE entfernt'), findsOneWidget);
      expect((await _savedPrefs())['favorites'], ['lidl']);
      await tester.tap(find.text('Widerrufen'));
      await tester.pumpAndSettle();
      expect((await _savedPrefs())['favorites'], ['rewe', 'lidl']);
      handle.dispose();
    });

    testWidgets('search finds a typo; kill switch keeps its note', (
      tester,
    ) async {
      _tall(tester);
      await pumpOfferScreen(
        tester,
        const FavoriteMarketsScreen(),
        overrides: [
          ...offersOn(),
          offersRemoteEnabledProvider.overrideWithValue(false),
        ],
      );
      expect(
        find.text(
          'Diese Märkte stehen oben, wenn du für eine Liste einen Markt wählst.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(CupertinoTextField).first, 'lidel');
      await tester.pumpAndSettle();
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.text('REWE'), findsNothing);
    });
  });

  group('S14 OffersSetupStep', () {
    Future<void> pumpStep(
      WidgetTester tester,
      List<Override> overrides, {
      required VoidCallback onDone,
    }) => pumpOfferScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: OffersSetupStep(onDone: onDone),
        ),
      ),
      overrides: overrides,
    );

    testWidgets('region, markets in their order, notes and "Weiter"', (
      tester,
    ) async {
      _tall(tester);
      var done = 0;
      await pumpStep(
        tester,
        offersWithRegion(FakeRegionLookup()),
        onDone: () => done++,
      );
      expect(done, 0, reason: 'it has something to show');
      expect(find.text('REGION'), findsOneWidget);
      expect(find.text('Standort verwenden'), findsOneWidget);
      expect(
        find.textContaining('Einmalig, um Region und Märkte'),
        findsOneWidget,
      );
      expect(find.text('z. B. 10437'), findsOneWidget);
      expect(find.text('DEINE MÄRKTE'), findsOneWidget);
      final order = [
        for (final name in [
          'Lidl',
          'Aldi',
          'REWE',
          'Edeka',
          'Kaufland',
          'Netto',
          'PENNY',
        ])
          tester.getTopLeft(find.text(name)),
      ];
      for (var i = 1; i < order.length; i++) {
        final before = order[i - 1];
        final now = order[i];
        expect(
          now.dy > before.dy || (now.dy == before.dy && now.dx > before.dx),
          isTrue,
          reason: 'fixed order',
        );
      }
      expect(find.textContaining('Prospekten der Händler'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);
      expect(find.byType(AvoFigure), findsNothing);
    });

    testWidgets('a zip makes Aldi the Aldi of the region; "Weiter" saves', (
      tester,
    ) async {
      _tall(tester);
      final lookup = FakeRegionLookup();
      var done = 0;
      await pumpStep(tester, offersWithRegion(lookup), onDone: () => done++);
      await tester.enterText(find.byType(CupertinoTextField), '79098');
      await tester.pump();
      expect(find.text('Aldi Süd'), findsOneWidget);
      await tester.tap(find.text('Lidl'));
      await tester.tap(find.text('Aldi Süd'));
      await tester.pump();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(lookup.saved, ['79098']);
      expect((await _savedPrefs())['favorites'], ['lidl', 'aldi-sued']);
      expect(done, 1);
    });

    testWidgets('signed out the markets wait on the device for the account', (
      tester,
    ) async {
      _tall(tester);
      await pumpStep(
        tester,
        offersWithRegion(FakeRegionLookup(), account: null),
        onDone: () {},
      );
      await tester.tap(find.text('REWE'));
      await tester.pump();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(pendingFavoriteStoresKey), ['rewe']);
    });

    testWidgets('the location brings the nearest markets first, once', (
      tester,
    ) async {
      _tall(tester);
      final lookup = FakeRegionLookup()
        ..locateResult = const LocateResult(
          LocateOutcome.found,
          region: Region(
            zip: '10437',
            city: 'Berlin',
            source: RegionSource.gps,
          ),
          coordinates: UserCoordinates(52.54, 13.41),
        );
      await pumpStep(tester, [
        ...offersWithRegion(lookup),
        nearbyStoresAtProvider.overrideWith(
          (ref, at) async => const [
            NearbyStoreOption(chainId: 'rewe', distanceMeters: 400),
            NearbyStoreOption(chainId: 'penny', distanceMeters: 900),
          ],
        ),
      ], onDone: () {});
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(find.text('10437 · Berlin'), findsOneWidget);
      final rewe = tester.getTopLeft(find.textContaining('REWE'));
      final lidl = tester.getTopLeft(find.text('Lidl'));
      expect(
        rewe.dy < lidl.dy || (rewe.dy == lidl.dy && rewe.dx < lidl.dx),
        isTrue,
      );
      expect(find.textContaining('400 m'), findsOneWidget);
    });

    testWidgets('location declined says how to go on', (tester) async {
      _tall(tester);
      final lookup = FakeRegionLookup()
        ..locateResult = const LocateResult(LocateOutcome.denied);
      await pumpStep(tester, offersWithRegion(lookup), onDone: () {});
      await tester.tap(find.text('Standort verwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Standort ist aus. Gib deine Postleitzahl ein oder erlaube ihn in '
          'den Einstellungen.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('kill switch: nothing shown, A moves on', (tester) async {
      var done = 0;
      await pumpStep(
        tester,
        offersWithRegion(FakeRegionLookup(), remote: false),
        onDone: () => done++,
      );
      expect(find.text('REGION'), findsNothing);
      expect(done, 1);
    });
  });
}
