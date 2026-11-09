import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/appearance_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/help_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/legal_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/lists_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/modules_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/notifications_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/settings_pages_search.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/routes/route_paths.dart';

import 'settings_test_helpers.dart';

/// The page behind each route of the entries.
final Map<String, Widget> _pages = {
  RoutePaths.settingsModules: const ModulesSettingsScreen(),
  RoutePaths.settingsDiet: const DietSettingsScreen(),
  RoutePaths.settingsPersonal: const PersonalSettingsScreen(),
  RoutePaths.settingsLists: const ListsSettingsScreen(),
  RoutePaths.settingsNotifications: const NotificationsSettingsScreen(),
  RoutePaths.settingsAppearance: const AppearanceSettingsScreen(),
  RoutePaths.settingsLanguage: const LanguageSettingsScreen(),
  RoutePaths.settingsHelp: const HelpSettingsScreen(),
  RoutePaths.settingsLegal: const LegalSettingsScreen(),
  RoutePaths.settingsLegalSources: const DataSourcesScreen(),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every page has an entry, every route is a settings route', () {
    final routes = settingsPagesSearchEntries.map((e) => e.route).toSet();
    for (final route in _pages.keys) {
      expect(routes, contains(route));
    }
    for (final e in settingsPagesSearchEntries) {
      expect(e.route, startsWith('${RoutePaths.settings}/'));
      expect(e.icon, isNotNull, reason: e.titleKey);
      if (e.rowId != null) expect(e.pathKeys, isNotEmpty, reason: e.titleKey);
    }
  });

  test('row ids are unique and named <page>.<row>', () {
    final ids = [
      for (final e in settingsPagesSearchEntries)
        if (e.rowId != null) e.rowId!,
    ];
    expect(ids.toSet(), hasLength(ids.length));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[a-z]+\.[a-z_]+$')));
    }
  });

  test('every text exists in German and English', () {
    for (final e in settingsPagesSearchEntries) {
      for (final key in [e.titleKey, ...e.pathKeys, ...e.keywordsKeys]) {
        for (final lang in ['de', 'en']) {
          final text = AppTranslations.get(key, lang);
          expect(text, isNot(key), reason: '$key ($lang)');
          expect(text, isNot(contains('{')), reason: '$key ($lang)');
        }
      }
    }
  });

  test('offers words are marked for the kill switch', () {
    final offers = settingsPagesSearchEntries.where((e) => e.offersTerm);
    expect(offers.map((e) => e.rowId), ['modules.offers', 'help.faq_offers']);
  });

  test('rows that need a module say which', () {
    final byRow = {
      for (final e in settingsPagesSearchEntries)
        if (e.rowId != null) e.rowId!: e.module,
    };
    expect(byRow['notifications.dinner_ideas'], AppModule.calories);
    expect(byRow['notifications.cost_split'], AppModule.costSplit);
    expect(byRow['notifications.plan_reminder'], AppModule.mealPlan);
    expect(byRow['help.faq_offers'], AppModule.offers);
    expect(byRow['notifications.restock'], isNull);
  });

  for (final entry in _pages.entries) {
    final rows = [
      for (final e in settingsPagesSearchEntries)
        if (e.route == entry.key &&
            e.rowId != null &&
            e.module != AppModule.mealPlan)
          e.rowId!,
    ];
    if (rows.isEmpty) continue;
    testWidgets('${entry.key} has a HighlightableRow for each entry', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        entry.value,
        height: 2400,
        overrides: settingsOverrides(
          modules: FakeModuleStore(exampleModules(calories: true)),
        ),
      );
      for (final id in rows) {
        expect(
          find.byWidgetPredicate((w) => w is HighlightableRow && w.id == id),
          findsOneWidget,
          reason: id,
        );
      }
    });
  }

  testWidgets('a searched row is lit once on its page', (tester) async {
    await pumpSettings(
      tester,
      const NotificationsSettingsScreen(
        highlightRowId: 'notifications.restock',
      ),
      height: 2400,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is RowHighlightScope && w.rowId == 'notifications.restock',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
