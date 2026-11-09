import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/diet_settings_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

AppFilterChip _chip(WidgetTester tester, String label) => tester.widget(
  find.byWidgetPredicate((w) => w is AppFilterChip && w.label == label),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  layoutMatrix('DietSettingsScreen', (_) => scoped(const DietSettingsScreen()));

  testWidgets('allergies come first, chips show the account', (tester) async {
    await pumpSettings(tester, const DietSettingsScreen(), height: 1600);
    final allergies = tester.getTopLeft(
      find.text('ALLERGIES AND INTOLERANCES'),
    );
    final diet = tester.getTopLeft(find.text('DIET'));
    expect(allergies.dy, lessThan(diet.dy));
    expect(_chip(tester, 'Peanuts').selected, isTrue);
    expect(_chip(tester, 'Vegetarian').selected, isTrue);
    expect(_chip(tester, 'Vegan').selected, isFalse);
    expect(find.text('Fructose'), findsNothing);
    expect(find.text('Adapt recipes automatically'), findsOneWidget);
  });

  testWidgets('a chip acts at once and writes both columns', (tester) async {
    final backend = FakeProfileBackend();
    await pumpSettings(
      tester,
      const DietSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
      height: 1600,
    );
    await tester.tap(find.text('Gluten'));
    await tester.pump();
    await tester.pump();
    expect(_chip(tester, 'Gluten').selected, isTrue);
    expect(_chip(tester, 'Tree nuts').selected, isFalse);
    await settle(tester);
    expect(backend.dietWrites.last.allergies, ['gluten', 'peanuts']);
    expect(backend.dietWrites.last.diet, [
      'vegetarian',
      'gluten_free',
      'nut_free',
    ]);

    await tester.tap(find.text('Vegetarian'));
    await settle(tester);
    expect(backend.dietWrites.last.diet, ['gluten_free', 'nut_free']);
    expect(_chip(tester, 'Vegetarian').selected, isFalse);
  });

  testWidgets('"Show more" adds the five further allergies', (tester) async {
    await pumpSettings(tester, const DietSettingsScreen(), height: 1600);
    await tester.tap(find.text('Show more'));
    await tester.pump();
    for (final a in ['Fructose', 'Histamine', 'Nightshades', 'Corn', 'Yeast']) {
      expect(find.text(a), findsOneWidget);
    }
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('old "free from" diets show as allergies', (tester) async {
    await pumpSettings(
      tester,
      const DietSettingsScreen(),
      overrides: settingsOverrides(
        profile: FakeProfileBackend(
          exampleUser(diet: ['gluten_free', 'vegan'], allergies: []),
        ),
      ),
      height: 1600,
    );
    expect(_chip(tester, 'Gluten').selected, isTrue);
    expect(_chip(tester, 'Vegan').selected, isTrue);
  });

  testWidgets('free-text allergies stay, and removing one can be undone', (
    tester,
  ) async {
    final backend = FakeProfileBackend(
      exampleUser(allergies: ['peanuts', 'Kiwi']),
    );
    await pumpSettings(
      tester,
      const DietSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
      height: 1600,
    );
    expect(_chip(tester, 'Kiwi').selected, isTrue);

    await tester.tap(find.text('Soy'));
    await settle(tester);
    expect(backend.dietWrites.last.allergies, ['peanuts', 'soy', 'Kiwi']);

    await tester.tap(find.text('Kiwi'));
    await settle(tester);
    expect(find.text('Kiwi'), findsNothing);
    expect(backend.dietWrites.last.allergies, ['peanuts', 'soy']);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(backend.dietWrites.last.allergies, ['peanuts', 'soy', 'Kiwi']);
    await letToastsExpire(tester);
  });

  testWidgets('offline: the choice stays and is sent again when online', (
    tester,
  ) async {
    final backend = FakeProfileBackend()..fail = true;
    final container = await pumpSettings(
      tester,
      const DietSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
      height: 1600,
    );
    await tester.tap(find.text('Eggs'));
    await settle(tester);
    expect(_chip(tester, 'Eggs').selected, isTrue);
    expect(backend.dietWrites, isEmpty);
    expect(container.read(dietSettingsProvider.notifier).syncFailed, isTrue);

    backend.fail = false;
    await container.read(dietSettingsProvider.notifier).retry();
    await settle(tester);
    expect(backend.dietWrites.last.allergies, ['eggs', 'peanuts']);
    expect(_chip(tester, 'Eggs').selected, isTrue);
  });

  testWidgets('"Adapt recipes automatically" is on by default and switches', (
    tester,
  ) async {
    final container = await pumpSettings(
      tester,
      const DietSettingsScreen(),
      height: 1600,
    );
    expect(container.read(recipeAutoAdaptProvider), isTrue);
    await tester.tap(find.text('Adapt recipes automatically'));
    await tester.pump();
    expect(container.read(recipeAutoAdaptProvider), isFalse);
    // The recipe tab reads the switch through the diet profile.
    expect(container.read(recipeDietProfileProvider).autoAdapt, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('setp_recipe_auto_adapt_u1'), isFalse);
  });

  testWidgets('German texts', (tester) async {
    await pumpSettings(
      tester,
      const DietSettingsScreen(),
      locale: const Locale('de'),
      height: 1600,
    );
    expect(find.text('Ernährung & Allergien'), findsOneWidget);
    expect(find.text('ALLERGIEN UND UNVERTRÄGLICHKEITEN'), findsOneWidget);
    expect(find.text('Erdnüsse'), findsOneWidget);
    expect(find.text('Weitere anzeigen'), findsOneWidget);
  });
}
