import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/modules_settings_screen.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix(
    'ModulesSettingsScreen',
    (_) => scoped(const ModulesSettingsScreen()),
  );

  testWidgets('one switch per released module, the unreleased plan missing', (
    tester,
  ) async {
    await pumpSettings(tester, const ModulesSettingsScreen());
    expect(find.text('Modules'), findsOneWidget);
    expect(find.byType(ToggleRow), findsNWidgets(4));
    expect(find.text('Prices & offers'), findsOneWidget);
    expect(find.text('Avo, your assistant'), findsOneWidget);
    expect(find.text('Calories & health'), findsOneWidget);
    expect(find.text('Split costs'), findsOneWidget);
    expect(find.text('Meal plan'), findsNothing);
    expect(
      find.text('Your tabs: Home, Lists, Avo, Recipes, Profile.'),
      findsOneWidget,
    );
  });

  testWidgets('switching off acts at once and can be undone', (tester) async {
    final store = FakeModuleStore(exampleModules());
    final container = await pumpSettings(
      tester,
      const ModulesSettingsScreen(),
      overrides: settingsOverrides(modules: store),
    );
    await tester.tap(find.text('Avo, your assistant'));
    await tester.pump();
    expect(
      container.read(appModulesProvider).isEnabled(AppModule.avo),
      isFalse,
    );
    expect(store.local?['avo'], isFalse);
    expect(find.text('Avo, your assistant turned off'), findsOneWidget);
    expect(
      find.text('The Avo tab is hidden. Your chats stay.'),
      findsOneWidget,
    );
    expect(
      find.text('Your tabs: Home, Lists, Recipes, Profile.'),
      findsOneWidget,
    );

    await settle(tester);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(container.read(appModulesProvider).isEnabled(AppModule.avo), isTrue);
    expect(find.text('Ask or talk, Avo does it in the app.'), findsOneWidget);
    await letToastsExpire(tester);
  });

  testWidgets('switching on needs no confirmation and shows no toast', (
    tester,
  ) async {
    final container = await pumpSettings(tester, const ModulesSettingsScreen());
    await tester.tap(find.text('Calories & health'));
    await tester.pump();
    expect(
      container.read(appModulesProvider).isEnabled(AppModule.calories),
      isTrue,
    );
    expect(find.textContaining('turned off'), findsNothing);
  });

  testWidgets('the kill switch drops "Prices & offers" without a hint', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const ModulesSettingsScreen(),
      overrides: settingsOverrides(killSwitch: true),
    );
    expect(find.text('Prices & offers'), findsNothing);
    expect(find.byType(ToggleRow), findsNWidgets(3));
  });

  testWidgets('German texts', (tester) async {
    await pumpSettings(
      tester,
      const ModulesSettingsScreen(),
      locale: const Locale('de'),
    );
    expect(find.text('Module'), findsOneWidget);
    expect(
      find.textContaining('Liste und Rezepte sind immer dabei.'),
      findsOneWidget,
    );
    expect(
      find.text('Deine Tabs: Home, Listen, Avo, Rezepte, Profil.'),
      findsOneWidget,
    );
  });
}
