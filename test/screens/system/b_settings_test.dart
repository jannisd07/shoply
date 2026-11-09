// A8 requests 1 and 2: Teil B's settings pages are registered in the Profil
// tab, Siri and Widgets are honest info pages, the search finds Teil B's
// pages and rows, and every row a hit asks for exists on its page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_settings_screen.dart';
import 'package:shoply/presentation/screens/calories/calories_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/profile_root_data.dart';
import 'package:shoply/presentation/screens/profile/settings/offers_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings_search_index.dart';
import 'package:shoply/presentation/screens/system/b_settings_search.dart';
import 'package:shoply/presentation/screens/system/siri_settings_screen.dart';
import 'package:shoply/presentation/screens/system/widgets/settings_info_row.dart';
import 'package:shoply/presentation/screens/system/widgets_settings_screen.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/route_paths.dart';

import '../avo/avo_fakes.dart' show FakeAvoBackend, FakeProHints;
import '../offers/offer_test_harness.dart';
import '../profile/settings/settings_test_helpers.dart';

final Set<String> _routes = {
  ...collectRoutePatterns(profileBranchRoutes),
  RoutePaths.pro,
};

List<String> _titles(String query, {bool killSwitch = false}) => [
  for (final hit in searchSettings(
    query,
    SettingsSearchScope(
      routes: _routes,
      enabledModules: {...AppModule.values},
      killSwitch: killSwitch,
    ),
    entries: bSettingsSearchEntries,
  ))
    AppTranslations.get(hit.titleKey, 'de'),
];

Finder _row(String id) => find.byWidgetPredicate(
  (w) => w is HighlightableRow && w.id == id,
  skipOffstage: false,
);

