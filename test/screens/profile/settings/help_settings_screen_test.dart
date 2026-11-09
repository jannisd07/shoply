import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/presentation/screens/profile/settings/help_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/in_app_browser_page.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix('HelpSettingsScreen', (_) => scoped(const HelpSettingsScreen()));

  testWidgets('questions unfold in place with a readable answer', (
    tester,
  ) async {
    await pumpSettings(tester, const HelpSettingsScreen(), height: 1600);
    expect(find.text('How do I share a list?'), findsOneWidget);
    expect(find.textContaining('invite people by link'), findsNothing);
    await tester.tap(find.text('How do I share a list?'));
    await settle(tester);
    expect(find.textContaining('invite people by link'), findsOneWidget);
    await tester.tap(find.text('How do I share a list?'));
    await settle(tester);
    expect(find.textContaining('invite people by link'), findsNothing);
  });

  testWidgets(
    'the offers question needs the offers module and no kill switch',
    (tester) async {
      await pumpSettings(tester, const HelpSettingsScreen(), height: 1600);
      expect(find.text('Where do the offers come from?'), findsOneWidget);
    },
  );

  testWidgets('kill switch: no offers question', (tester) async {
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(killSwitch: true),
      height: 1600,
    );
    expect(find.text('Where do the offers come from?'), findsNothing);
  });

  testWidgets('support mail opens; without a mail app the address is copied', (
    tester,
  ) async {
    final actions = FakeExternalActions()..mailOpens = false;
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(actions: actions),
      height: 1600,
    );
    await tester.tap(find.text('Email support'));
    await settle(tester);
    expect(actions.mails.single.to, LegalLinks.supportEmail);
    expect(actions.mails.single.subject, 'Avo support');
    expect(actions.copied, [LegalLinks.supportEmail]);
    expect(find.text('Address copied'), findsOneWidget);
    await letToastsExpire(tester);
  });

  testWidgets('"Report a bug" puts version and iOS visibly into the mail', (
    tester,
  ) async {
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(actions: actions),
      height: 1600,
    );
    await tester.tap(find.text('Report a bug'));
    await settle(tester);
    final mail = actions.mails.single;
    expect(mail.subject, 'Avo: bug report');
    expect(mail.body, contains('What happened?'));
    expect(mail.body, contains('Avo 1.1.4 (31)'));
    expect(mail.body, contains('iOS: 26.1'));
    expect(actions.copied, isEmpty);
  });

  testWidgets('rating opens the App Store dialog without a pre-dialog', (
    tester,
  ) async {
    final actions = FakeExternalActions();
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(actions: actions),
      height: 1600,
    );
    await tester.tap(find.text('Rate Avo'));
    await tester.pump();
    expect(actions.reviews, 1);
  });

  testWidgets('"Reset tips" waits for the undo time', (tester) async {
    var resets = 0;
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(resetTips: () => resets++),
      height: 1600,
    );
    await tester.tap(find.text('Reset tips'));
    await settle(tester);
    expect(find.text('Tips reset'), findsOneWidget);
    expect(resets, 0);
    await tester.pump(const Duration(seconds: 4));
    expect(resets, 1);
    await letToastsExpire(tester);
  });

  testWidgets('"Undo" keeps the tips', (tester) async {
    var resets = 0;
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(resetTips: () => resets++),
      height: 1600,
    );
    await tester.tap(find.text('Reset tips'));
    await settle(tester);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(resets, 0);
    await letToastsExpire(tester);
  });

  testWidgets('the guide opens in the in-app browser', (tester) async {
    final web = FakeWebLoader(
      document: const WebDocument(
        blocks: [WebBlock(WebBlockKind.title, 'So nutzt du Avo')],
      ),
    );
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(web: web),
      height: 1600,
    );
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.byType(InAppBrowserPage), findsOneWidget);
    expect(find.text('So nutzt du Avo'), findsOneWidget);
    expect(web.urls.single, Uri.parse(LegalLinks.userGuide));
  });

  testWidgets('the footer shows the version, or only the name', (tester) async {
    await pumpSettings(tester, const HelpSettingsScreen(), height: 1600);
    expect(find.text('Avo · Version 1.1.4 (31)'), findsOneWidget);
  });

  testWidgets('German texts', (tester) async {
    await pumpSettings(
      tester,
      const HelpSettingsScreen(),
      overrides: settingsOverrides(version: null),
      locale: const Locale('de'),
      height: 1600,
    );
    expect(find.text('Häufige Fragen'.toUpperCase()), findsOneWidget);
    expect(find.text('Tipps zurücksetzen'), findsOneWidget);
    expect(find.text('Avo'), findsOneWidget);
  });
}
