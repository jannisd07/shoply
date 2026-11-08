// S1, S1a, S2, S12 of docs/redesign/b-screens/kalorien.md: the diary.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/calories_diary_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_ring.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

import 'calorie_fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] into the middle of the diary (the list builds lazily).
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CaloriesDiaryScreen)));

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  testWidgets('shows the stored day: left, eaten, goal, meals and water', (tester) async {
    final env = await CalorieTestEnv.create(
      stored: {kToday: usualDay()},
      server: {kToday: usualDay()},
      storedGoal: goal(),
    );
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());

    expect(find.byType(CalorieRing), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('1,360 eaten · goal 2,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Calories today: 640 of 2,000 left, 1,360 eaten.'), findsOneWidget);
    // The macros are their own elements (S1 Barrierefreiheit).
    final protein = tester.getSemantics(find.bySemanticsLabel('Protein'));
    expect(protein.value, '82 of 133 grams');
    expect(find.text('Spaghetti Bolognese'), findsOneWidget);
    expect(find.text('1 serving · estimated'), findsOneWidget);
    expect(find.text('60 g'), findsOneWidget);
    expect(find.bySemanticsLabel('Spaghetti Bolognese, estimated, 940 calories, Lunch'), findsOneWidget);
    expect(find.bySemanticsLabel('Log Breakfast'), findsOneWidget);
    expect(find.bySemanticsLabel('Date: Today, Saturday, November 7'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('German: numbers, words and dates in the device language', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(),
        overrides: env.overrides(), locale: const Locale('de'));
    await settle(tester);

    expect(find.text('Kalorien'), findsOneWidget);
    expect(find.text('kcal übrig'), findsOneWidget);
    expect(find.text('1.360 gegessen · Ziel 2.000'), findsOneWidget);
    expect(find.textContaining('Heute, Sa., 7. Nov.', findRichText: true), findsOneWidget);
    expect(find.text('FRÜHSTÜCK'), findsOneWidget);
    expect(find.text('Eintragen'), findsWidgets);
  });

  testWidgets('a goal row on the server but nothing today: full budget, no empty state', (tester) async {
    final env = await CalorieTestEnv.create();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    expect(find.text('Nothing eaten yet · goal 2,000'), findsOneWidget);
    expect(find.text('Log food'), findsWidgets);
  });

  testWidgets('over the goal: how far over, in words, never red', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalValue: goal(kcal: 1240)));
    await settle(tester);

    expect(find.text('kcal over'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Calories today: 120 over the goal of 1,240')), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle_fill), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no goal: S1a with three choices; "Log without a goal" shows the diary without a ring',
      (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final visited = await pumpCalories(tester, const CaloriesDiaryScreen(),
        overrides: env.overrides(goalValue: null));
    await settle(tester);

    expect(find.text('How much do you want to eat each day?'), findsOneWidget);
    expect(find.text('Log without a goal'), findsOneWidget);
    expect(find.text('Turn off Calories'), findsOneWidget);

    await tester.tap(find.text('Set a goal'));
    await settle(tester);
    expect(visited.last, '/calories/goals/setup?from=empty');
  });

  testWidgets('"Log without a goal" is remembered and shows eaten kcal, plain macros', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalValue: null));
    await settle(tester);
    await tester.tap(find.text('Log without a goal'));
    await settle(tester);

    expect(find.byType(CalorieRing), findsNothing);
    expect(find.text('kcal eaten'), findsOneWidget);
    expect(find.text('Protein 82 g'), findsOneWidget);
    expect(find.text('Set a goal'), findsOneWidget);
    expect(env.prefs.getBool('cal_without_goal_v1_$kUser'), isTrue);
  });

  testWidgets('"Turn off Calories" leaves first, then switches the module off with undo', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalValue: null));
    await settle(tester);
    await tester.tap(find.text('Turn off Calories'));
    await settle(tester);

    expect(find.byType(CaloriesDiaryScreen), findsNothing);
    expect(env.modules.written?['calories'], isFalse);
    expect(find.text('Calories turned off'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('a network error without a stored goal is an error, never "no goal"', (tester) async {
    final env = await CalorieTestEnv.create();
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalError: true));
    await settle(tester);

    expect(find.text('Couldn\'t load your diary.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('How much do you want to eat each day?'), findsNothing);
  });

  testWidgets('offline without a stored day: says so, no button', (tester) async {
    final env = await CalorieTestEnv.create();
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(offline: true));
    await settle(tester);

    expect(find.text('You\'re offline. Your diary will appear once you\'re back online.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offline with a stored day: the day plus the offline status row', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, storedGoal: goal());
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(offline: true));
    await settle(tester);

    expect(find.text('You\'re offline. Your entries will be saved once you\'re back online.'), findsOneWidget);
    expect(find.text('Haferflocken'), findsOneWidget);
  });

  testWidgets('first start without anything stored: calm placeholders, no spinner', (tester) async {
    final env = await CalorieTestEnv.create();
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalLoading: true));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('a past day: eaten and the difference to the goal, "Today" goes back', (tester) async {
    final env = await CalorieTestEnv.create(server: {'2026-11-05': usualDay(date: '2026-11-05')});
    await pumpCalories(tester, const CaloriesDiaryScreen(initialDateKey: '2026-11-05'), overrides: env.overrides());
    await settle(tester);

    expect(find.text('kcal eaten'), findsOneWidget);
    expect(find.text('Goal 2,000 · 640 under'), findsOneWidget);
    expect(find.textContaining('Thu, Nov 5', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text('Nothing eaten yet · goal 2,000'), findsOneWidget);
  });

  testWidgets('the date menu lists seven days with kcal and switches the day', (tester) async {
    final env = await CalorieTestEnv.create(
      server: {kToday: usualDay(), '2026-11-06': usualDay(date: '2026-11-06')},
    );
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.tap(find.textContaining('Today, Sat, Nov 7', findRichText: true));
    await settle(tester);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Choose date…'), findsOneWidget);
    expect(find.text('1,360 kcal'), findsWidgets);

    await tester.tap(find.text('Yesterday'));
    await settle(tester);
    expect(find.textContaining('Yesterday, Fri, Nov 6', findRichText: true), findsOneWidget);
  });

  testWidgets('VoiceOver: swiping down on the group shows the day before', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Calories today:'))).hint,
        'Swipe up or down to change the day.');
    tester.semantics.decrease(find.semantics.byLabel(RegExp(r'^Calories today:')));
    await settle(tester);
    expect(find.bySemanticsLabel('Date: Yesterday, Friday, November 6'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a horizontal fling on the group shows the day before; left of today rubber-bands', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.fling(find.text('kcal left'), const Offset(-200, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Date: Today, Saturday, November 7'), findsOneWidget);

    await tester.fling(find.text('kcal left'), const Offset(200, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Date: Yesterday, Friday, November 6'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('midnight: the diary moves on to the new day by itself', (tester) async {
    var now = DateTime(2026, 11, 7, 23, 59, 30);
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(clock: () => now));
    await settle(tester);
    expect(find.bySemanticsLabel('Date: Today, Saturday, November 7'), findsOneWidget);

    now = DateTime(2026, 11, 8, 0, 0, 31);
    await tester.pump(const Duration(seconds: 31));
    await settle(tester);
    expect(find.bySemanticsLabel('Date: Today, Sunday, November 8'), findsOneWidget);
    expect(find.text('Nothing eaten yet · goal 2,000'), findsOneWidget);

    // A write after midnight lands on the new day.
    await reveal(tester, find.text('+250 ml'));
    await tester.tap(find.text('+250 ml'));
    await settle(tester);
    final c = containerOf(tester);
    expect(c.read(calorieDayProvider('2026-11-08')).day!.waterMl, 250);
    expect(c.read(calorieDayProvider(kToday)).day!.waterMl, 1250);
    semantics.dispose();
  });

  testWidgets('back from the background after midnight: "Heute" is the new day at once', (tester) async {
    var now = DateTime(2026, 11, 7, 23, 59, 30);
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(clock: () => now));
    await settle(tester);

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    // The night passes while iOS keeps the app suspended (its timers stand still).
    now = DateTime(2026, 11, 8, 7, 15);
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Date: Today, Sunday, November 8'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a goal that fails to load with a known day: eaten kcal and a retry, never "no goal"',
      (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(goalError: true));
    await settle(tester);

    expect(find.text('kcal eaten'), findsOneWidget);
    expect(find.text('Couldn\'t load your goal.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Set a goal'), findsNothing);
    expect(find.text('How much do you want to eat each day?'), findsNothing);
  });

  testWidgets('an error without a stored day keeps the date line, so the day can still change', (tester) async {
    final env = await CalorieTestEnv.create(server: {'2026-11-06': usualDay(date: '2026-11-06')});
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, const CaloriesDiaryScreen(initialDateKey: '2026-11-03'),
        overrides: env.overrides(offline: true));
    await settle(tester);

    expect(find.text('You\'re offline. Your diary will appear once you\'re back online.'), findsOneWidget);
    expect(find.textContaining('Tue, Nov 3', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.textContaining('Today, Sat, Nov 7', findRichText: true), findsOneWidget);
  });

  testWidgets('back online: the diary loads by itself', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    env.remote.fetchError = const CalorieDataException(CalorieErrorCode.network);
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides(offline: true));
    await settle(tester);
    expect(find.text('You\'re offline. Your diary will appear once you\'re back online.'), findsOneWidget);

    env.remote.fetchError = null;
    containerOf(tester).read(testOfflineProvider.notifier).state = false;
    await settle(tester);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('Haferflocken'), findsOneWidget);
  });

  testWidgets('a new ?date= on the open diary shows that day', (tester) async {
    final env = await CalorieTestEnv.create(server: {'2026-11-05': usualDay(date: '2026-11-05')});
    final date = ValueNotifier<String?>(null);
    await pumpCalories(
      tester,
      ValueListenableBuilder<String?>(
        valueListenable: date,
        builder: (_, key, __) => CaloriesDiaryScreen(initialDateKey: key),
      ),
      overrides: env.overrides(),
    );
    await settle(tester);
    expect(find.textContaining('Today, Sat, Nov 7', findRichText: true), findsOneWidget);

    date.value = '2026-11-05';
    await settle(tester);
    expect(find.textContaining('Thu, Nov 5', findRichText: true), findsOneWidget);
    expect(find.text('Goal 2,000 · 640 under'), findsOneWidget);
  });

  testWidgets('swipe left deletes; "Undo" puts the same row back in its place', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    final before = containerOf(tester).read(calorieDayProvider(kToday)).day!.entries;
    await tester.drag(find.text('Haferflocken'), const Offset(-380, 0));
    await tester.pumpAndSettle();
    expect(find.text('Haferflocken'), findsNothing);
    expect(find.text('Haferflocken deleted'), findsOneWidget);
    expect(env.remote.days[kToday]!.entries.map((e) => e.id), isNot(contains('e1')));

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final after = containerOf(tester).read(calorieDayProvider(kToday)).day!.entries;
    expect(after, before);
    expect(find.text('Haferflocken'), findsOneWidget);
  });

  testWidgets('a delete that fails brings the swiped row back and says so', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(
      tester,
      const CaloriesDiaryScreen(),
      overrides: [...env.overrides(), calorieDiaryProvider.overrideWith(_FailingDeleteDiary.new)],
    );
    await settle(tester);

    await tester.drag(find.text('Haferflocken'), const Offset(-380, 0));
    await tester.pumpAndSettle();
    expect(find.text('Haferflocken'), findsOneWidget);
    expect(find.text('Couldn\'t save that. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the plus opens "Essen eintragen" with the meal of the time of day', (tester) async {
    final env = await CalorieTestEnv.create();
    final visited = await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Log food').first);
    await settle(tester);
    expect(visited.last, '/calories/add?meal=lunch');
  });

  testWidgets('long press → Delete removes the row, "Undo" brings it back', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.longPress(find.text('Banane'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Banane'), findsNothing);
    expect(find.text('Banane deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Banane'), findsOneWidget);
  });

  testWidgets('long press → move to another meal', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await tester.longPress(find.text('Banane'));
    await settle(tester);
    await tester.tap(find.text('Move to another meal'));
    await settle(tester);
    await tester.tap(find.text('Dinner'));
    await settle(tester);

    final day = containerOf(tester).read(calorieDayProvider(kToday)).day!;
    expect(day.entries.firstWhere((e) => e.id == 'e2').mealType, MealType.dinner);
  });

  testWidgets('a row the server refused says "Not saved" and retries on tap', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    env.remote.writeError = const CalorieDataException(CalorieErrorCode.rejected);
    await containerOf(tester).read(calorieDiaryProvider).addFood(food('', 'Skyr', 120, meal: MealType.snack));
    await settle(tester);

    await reveal(tester, find.text('Not saved'));
    expect(find.text('Not saved'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Skyr, 120 calories, Snacks, not saved\.')), findsOneWidget);

    env.remote.writeError = null;
    await tester.tap(find.text('Not saved'));
    await settle(tester);
    expect(find.text('Not saved'), findsNothing);
    semantics.dispose();
  });

  testWidgets('water: "+250 ml" adds for the shown day with undo', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await reveal(tester, find.text('+250 ml'));
    expect(find.bySemanticsLabel('Water, 1.25 of 2 litres'), findsOneWidget);
    await tester.tap(find.text('+250 ml'));
    await settle(tester);
    expect(find.bySemanticsLabel('Water, 1.5 of 2 litres'), findsOneWidget);
    expect(find.text('Added 250 ml of water'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('water: "Other amount…" asks in a centred alert and rejects non-numbers', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final semantics = tester.ensureSemantics();
    await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await reveal(tester, find.text('+250 ml'));
    await tester.longPress(find.bySemanticsLabel('Water, 1.25 of 2 litres'));
    await settle(tester);
    expect(find.text('+150 ml'), findsOneWidget);
    expect(find.textContaining('Remove last entry (500 ml'), findsOneWidget);
    await tester.tap(find.text('Other amount…'));
    await settle(tester);

    expect(find.text('Add water'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'viel');
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Enter a number, for example 450 or 450.5'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '300');
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(find.bySemanticsLabel('Water, 1.55 of 2 litres'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('?focus=water scrolls the water row into view', (tester) async {
    final env = await CalorieTestEnv.create(stored: {kToday: usualDay()}, storedGoal: goal());
    await pumpCalories(tester, const CaloriesDiaryScreen(focusWater: true), overrides: env.overrides());
    await settle(tester);

    final chip = tester.getRect(find.text('+250 ml'));
    expect(chip.top, greaterThan(0));
    expect(chip.bottom, lessThan(844));
  });

  testWidgets('week and links: weight, challenge day and goal as values', (tester) async {
    final env = await CalorieTestEnv.create(server: {kToday: usualDay()});
    final visited = await pumpCalories(tester, const CaloriesDiaryScreen(), overrides: env.overrides());
    await settle(tester);

    await reveal(tester, find.text('Goals'));
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('72.4 kg'), findsOneWidget);
    expect(find.text('16:8 · day 5'), findsOneWidget);
    expect(find.text('2,000 kcal'), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await settle(tester);
    expect(visited.last, '/calories/goals');
  });
}

/// A diary whose deletes fail (signed out in the meantime).
class _FailingDeleteDiary extends CalorieDiary {
  _FailingDeleteDiary(super.ref);

  @override
  Future<FoodLogEntry> deleteFood(FoodLogEntry entry) async =>
      throw const CalorieDataException(CalorieErrorCode.notSignedIn);
}
