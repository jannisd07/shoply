import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/presentation/screens/profile/settings/legal_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

const _licenses = [
  PackageLicenses('flutter', ['BSD 3-Clause License', 'Copyright 2014']),
  PackageLicenses('go_router', ['BSD 3-Clause License']),
];

List<Override> _overrides({
  FakeWebLoader? web,
  FakeExternalActions? actions,
  bool killSwitch = false,
}) => [
  ...settingsOverrides(web: web, actions: actions, killSwitch: killSwitch),
  settingsLicensesProvider.overrideWith((ref) async => _licenses),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('documents keep their ids and pages', () {
    expect(LegalDocument.fromId('privacy'), LegalDocument.privacy);
    expect(LegalDocument.fromId('nope'), isNull);
    expect(LegalDocument.privacy.url, LegalLinks.privacy);
    expect(LegalDocument.licenses.url, isNull);
  });

  layoutMatrix(
    'LegalSettingsScreen',
    (_) => scoped(const LegalSettingsScreen()),
  );
  layoutMatrix('DataSourcesScreen', (_) => scoped(const DataSourcesScreen()));
  layoutMatrix(
    'LicensesScreen',
    (_) => scoped(
      const LegalDocumentScreen(document: LegalDocument.licenses),
      overrides: _overrides(),
    ),
  );

  testWidgets('five rows; Datenschutz opens in the in-app browser', (
    tester,
  ) async {
    final web = FakeWebLoader(
      document: const WebDocument(
        blocks: [WebBlock(WebBlockKind.title, 'Datenschutzerklärung')],
      ),
    );
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const LegalSettingsScreen(),
      overrides: _overrides(web: web, actions: actions),
    );
    expect(find.byType(NavRow), findsNWidgets(5));
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.byType(InAppBrowserPage), findsOneWidget);
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
    expect(web.urls.single, Uri.parse(LegalLinks.privacy));

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is GlassIconButton && w.semanticLabel == 'Open in Safari',
      ),
    );
    await tester.pump();
    expect(actions.urls, [Uri.parse(LegalLinks.privacy)]);
  });

  testWidgets('Datenquellen names every source with its licence', (
    tester,
  ) async {
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const LegalSettingsScreen(),
      overrides: _overrides(actions: actions),
      height: 1400,
    );
    await tester.tap(find.text('Data sources'));
    await tester.pumpAndSettle();
    expect(find.text('PRODUCT PHOTOS AND NUTRITION'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('OFFERS'), findsOneWidget);
    await tester.tap(find.text('www.openstreetmap.org'));
    await tester.pump();
    expect(actions.urls.single.host, 'www.openstreetmap.org');
  });

  testWidgets('kill switch: no offers source, ODbL stays', (tester) async {
    await pumpSettings(
      tester,
      const DataSourcesScreen(),
      overrides: _overrides(killSwitch: true),
      height: 1400,
    );
    expect(find.text('OFFERS'), findsNothing);
    expect(find.text('PRICES'), findsOneWidget);
  });

  testWidgets('Lizenzen lists packages and opens their text', (tester) async {
    await pumpSettings(
      tester,
      const LegalSettingsScreen(),
      overrides: _overrides(),
    );
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.text('2 open-source packages'), findsOneWidget);
    await tester.tap(find.text('go_router'));
    await tester.pumpAndSettle();
    expect(find.text('BSD 3-Clause License'), findsOneWidget);
  });

  testWidgets('German texts', (tester) async {
    await pumpSettings(
      tester,
      const LegalSettingsScreen(),
      overrides: _overrides(),
      locale: const Locale('de'),
    );
    for (final t in [
      'Rechtliches',
      'Datenschutz',
      'Impressum',
      'Nutzungsbedingungen',
      'Datenquellen',
      'Lizenzen',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
  });
}
