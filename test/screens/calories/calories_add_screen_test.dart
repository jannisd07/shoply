// S3 "Essen eintragen" of docs/redesign/b-screens/kalorien.md: meal menu,
// date line, the input methods Foto | Barcode | Suche, "Zuletzt gegessen",
// own foods and Open Food Facts in the search, "Manuell eintragen", the
// photo card (camera question, offline, daily limit) and the barcode card
// (number field, "Zuletzt gescannt", no scanner).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/presentation/screens/calories/calories_add_screen.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';

import 'calorie_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesAddScreen)));

final _history = [
  food('h1', 'Haferflocken', 220, quantity: 60, unit: 'g', date: '2026-11-06', created: DateTime(2026, 11, 6, 8)),
  food('h2', 'Haferflocken', 220, quantity: 60, unit: 'g', date: '2026-11-05', created: DateTime(2026, 11, 5, 8)),
  food('h3', 'Skyr Natur', 130, quantity: 250, unit: 'g', brand: 'Milbona', date: '2026-11-06',
      created: DateTime(2026, 11, 6, 15)),
  food('h4', 'Apfel', 80, date: '2026-11-04', created: DateTime(2026, 11, 4, 10)),
];

/// The plus of a "Zuletzt gegessen" row (the text opens S7).
Finder _plus(String name) => find.byKey(ValueKey('cal-recent-log-${name.toLowerCase()}|'));

/// Back from a route the fake router pushed (it has no back button).
Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await settle(tester);
}

/// Chooses a segment the way the control does (in tests the control is the
/// pull-down: the test font is wider than SF Pro).
Future<void> _segment(WidgetTester tester, CalorieInputMethod method) async {
  final control = tester.widget<AppSegmentedControl<CalorieInputMethod>>(
      find.byType(AppSegmentedControl<CalorieInputMethod>));
  control.onChanged(method);
  await settle(tester);
}

