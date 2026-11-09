import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/appearance_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/language_settings_screen.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/state/language_provider.dart';
import 'package:shoply/presentation/state/theme_provider.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

ChoiceRow _choice(WidgetTester tester, String title) => tester.widget(
  find.byWidgetPredicate((w) => w is ChoiceRow && w.title == title),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Darstellung', () {
    layoutMatrix(
      'AppearanceSettingsScreen',
      (_) => scoped(const AppearanceSettingsScreen()),
    );

    testWidgets('three choices with one checkmark; a tap acts at once', (
      tester,
    ) async {
      final theme = FakeThemeService();
      final container = await pumpSettings(
        tester,
        const AppearanceSettingsScreen(),
        overrides: settingsOverrides(theme: theme),
      );
      expect(find.byType(ChoiceRow), findsNWidgets(3));
      final selected = [
        for (final t in ['System', 'Light', 'Dark'])
          if (_choice(tester, t).selected) t,
      ];
      expect(selected, hasLength(1));

      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(_choice(tester, 'Dark').selected, isTrue);
      expect(_choice(tester, 'Light').selected, isFalse);
      expect(theme.saved, ['dark']);
    });

    testWidgets('the footer leads to the iOS settings', (tester) async {
      final actions = FakeExternalActions();
      await pumpSettings(
        tester,
        const AppearanceSettingsScreen(),
        overrides: settingsOverrides(actions: actions),
      );
      expect(find.textContaining('Text size, bold text'), findsOneWidget);
      await tester.tap(find.text('Open iOS Settings'));
      await tester.pump();
      expect(actions.appSettings, 1);
    });
  });

  group('Sprache', () {
    layoutMatrix(
      'LanguageSettingsScreen',
      (_) => scoped(const LanguageSettingsScreen()),
    );

    testWidgets('"System" is chosen by default and names the language', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        const LanguageSettingsScreen(),
        overrides: [
          ...settingsOverrides(),
          settingsDeviceLanguageProvider.overrideWithValue('de'),
        ],
      );
      expect(_choice(tester, 'System').selected, isTrue);
      expect(find.text('Deutsch, like your iPhone'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('a language acts at once and goes into the account', (
      tester,
    ) async {
      final backend = FakeProfileBackend();
      final container = await pumpSettings(
        tester,
        const LanguageSettingsScreen(),
        overrides: settingsOverrides(profile: backend),
      );
      await tester.tap(find.text('Deutsch'));
      await settle(tester);
      expect(container.read(languageProvider), 'de');
      expect(_choice(tester, 'Deutsch').selected, isTrue);
      expect(_choice(tester, 'System').selected, isFalse);
      expect(backend.languageWrites, ['de']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'de');
    });

    testWidgets('a saved language shows its checkmark', (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'en'});
      await pumpSettings(tester, const LanguageSettingsScreen());
      expect(_choice(tester, 'English').selected, isTrue);
      expect(_choice(tester, 'System').selected, isFalse);
    });

    testWidgets('German texts', (tester) async {
      await pumpSettings(
        tester,
        const LanguageSettingsScreen(),
        locale: const Locale('de'),
      );
      expect(find.text('Sprache'), findsOneWidget);
      expect(
        find.textContaining('Gilt für die App, Mitteilungen und Avo.'),
        findsOneWidget,
      );
    });
  });
}
