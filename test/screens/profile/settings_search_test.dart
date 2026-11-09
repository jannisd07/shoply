import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/profile/profile_root_data.dart';
import 'package:shoply/presentation/screens/profile/profile_root_pages.dart';
import 'package:shoply/presentation/screens/profile/profile_root_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/data/notification_settings.dart';
import 'package:shoply/presentation/screens/profile/settings_search_entry.dart';
import 'package:shoply/presentation/screens/profile/settings_search_index.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart'
    show bSettingsSearchEntries;
import 'package:shoply/routes/areas/profile_routes.dart';
import 'package:shoply/routes/route_paths.dart';

String _en(String key, {Map<String, String>? params}) =>
    AppTranslations.get(key, 'en', params: params);
String _de(String key, {Map<String, String>? params}) =>
    AppTranslations.get(key, 'de', params: params);

const _bPages = [
  RoutePaths.settingsOffers,
  RoutePaths.settingsHealth,
  RoutePaths.settingsPlan,
  RoutePaths.settingsAvo,
  RoutePaths.settingsSiri,
  RoutePaths.settingsWidgets,
];

/// Teil A's routes alone, then with Teil B's pages.
final Set<String> _aRoutes = {
  for (final r in collectRoutePatterns(profileBranchRoutes))
    if (!_bPages.any((b) => r == b || r.startsWith('$b/'))) r,
  RoutePaths.pro,
};
final Set<String> _allRoutes = {
  ..._aRoutes,
  RoutePaths.settingsOffers,
  RoutePaths.settingsOffersRegion,
  RoutePaths.settingsOffersMarkets,
  RoutePaths.settingsHealth,
  RoutePaths.settingsPlan,
  RoutePaths.settingsAvo,
};

/// The root's own entries and Teil B's page entries (not its rows), so the
/// tests do not depend on what the page parts register.
final List<SettingsSearchEntry> _rootEntries = [
  ...profileRootSearchEntries,
  ...bSettingsSearchEntries.where((e) => e.rowId == null),
];

const _rows = [
  SettingsSearchEntry(
    route: RoutePaths.settingsAccount,
    titleKey: 'prof_row_account',
    keywordsKeys: ['prof_kw_account'],
    rowId: 'account.delete',
  ),
  SettingsSearchEntry(
    route: RoutePaths.settingsOffersRegion,
    titleKey: 'prof_row_region',
    pathKeys: ['prof_row_offers', 'prof_row_region'],
    killSwitchPathKeys: ['prof_row_markets', 'prof_row_region'],
    keywordsKeys: ['prof_kw_region'],
    rowId: 'offers.zip',
  ),
];

List<String> _titles(
  String query, {
  Set<String>? routes,
  Set<AppModule> modules = const {AppModule.offers, AppModule.avo},
  bool killSwitch = false,
  List<SettingsSearchEntry>? entries,
}) => [
  for (final h in searchSettings(
    query,
    SettingsSearchScope(
      routes: routes ?? _allRoutes,
      enabledModules: modules,
      killSwitch: killSwitch,
    ),
    entries: entries ?? _rootEntries,
  ))
    _de(h.titleKey),
];

