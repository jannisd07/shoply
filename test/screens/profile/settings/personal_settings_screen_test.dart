import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/personal_settings_screen.dart';

import '../../../layout/layout_matrix.dart';
import 'settings_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('height conversion keeps the length', () {
    expect(cmToFeetInches(182), (feet: 5, inches: 11));
    expect(feetInchesToCm(5, 11), closeTo(180.34, 0.001));
    expect(cmToFeetInches(feetInchesToCm(5, 11)), (feet: 5, inches: 11));
    expect(cmToFeetInches(feetInchesToCm(6, 2)), (feet: 6, inches: 2));
  });

  test('old rows with decimal feet are read as feet', () {
    final p = PersonalSettings.of(exampleUser(height: 5.7, heightUnit: 'ft'));
    expect(p.unit, HeightUnit.feet);
    expect(p.heightCm, 174);
  });

  layoutMatrix(
    'PersonalSettingsScreen',
    (_) => scoped(const PersonalSettingsScreen()),
  );

  layoutMatrix(
    'PersonalSettingsScreen with the height open',
    (_) => scoped(const PersonalSettingsScreen()),
    afterPump: (tester) async {
      await tester.tap(find.text('Height'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows the values; nothing is a slider', (tester) async {
    await pumpSettings(tester, const PersonalSettingsScreen());
    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('34 years'), findsOneWidget);
    expect(find.text('182 cm'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(
      find.text(
        'Only used for calorie goals. Calories & health is turned off.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CupertinoSlider), findsNothing);
  });

  testWidgets('the age wheel writes the new age at once', (tester) async {
    final backend = FakeProfileBackend();
    await pumpSettings(
      tester,
      const PersonalSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
    );
    await tester.tap(find.text('Age'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsOneWidget);
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(backend.personalWrites, isNotEmpty);
    final age = backend.personalWrites.last.age!;
    expect(age, greaterThan(34));
    expect(find.text('$age years'), findsOneWidget);
    expect(backend.personalWrites.last.heightCm, 182);
  });

  testWidgets('switching to ft, in converts instead of clearing', (
    tester,
  ) async {
    final backend = FakeProfileBackend();
    await pumpSettings(
      tester,
      const PersonalSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
    );
    await tester.tap(find.text('Height'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ft, in'));
    await settle(tester);
    expect(find.text('5 ft 11 in'), findsOneWidget);
    expect(backend.personalWrites.last.unit, HeightUnit.feet);
    expect(backend.personalWrites.last.heightCm, 182);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
  });

  testWidgets('only one picker is open at a time', (tester) async {
    await pumpSettings(tester, const PersonalSettingsScreen());
    await tester.tap(find.text('Age'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Height'));
    await tester.pumpAndSettle();
    expect(find.text('ft, in'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsOneWidget);
  });

  testWidgets('gender comes from a pull-down menu', (tester) async {
    final backend = FakeProfileBackend();
    await pumpSettings(
      tester,
      const PersonalSettingsScreen(),
      overrides: settingsOverrides(profile: backend),
    );
    await tester.tap(find.text('Gender'));
    await tester.pumpAndSettle();
    expect(find.text('Not specified'), findsOneWidget);
    await tester.tap(find.text('Diverse'));
    await tester.pumpAndSettle();
    expect(find.text('Diverse'), findsOneWidget);
    expect(backend.personalWrites.last.gender, 'other');
  });

  testWidgets('without values the rows say "Not set"', (tester) async {
    await pumpSettings(
      tester,
      const PersonalSettingsScreen(),
      overrides: settingsOverrides(
        profile: FakeProfileBackend(
          exampleUser(age: null, height: null, gender: null),
        ),
      ),
    );
    expect(find.text('Not set'), findsNWidgets(3));
  });

  testWidgets('from AX3 on the age is a number field', (tester) async {
    await pumpSettings(tester, const PersonalSettingsScreen(), scale: 3.1);
    await tester.tap(find.text('Age'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNothing);
    expect(find.byType(CupertinoTextField), findsOneWidget);
  });

  testWidgets('with calories on the footer names the daily needs', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const PersonalSettingsScreen(),
      overrides: settingsOverrides(
        modules: FakeModuleStore(exampleModules(calories: true)),
      ),
      locale: const Locale('de'),
    );
    expect(
      find.text(
        'Daraus berechnet Avo deinen Tagesbedarf. Die Angaben bleiben in deinem Konto.',
      ),
      findsOneWidget,
    );
    expect(find.text('34 Jahre'), findsOneWidget);
  });
}