void main() {
  testWidgets('title is the meal of the time of day; the menu changes it', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.bySemanticsLabel('Log Lunch'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Log Lunch')).hint, 'Change meal');

    await tester.tap(find.bySemanticsLabel('Log Lunch'));
    await settle(tester);
    await tester.tap(find.text('Dinner'));
    await settle(tester);
    expect(find.bySemanticsLabel('Log Dinner'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the input method: Photo | Barcode | Search, "Search" first; no photo while the AI is off', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
    await settle(tester);
    final control = tester.widget<AppSegmentedControl<CalorieInputMethod>>(
        find.byType(AppSegmentedControl<CalorieInputMethod>));
    expect(control.segments.map((s) => s.label), ['Photo', 'Barcode', 'Search']);
    expect(control.selected, CalorieInputMethod.search);
    expect(control.semanticLabel, 'Input method');

    await _segment(tester, CalorieInputMethod.barcode);
    expect(env.prefs.getString('cal_input_method_v1_$kUser'), 'barcode');
    expect(find.text('Open camera'), findsOneWidget);
  });

  testWidgets('kill switch: only Barcode and Search', (tester) async {
    final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'photo'});
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(ai: false));
    await settle(tester);
    final control = tester.widget<AppSegmentedControl<CalorieInputMethod>>(
        find.byType(AppSegmentedControl<CalorieInputMethod>));
    expect(control.segments.map((s) => s.label), ['Barcode', 'Search']);
    expect(control.selected, CalorieInputMethod.search);
  });

  testWidgets('"Zuletzt gegessen" lists each food once, recent and frequent mixed', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.text('RECENTLY EATEN'), findsOneWidget);
    expect(find.text('Haferflocken'), findsOneWidget);
    expect(find.text('60 g · 220 kcal'), findsOneWidget);
    expect(find.text('250 g · 130 kcal'), findsOneWidget);
    expect(find.text('80 kcal'), findsOneWidget);
  });

  testWidgets('the plus logs it for the chosen meal: check, "Logged", undo; the screen stays', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.breakfast),
        overrides: env.overrides(recent: _history));
    await settle(tester);

    final row = find.bySemanticsLabel('Haferflocken, 60 g, 220 calories');
    expect(tester.getSemantics(row).hint, 'Log Haferflocken');
    await tester.tap(_plus('Haferflocken'));
    await settle(tester);

    expect(find.text('Logged'), findsOneWidget);
    expect(find.text('Haferflocken logged'), findsOneWidget);
    final day = containerOf(tester).read(calorieDayProvider(kToday)).day!;
    final logged = day.entries.single;
    expect(logged.foodName, 'Haferflocken');
    expect(logged.mealType, MealType.breakfast);
    expect(logged.calories, 220);
    expect(find.byType(CaloriesAddScreen), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(containerOf(tester).read(calorieDayProvider(kToday)).day!.entries, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Logged'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a tap on the text opens S7 with that amount; long press offers "Different amount…"', (tester) async {
    final env = await CalorieTestEnv.create();
    final visited = await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.breakfast),
        overrides: env.overrides(recent: _history));
    await settle(tester);

    await tester.tap(find.text('Skyr Natur'));
    await settle(tester);
    expect(visited.last, '/calories/add/food/recent%3Ah3?meal=breakfast');

    await _back(tester);
    await tester.longPress(find.text('Apfel'));
    await settle(tester);
    expect(find.text('Different amount…'), findsOneWidget);
    expect(find.text('Remove from recent'), findsOneWidget);
  });

  testWidgets('another day: "For Thu, Nov 5" and logging goes to that day', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(dateKey: '2026-11-05'),
        overrides: env.overrides(recent: _history));
    await settle(tester);

    expect(find.text('For Thu, Nov 5'), findsOneWidget);
    await tester.tap(_plus('Apfel'));
    await settle(tester);
    final day = containerOf(tester).read(calorieDayProvider('2026-11-05')).day!;
    expect(day.entries.map((e) => e.foodName), contains('Apfel'));
  });

  testWidgets('left open over midnight: a tap logs for the new day', (tester) async {
    var now = DateTime(2026, 11, 7, 23, 58);
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.snack),
        overrides: env.overrides(recent: _history, clock: () => now));
    await settle(tester);

    now = DateTime(2026, 11, 8, 0, 3);
    await tester.tap(_plus('Apfel'));
    await settle(tester);
    final c = containerOf(tester);
    expect(c.read(calorieDayProvider('2026-11-08')).day!.entries.single.foodName, 'Apfel');
    expect(c.read(calorieDayProvider(kToday)).day?.entries ?? const [], isEmpty);
  });

  testWidgets('the history fails to load: says so with retry, never the first-run note', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(),
        overrides: env.overrides(recentError: StateError('server')));
    await settle(tester);

    expect(find.text('Couldn\'t load what you ate recently.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Foods you eat often will show up here. One tap logs them.'), findsNothing);
  });

  testWidgets('a picked day starts loading at once', (tester) async {
    final env = await CalorieTestEnv.create(server: {'2026-11-05': usualDay(date: '2026-11-05')});
    await pumpCalories(tester, const CaloriesAddScreen(dateKey: '2026-11-05'), overrides: env.overrides());
    await settle(tester);
    expect(containerOf(tester).read(calorieDayProvider('2026-11-05')).day!.entries, hasLength(3));
  });

  testWidgets('search filters the history; nothing anywhere: Avo thinks and "Enter manually" takes the text', (tester) async {
    final env = await CalorieTestEnv.create();
    final visited = await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    await tester.enterText(find.byType(EditableText), 'milb');
    await settle(tester);
    expect(find.text('Skyr Natur'), findsOneWidget);
    expect(find.text('Haferflocken'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'Pizza');
    await settle(tester);
    expect(find.text('Nothing found for “Pizza”.'), findsOneWidget);
    await tester.tap(find.text('Enter manually'));
    await settle(tester);
    expect(visited.last, '/calories/add/manual?meal=lunch&name=Pizza');
  });

  testWidgets('own foods at once, Open Food Facts after the pause; a hit opens S7', (tester) async {
    final env = await CalorieTestEnv.create();
    final visited = await pumpCalories(
      tester,
      const CaloriesAddScreen(),
      overrides: env.overrides(
        userFoods: [
          UserFood(id: 'o1', userId: kUser, name: 'Skyr mit Beeren', kcal100: 95, createdAt: DateTime(2026, 11, 1)),
        ],
        offHits: [offProduct('4056489123453', 'Skyr Natur', brand: 'Milbona')],
      ),
    );
    await settle(tester);

    await tester.enterText(find.byType(EditableText), 'Skyr');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('YOUR FOODS'), findsOneWidget);
    expect(find.text('Skyr mit Beeren'), findsOneWidget);
    expect(find.text('FOODS'), findsNothing, reason: 'online hits wait for the pause');

    await settle(tester);
    expect(find.text('FOODS'), findsOneWidget);
    expect(find.text('Milbona · 63 kcal per 100 g'), findsOneWidget);
    expect(find.text('Data: Open Food Facts'), findsOneWidget);

    await tester.tap(find.text('Skyr Natur'));
    await settle(tester);
    expect(visited.last, '/calories/add/food/4056489123453?meal=lunch');
  });

  testWidgets('the online search fails: a status row with retry, local hits stay', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(),
        overrides: env.overrides(recent: _history, offSearchError: kOffFailed));
    await settle(tester);

    await tester.enterText(find.byType(EditableText), 'Skyr');
    await settle(tester);
    expect(find.text('Online search didn\'t work.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Skyr Natur'), findsOneWidget);
    expect(find.textContaining('Nothing found'), findsNothing);
  });

  testWidgets('"Enter manually" row opens S8', (tester) async {
    final env = await CalorieTestEnv.create();
    final visited = await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.dinner), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Type in the name and calories'), findsOneWidget);
    await tester.tap(find.text('Enter manually'));
    await settle(tester);
    expect(visited.last, '/calories/add/manual?meal=dinner');
  });

  testWidgets('first start without history: the footnote explains what will show', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Foods you eat often will show up here. One tap logs them.'), findsOneWidget);
  });

  testWidgets('long press removes a food from "Zuletzt" and remembers it', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(recent: _history));
    await settle(tester);

    await tester.longPress(find.text('Apfel'));
    await settle(tester);
    await tester.tap(find.text('Remove from recent'));
    await settle(tester);
    expect(find.text('Apfel'), findsNothing);
    expect(env.prefs.getStringList('cal_recent_hidden_v1_$kUser'), contains('apfel|'));
  });

  testWidgets('offline: the stored history still shows, the status row says so, no online search', (tester) async {
    final env = await CalorieTestEnv.create(extraPrefs: {
      'cal_recent_v1_$kUser': jsonEncode([for (final e in _history) e.toJson()]),
    });
    await pumpCalories(
      tester,
      const CaloriesAddScreen(),
      overrides: env.overrides(
        offline: true,
        recentError: StateError('offline'),
        offHits: [offProduct('4056489123453', 'Skyr Light')],
      ),
    );
    await settle(tester);

    expect(find.text('You\'re offline. Only your own and recent foods are shown.'), findsOneWidget);
    expect(find.text('Skyr Natur'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Skyr');
    await settle(tester);
    expect(find.text('Skyr Light'), findsNothing);
  });

  testWidgets('close returns to where it was opened', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Close'));
    await settle(tester);
    expect(find.byType(CaloriesAddScreen), findsNothing);
  });

  group('Photo', () {
    testWidgets('never asked: the app explains first; "Not now" stays, "Continue" asks and opens S4', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'photo'});
      final camera = FakeCalorieCamera(permissionValue: CameraPermission.notDetermined);
      final visited = await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.lunch),
          overrides: env.overrides(camera: camera));
      await settle(tester);

      expect(find.text('Take a photo of your plate from above.'), findsOneWidget);
      expect(find.textContaining('estimated from the photo'), findsOneWidget);
      await tester.tap(find.text('Take photo'));
      await settle(tester);
      expect(find.text('Camera for meal photos'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(camera.requests, 0);
      expect(visited, isEmpty);

      await tester.tap(find.text('Take photo'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(camera.requests, 1);
      expect(visited.last, '/calories/add/photo?meal=lunch');
    });

    testWidgets('offline: the camera button is off and says why', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'photo'});
      final semantics = tester.ensureSemantics();
      await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(offline: true));
      await settle(tester);

      expect(find.text('Photo estimates need a connection.'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Take photo')), isSemantics(isEnabled: false));
      semantics.dispose();
    });

    testWidgets('daily limit (free): the limit, "Enter manually" and "See Avo Pro"', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {
        'cal_input_method_v1_$kUser': 'photo',
        'cal_photo_limit_v1_$kUser': kToday,
      });
      final visited = await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
      await settle(tester);

      expect(find.text('You\'ve used today\'s photo estimates. They\'re back tomorrow, or get up to 15 a day with Avo Pro.'),
          findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
      expect(find.text('See Avo Pro'), findsOneWidget);
      expect(find.text('Take photo'), findsNothing);
      // A9-3: the paywall for more AI a day, not a calories lock.
      await tester.tap(find.text('See Avo Pro'));
      await settle(tester);
      expect(visited, ['/pro?feature=avo_questions']);
    });

    testWidgets('daily limit (Pro): no paywall link', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {
        'cal_input_method_v1_$kUser': 'photo',
        'cal_photo_limit_v1_$kUser': kToday,
      });
      await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides(pro: true));
      await settle(tester);

      expect(find.text('You\'ve used today\'s photo estimates. They\'re back tomorrow.'), findsOneWidget);
      expect(find.text('See Avo Pro'), findsNothing);
    });

    testWidgets('"Choose from Photos" goes straight to S5', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'photo'});
      final camera = FakeCalorieCamera(pickResult: MealPhotoResult(MealPhotoStatus.picked, bytes: kJpeg));
      final visited = await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.dinner),
          overrides: env.overrides(camera: camera));
      await settle(tester);

      await tester.tap(find.text('Choose from Photos'));
      await settle(tester);
      expect(camera.picks, 1);
      expect(visited.last, '/calories/add/estimate?meal=dinner');
    });
  });

  group('Barcode', () {
    testWidgets('a typed number found on this device opens S7; an unknown one offers manual entry', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'barcode'});
      final visited = await pumpCalories(
        tester,
        const CaloriesAddScreen(),
        overrides: env.overrides(offProducts: {'4056489123453': offProduct('4056489123453', 'Skyr Natur')}),
      );
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), '4 056489 123453');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(visited.last, '/calories/add/food/4056489123453?meal=lunch');

      await _back(tester);
      expect(find.text('RECENTLY SCANNED'), findsOneWidget, reason: 'the found product is kept');

      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), '4000000000099');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('Nothing is known about this barcode.'), findsOneWidget);
      await tester.tap(find.text('Enter manually'));
      await settle(tester);
      expect(visited.last, '/calories/add/manual?meal=lunch&barcode=4000000000099');
    });

    testWidgets('the iPhone number pad has no return key: "Search" submits, from 8 digits on', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'barcode'});
      final visited = await pumpCalories(
        tester,
        const CaloriesAddScreen(),
        overrides: env.overrides(offProducts: {'4056489123453': offProduct('4056489123453', 'Skyr Natur')}),
      );
      await settle(tester);
      final search = find.byKey(const ValueKey('cal-barcode-search'));

      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), '405648');
      await settle(tester);
      await tester.tap(search);
      await settle(tester);
      expect(visited, isEmpty, reason: 'off below 8 digits');

      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), '4056489123453');
      await settle(tester);
      await tester.tap(search);
      await settle(tester);
      expect(visited.last, '/calories/add/food/4056489123453?meal=lunch');
    });

    testWidgets('?tab=barcode opens that segment without changing the remembered one', (tester) async {
      final env = await CalorieTestEnv.create();
      await pumpCalories(tester, const CaloriesAddScreen(tab: CalorieInputMethod.barcode), overrides: env.overrides());
      await settle(tester);
      expect(find.text('Open camera'), findsOneWidget);
      expect(env.prefs.getString('cal_input_method_v1_$kUser'), isNull);
    });

    testWidgets('a number with a wrong check digit says so under the field', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'barcode'});
      await pumpCalories(tester, const CaloriesAddScreen(), overrides: env.overrides());
      await settle(tester);

      await tester.enterText(find.byKey(const ValueKey('cal-barcode-field')), '4056489123450');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('That number doesn\'t fit. Check the digits under the barcode.'), findsOneWidget);
    });

    testWidgets('no camera scanner: only the field, with a footnote', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'barcode'});
      await pumpCalories(tester, const CaloriesAddScreen(),
          overrides: env.overrides(camera: FakeCalorieCamera(supported: false)));
      await settle(tester);

      expect(find.text('Open camera'), findsNothing);
      expect(find.text('This iPhone can\'t read barcodes with the camera. Enter the number instead.'), findsOneWidget);
    });

    testWidgets('"Open camera" opens S6 with meal and day', (tester) async {
      final env = await CalorieTestEnv.create(extraPrefs: {'cal_input_method_v1_$kUser': 'barcode'});
      final visited = await pumpCalories(tester, const CaloriesAddScreen(meal: MealType.snack, dateKey: '2026-11-05'),
          overrides: env.overrides());
      await settle(tester);

      await tester.tap(find.text('Open camera'));
      await settle(tester);
      expect(visited.last, '/calories/scan?meal=snack&date=2026-11-05');
    });
  });

  test('ranking: newest, most often, second newest …, each food once, hidden ones out', () {
    final ranked = rankRecentFoods([
      food('a', 'Apfel', 80, created: DateTime(2026, 11, 7, 9)),
      food('b', 'Brot', 200, created: DateTime(2026, 11, 1)),
      food('c', 'Brot', 200, created: DateTime(2026, 11, 2)),
      food('d', 'Brot', 200, created: DateTime(2026, 11, 3)),
      food('e', 'Ei', 90, created: DateTime(2026, 11, 6)),
      food('f', 'Kaffee', 5, created: DateTime(2026, 11, 5)),
    ], hidden: {'kaffee|'});
    expect(ranked.map((r) => r.template.foodName), ['Apfel', 'Brot', 'Ei']);
    expect(ranked[1].count, 3);
    expect(ranked[1].template.id, 'd');
  });
}