void main() {
  group('normalize and routes', () {
    test('folds case, umlauts, ß and hyphens', () {
      expect(normalizeSettingsQuery('  Größe & E-Mail  '), 'grosse email');
      expect(normalizeSettingsQuery('Nüsse'), 'nusse');
      expect(normalizeSettingsQuery('Profil › Konto'), 'profil konto');
    });

    test('route patterns with parameters match, the query is ignored', () {
      expect(isRouteRegistered(_aRoutes, '/settings/legal/privacy'), isTrue);
      expect(isRouteRegistered(_aRoutes, '/settings/diet?row=x'), isTrue);
      expect(isRouteRegistered(_aRoutes, RoutePaths.settingsOffers), isFalse);
      expect(isRouteRegistered(_aRoutes, '/settings/nope/deeper'), isFalse);
    });

    test('a deep location pushes its parents first', () {
      expect(settingsLocationChain('/settings/account/delete?row=x'), [
        '/settings/account',
        '/settings/account/delete?row=x',
      ]);
      expect(settingsLocationChain('/settings/diet?row=diet.allergies'), [
        '/settings/diet?row=diet.allergies',
      ]);
      expect(settingsLocationChain(RoutePaths.pro), [RoutePaths.pro]);
    });

    test('a location belongs to its first-level page', () {
      expect(profilePageOf('/settings/legal/sources')?.id, ProfilePageId.legal);
      expect(profilePageOf('/settings/diet?row=a')?.id, ProfilePageId.diet);
      expect(profilePageOf(RoutePaths.pro), isNull);
    });
  });

  group('search', () {
    test('finds pages in German and English, at once and without network', () {
      expect(_titles('dunkel'), ['Darstellung']);
      expect(_titles('Nachtmodus'), ['Darstellung']);
      expect(_titles('dark'), ['Darstellung']);
      expect(_titles('Allergie'), ['Ernährung & Allergien']);
      expect(_titles('Nuss'), ['Ernährung & Allergien']);
      expect(_titles('kündigen'), ['Avo Pro']);
      expect(_titles('Abo'), ['Avo Pro']);
      expect(_titles('Bildschirm an'), ['Listen']);
      expect(_titles('PLZ'), ['Region']);
      expect(_titles('Postleitzahl'), ['Region']);
      expect(_titles('Lieblingsmarkt'), ['Lieblingsmärkte']);
      expect(_titles('email'), contains('Profil bearbeiten'));
    });

    test('"löschen" leads to Konto; a row comes with its path', () {
      final hits = searchSettings(
        'löschen',
        SettingsSearchScope(routes: _allRoutes, enabledModules: const {}),
        entries: [..._rootEntries, ..._rows],
      );
      expect(hits.map((h) => h.entry.route).toSet(), {
        RoutePaths.settingsAccount,
      });
      // The page first, then its row.
      expect(hits.first.entry.rowId, isNull);
      final row = hits.last;
      expect(row.location, '/settings/account?row=account.delete');
      expect(row.pathKeys, ['prof_row_account']);
    });

    test('title hits rank before search-word hits', () {
      final titles = _titles('Konto');
      expect(titles.first, 'Konto');
    });

    test('hits in the app language rank first ("nut" in English)', () {
      final hits = searchSettings(
        'nut',
        SettingsSearchScope(
          routes: _allRoutes,
          enabledModules: AppModule.values.toSet(),
          languageCode: 'en',
        ),
        entries: allSettingsSearchEntries(),
      );
      final routes = [for (final h in hits) h.entry.route];
      // Allergies ("nuts") before the German "Nutzungsbedingungen".
      expect(routes, contains(RoutePaths.settingsDiet));
      expect(
        routes.indexOf(RoutePaths.settingsDiet),
        lessThan(
          routes.indexWhere((r) => r.startsWith(RoutePaths.settingsLegal)),
        ),
      );
    });

    test('unknown words find nothing', () {
      expect(_titles('Kontrast'), isEmpty);
      expect(_titles('   '), isEmpty);
    });

    test('pages without a route are not found', () {
      expect(_titles('PLZ', routes: _aRoutes), isEmpty);
      expect(_titles('Prospekt', routes: _aRoutes), isEmpty);
      expect(_titles('Siri'), isEmpty);
    });

    test('pages of switched-off modules are not found', () {
      expect(_titles('Apple Health'), isEmpty);
      expect(_titles('Apple Health', modules: {AppModule.calories}), [
        'Kalorien & Gesundheit',
      ]);
    });

    test('a row needs its own module and its page\'s module', () {
      // "Kalorien, Gewicht und Ziele" is a Kalorien row on the Avo page.
      List<String> find(Set<AppModule> modules) => _titles(
        'Gewicht und Ziele',
        modules: modules,
        entries: bSettingsSearchEntries,
      );
      const row = 'Kalorien, Gewicht und Ziele';
      expect(find({AppModule.calories}), isNot(contains(row)));
      expect(find({AppModule.avo}), isNot(contains(row)));
      expect(find({AppModule.avo, AppModule.calories}), contains(row));
    });

    test('kill switch: offers words find nothing, markets are "Märkte"', () {
      expect(_titles('Prospekt'), ['Preise & Angebote']);
      expect(_titles('Prospekt', killSwitch: true), isEmpty);
      expect(_titles('Angebot', killSwitch: true), isEmpty);
      expect(_titles('PLZ', killSwitch: true), ['Region']);
      // The "Märkte" page first; its subpages follow through their path.
      final markets = _titles('Markt', killSwitch: true);
      expect(markets.first, 'Märkte');
      expect(markets, containsAll(['Lieblingsmärkte', 'Region']));
      final plz = searchSettings(
        'PLZ',
        SettingsSearchScope(
          routes: _allRoutes,
          enabledModules: const {},
          killSwitch: true,
        ),
        entries: _rootEntries,
      ).single;
      expect(plz.pathKeys, ['prof_row_markets']);
      expect(plz.page?.id, ProfilePageId.offers);
      final region = searchSettings(
        'Region',
        SettingsSearchScope(
          routes: _allRoutes,
          enabledModules: const {},
          killSwitch: true,
        ),
        entries: _rows,
      ).single;
      expect(region.pathKeys, ['prof_row_markets', 'prof_row_region']);
      expect(region.location, '/settings/offers/region?row=offers.zip');
    });

    test('one place shows once, its subpages follow it', () {
      // Both offers entries match "Preise"; one hit, then the subpages
      // found through their path.
      final titles = _titles('Preise');
      expect(titles.first, 'Preise & Angebote');
      expect(titles.where((t) => t == 'Preise & Angebote'), hasLength(1));
      expect(titles, containsAll(['Region', 'Lieblingsmärkte']));
    });

    test('every entry key exists in both languages', () {
      for (final e in _rootEntries) {
        for (final key in [e.titleKey, ...e.keywordsKeys, ...e.pathKeys]) {
          expect(_en(key), isNot(key), reason: key);
          expect(_de(key), isNot(key), reason: key);
        }
      }
    });
  });

  group('row values', () {
    test('Ernährung: first diet, then the allergy count', () {
      expect(dietValue(_de, ['vegetarian'], 1), 'Vegetarisch · 1 Allergie');
      expect(dietValue(_de, ['vegan', 'halal'], 0), 'Vegan +1');
      expect(dietValue(_de, const [], 2), '2 Allergien');
      expect(dietValue(_de, const [], 0), isNull);
      expect(dietValue(_en, ['vegetarian'], 1), 'Vegetarian · 1 allergy');
    });

    test('Module counts shown modules that are on', () {
      expect(
        modulesValue(
          _de,
          const ProfileRootData(
            enabledModules: {
              AppModule.offers,
              AppModule.avo,
              AppModule.costSplit,
              AppModule.calories,
            },
          ),
        ),
        '4 an',
      );
      expect(
        modulesValue(
          _en,
          const ProfileRootData(
            enabledModules: {AppModule.offers, AppModule.avo},
            killSwitch: true,
          ),
        ),
        '1 on',
      );
    });

    test('Avo Pro line per status', () {
      expect(
        ProRowStatus.of(SubscriptionStatus.notSubscribed),
        ProRowStatus.trialAvailable,
      );
      expect(
        proSubtitle(_de, ProRowStatus.trialAvailable),
        '14 Tage gratis testen',
      );
      expect(proSubtitle(_de, ProRowStatus.subscribe), 'Alle Vorteile ansehen');
      expect(proSubtitle(_de, ProRowStatus.active), 'Aktiv');
      expect(proSubtitle(_de, ProRowStatus.pending), 'Wartet auf Freigabe');
      expect(proSubtitle(_de, ProRowStatus.unknown), isNull);
    });

    test('Preise & Angebote: markets, else region; "Aus" when off', () {
      expect(favoritesValue(const []), isNull);
      expect(favoritesValue(['Lidl', 'REWE']), 'Lidl, REWE');
      expect(favoritesValue(['Lidl', 'REWE', 'Aldi Süd']), 'Lidl, REWE +1');
      const on = ProfileRootData(
        enabledModules: {AppModule.offers},
        regionLabel: '79098 Freiburg',
      );
      expect(offersValue(_de, on), '79098 Freiburg');
      expect(
        offersValue(
          _de,
          const ProfileRootData(
            enabledModules: {AppModule.offers},
            regionLabel: '79098 Freiburg',
            favoritesLabel: 'Lidl, REWE',
          ),
        ),
        'Lidl, REWE',
      );
      expect(
        offersValue(_de, const ProfileRootData(regionLabel: '79098')),
        'Aus',
      );
      expect(
        offersValue(
          _de,
          const ProfileRootData(
            killSwitch: true,
            regionLabel: '79098',
            favoritesLabel: 'Lidl',
          ),
        ),
        'Lidl',
      );
      expect(offersValue(_de, const ProfileRootData(killSwitch: true)), isNull);
    });

    test('Mitteilungen: main switch first, then what iOS allows', () {
      NotificationRowState? state(
        NotificationPermissionState p, {
        bool master = true,
        bool loaded = true,
      }) => notificationRowState(master: master, loaded: loaded, permission: p);
      expect(
        state(NotificationPermissionState.allowed),
        NotificationRowState.on,
      );
      expect(
        state(NotificationPermissionState.unknown),
        NotificationRowState.on,
      );
      expect(
        state(NotificationPermissionState.notAsked),
        NotificationRowState.off,
      );
      expect(
        state(NotificationPermissionState.denied),
        NotificationRowState.blockedInIos,
      );
      expect(
        state(NotificationPermissionState.allowed, master: false),
        NotificationRowState.off,
      );
      expect(state(NotificationPermissionState.allowed, loaded: false), isNull);
    });

    test('Mitteilungen, Darstellung, Sprache, Region', () {
      expect(notificationsValue(_de, NotificationRowState.on), 'An');
      expect(notificationsValue(_de, NotificationRowState.off), 'Aus');
      expect(
        notificationsValue(_de, NotificationRowState.blockedInIos),
        'In iOS aus',
      );
      expect(notificationsValue(_de, null), isNull);
      expect(appearanceValue(_de, ThemeMode.dark), 'Dunkel');
      expect(appearanceValue(_en, ThemeMode.system), 'System');
      expect(languageValue(_en, 'de'), 'Deutsch');
      expect(languageValue(_de, 'en'), 'English');
      expect(
        regionValue(
          const Region(
            zip: '79098',
            city: 'Freiburg',
            source: RegionSource.manual,
          ),
        ),
        '79098 Freiburg',
      );
    });
  });
}