List<Override> _pageOverrides() => [
  ...settingsOverrides(
    modules: FakeModuleStore(exampleModules(calories: true)),
  ),
  avoBackendProvider.overrideWithValue(FakeAvoBackend()),
  avoChatProvider.overrideWith(
    (ref) => AvoChat(FakeAvoBackend(), proHints: FakeProHints()),
  ),
  calorieGoalStateProvider.overrideWith(
    (ref) => const CalorieGoalState(CalorieGoalStatus.none),
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('routes', () {
    test('the Profil tab knows Teil B\'s pages (Wochenplan comes with B7)', () {
      for (final route in [
        RoutePaths.settingsOffers,
        RoutePaths.settingsOffersRegion,
        RoutePaths.settingsOffersMarkets,
        RoutePaths.settingsHealth,
        '${RoutePaths.settingsHealth}/goals',
        RoutePaths.settingsAvo,
        RoutePaths.settingsSiri,
        RoutePaths.settingsWidgets,
      ]) {
        expect(_routes, contains(route), reason: route);
      }
      expect(_routes, isNot(contains(RoutePaths.settingsPlan)));
    });
  });

  group('search', () {
    test('every key exists in German and English', () {
      for (final e in bSettingsSearchEntries) {
        for (final key in [
          e.titleKey,
          ...e.pathKeys,
          ...e.keywordsKeys,
          ?e.killSwitchTitleKey,
          ...?e.killSwitchPathKeys,
        ]) {
          for (final lang in ['de', 'en']) {
            expect(
              AppTranslations.get(key, lang),
              isNot(key),
              reason: '$key ($lang)',
            );
          }
        }
      }
    });

    test('pages and rows of Teil B are found, rows with their path', () {
      expect(_titles('Siri'), contains('Siri & Kurzbefehle'));
      expect(_titles('Kurzbefehle'), contains('Kurzbefehle-App öffnen'));
      expect(_titles('Widget'), contains('Widgets'));
      expect(_titles('Abendessen'), ['Ideen fürs Abendessen']);
      expect(_titles('Allergien'), contains('Ernährung und Allergien'));
      expect(_titles('Chat löschen'), ['Gespräch löschen']);
      expect(_titles('Prospekt'), contains('Preise & Angebote'));
      expect(_titles('Markt erkennen'), contains('Markt automatisch erkennen'));

      final hit = searchSettings(
        'Abendessen',
        SettingsSearchScope(
          routes: _routes,
          enabledModules: {...AppModule.values},
        ),
        entries: bSettingsSearchEntries,
      ).single;
      expect(hit.location, '/settings/health?row=health.dinner_ideas');
      expect(hit.pathKeys, ['cal_settings_title']);
    });

    test('rows of a switched-off module are not found', () {
      List<String> without(AppModule off, String query) => [
        for (final hit in searchSettings(
          query,
          SettingsSearchScope(
            routes: _routes,
            enabledModules: {...AppModule.values}..remove(off),
          ),
          entries: bSettingsSearchEntries,
        ))
          hit.titleKey,
      ];
      expect(without(AppModule.calories, 'Abendessen'), isEmpty);
      expect(without(AppModule.calories, 'Gewicht'), isEmpty);
      expect(without(AppModule.avo, 'Chat löschen'), isEmpty);
      expect(without(AppModule.offers, 'Angebote an Artikeln'), isEmpty);
    });

    test('kill switch: no offers words, markets as "Märkte"', () {
      expect(_titles('Angebote an Artikeln', killSwitch: true), isEmpty);
      expect(_titles('Prospekt', killSwitch: true), isEmpty);
      final hits = searchSettings(
        'Markt erkennen',
        SettingsSearchScope(
          routes: _routes,
          enabledModules: {...AppModule.values},
          killSwitch: true,
        ),
        entries: bSettingsSearchEntries,
      );
      final detect = hits.firstWhere(
        (h) => h.entry.rowId == OffersSettingsRows.detect,
      );
      expect(detect.pathKeys, ['prof_row_markets']);
    });
  });

  group('every searched row exists on its page', () {
    testWidgets('Kalorien & Gesundheit', (tester) async {
      await pumpSettings(
        tester,
        const CaloriesSettingsScreen(),
        overrides: _pageOverrides(),
        height: 1600,
      );
      for (final e in bSettingsSearchEntries) {
        if (e.route != RoutePaths.settingsHealth || e.rowId == null) continue;
        expect(_row(e.rowId!), findsOneWidget, reason: e.rowId);
      }
      expect(_row(CaloriesSettingsRows.dinnerTime), findsOneWidget);
    });

    testWidgets('Avo', (tester) async {
      await pumpSettings(
        tester,
        const AvoSettingsScreen(),
        overrides: _pageOverrides(),
        height: 1600,
      );
      for (final e in bSettingsSearchEntries) {
        if (e.route != RoutePaths.settingsAvo || e.rowId == null) continue;
        expect(_row(e.rowId!), findsOneWidget, reason: e.rowId);
      }
    });

    testWidgets('Siri & Kurzbefehle', (tester) async {
      await pumpSettings(
        tester,
        const SiriSettingsScreen(),
        overrides: _pageOverrides(),
        height: 1600,
      );
      for (final e in bSettingsSearchEntries) {
        if (e.route != RoutePaths.settingsSiri || e.rowId == null) continue;
        expect(_row(e.rowId!), findsOneWidget, reason: e.rowId);
      }
    });

    testWidgets('Preise & Angebote', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpOfferScreen(
        tester,
        const RowHighlightScope(rowId: null, child: OffersSettingsScreen()),
        overrides: [
          ...offersOn(region: testRegion),
          offersRemoteEnabledProvider.overrideWithValue(true),
          moduleEnabledProvider.overrideWith((ref, m) => true),
        ],
      );
      for (final e in bSettingsSearchEntries) {
        if (e.route != RoutePaths.settingsOffers || e.rowId == null) continue;
        expect(_row(e.rowId!), findsOneWidget, reason: e.rowId);
      }
    });
  });

  group('Siri & Kurzbefehle', () {
    testWidgets('the sentences with Avo, and the Shortcuts app', (
      tester,
    ) async {
      final actions = FakeExternalActions();
      await pumpSettings(
        tester,
        const SiriSettingsScreen(),
        overrides: settingsOverrides(actions: actions),
        height: 1400,
      );
      expect(find.text('Siri & Shortcuts'), findsOneWidget);
      expect(find.text('“Add milk to Avo”'), findsOneWidget);
      expect(find.text('Adds an item to a list'), findsOneWidget);
      expect(find.text('“Show saved recipes in Avo”'), findsOneWidget);
      expect(
        find.byType(SettingsInfoRow),
        findsNWidgets(kSiriSentences.length),
      );
      await tester.tap(find.text('Open the Shortcuts app'));
      await settle(tester);
      expect(actions.urls, [kShortcutsAppUrl]);
      expect(find.textContaining("didn't open"), findsNothing);
    });

    testWidgets('says so when the Shortcuts app does not open', (tester) async {
      final actions = FakeExternalActions()..urlOpens = false;
      await pumpSettings(
        tester,
        const SiriSettingsScreen(),
        overrides: settingsOverrides(actions: actions),
        height: 1400,
      );
      await tester.tap(find.text('Open the Shortcuts app'));
      await tester.pump();
      expect(
        find.text(
          "The Shortcuts app didn't open. You can get it again from the App Store.",
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
    });

    test('every sentence names the app and exists in both languages', () {
      for (final (sentence, action) in kSiriSentences) {
        for (final lang in ['de', 'en']) {
          expect(
            AppTranslations.get(sentence, lang, params: {'app': 'Avo'}),
            contains('Avo'),
          );
          expect(AppTranslations.get(action, lang), isNot(action));
        }
      }
    });
  });

  group('Widgets', () {
    testWidgets('the three widgets with their sizes and how to add one', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        const WidgetsSettingsScreen(),
        overrides: settingsOverrides(),
      );
      expect(find.byType(SettingsInfoRow), findsNWidgets(kHomeWidgets.length));
      expect(find.text('Shopping list'), findsOneWidget);
      expect(find.text('Quick add'), findsOneWidget);
      expect(find.text('Saved recipes'), findsOneWidget);
      expect(find.text('Small, medium'), findsOneWidget);
      expect(find.text('Small, medium, large'), findsNWidgets(2));
      expect(find.textContaining('Add Widget'), findsOneWidget);
    });
  });

  testWidgets('SettingsInfoRow reads as one element', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSettings(
      tester,
      const SettingsInfoRow(
        title: 'Einkaufsliste',
        subtitle: 'Wähle eine Liste',
        value: 'Klein, mittel',
      ),
      overrides: settingsOverrides(),
    );
    expect(
      find.bySemanticsLabel('Einkaufsliste, Wähle eine Liste, Klein, mittel'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
