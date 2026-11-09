import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import '../screens/recipes/recipes_browse_fakes.dart';
import '../screens/recipes/recipes_browse_harness.dart';

/// T6 and T7 sit in the tip slot below Rezepte's large title.
const _t6 =
    'Tip: “Add ingredients to list” in a recipe puts everything you need for it on your list.';
const _t7 = 'Tip: Set your diet and allergies, and recipes adapt to you.';

/// The tips' clock; tests move it to the next day.
DateTime _now = DateTime(2026, 11, 8, 10);

Future<TipService> _tips([Map<String, Object> stored = const {}]) async {
  _now = DateTime(2026, 11, 8, 10);
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return TipService(clock: () => _now)..attach(prefs);
}

Future<void> _open(
  WidgetTester tester,
  TipService tips, {
  RecipeDietProfile profile = RecipeDietProfile.none,
}) async {
  await pumpBrowse(tester, [
    ...browseOverrides(
      seed: browseCatalogue(),
      fresh: browseCatalogue(),
      profile: profile,
    ),
    tipServiceProvider.overrideWithValue(tips),
  ]);
}

/// Leaves the tab and opens it again (a new visit).
Future<void> _reopen(
  WidgetTester tester,
  TipService tips, {
  RecipeDietProfile profile = RecipeDietProfile.none,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _open(tester, tips, profile: profile);
}

void main() {
  testWidgets('T6 on the first visit, below the large title', (tester) async {
    final tips = await _tips();
    await _open(tester, tips);
    expect(find.text(_t6), findsOneWidget);
    expect(tips.active, TipId.recipeToList);
    expect(tips.visits(TipPlace.recipes), 1);
    final title = tester.getRect(find.text('Recipes').first);
    final tip = tester.getRect(find.byType(TipRow));
    final search = tester.getRect(find.text('Recipes, ingredients, creators'));
    expect(tip.top, greaterThan(title.bottom));
    expect(tip.bottom, lessThan(search.top));
  });

  testWidgets('T7 the next day on the second visit; "Set up" opens the diet', (
    tester,
  ) async {
    final tips = await _tips();
    await _open(tester, tips);
    _now = DateTime(2026, 11, 9, 10);
    await _reopen(tester, tips);
    expect(find.text(_t6), findsNothing);
    expect(find.text(_t7), findsOneWidget);
    expect(tips.active, TipId.diet);

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    expect(find.text('at /diet-preferences'), findsOneWidget);
  });

  testWidgets('the older diet hint is gone (T7 replaces it)', (tester) async {
    final tips = await _tips();
    await _open(tester, tips);
    expect(
      find.text('Set your diet and allergies. Recipes adapt to them.'),
      findsNothing,
    );
  });

  testWidgets('hiding T6 collapses the row without a gap', (tester) async {
    final tips = await _tips();
    await _open(tester, tips);
    final searchBefore = tester.getRect(
      find.text('Recipes, ingredients, creators'),
    );
    tips.dismiss(TipId.recipeToList);
    await tester.pumpAndSettle();
    expect(find.byType(TipRow), findsNothing);
    final searchAfter = tester.getRect(
      find.text('Recipes, ingredients, creators'),
    );
    expect(searchAfter.top, lessThan(searchBefore.top));
    expect(tips.isFinished(TipId.recipeToList), isTrue);
  });

  testWidgets('with a diet set, T7 is done and never shows', (tester) async {
    final tips = await _tips();
    tips
      ..visit(TipPlace.recipes)
      ..visit(TipPlace.recipes)
      ..markDone(TipId.recipeToList);
    await _open(
      tester,
      tips,
      profile: const RecipeDietProfile(diets: ['vegan']),
    );
    expect(find.text(_t7), findsNothing);
    await tester.pump();
    expect(tips.isFinished(TipId.diet), isTrue);
  });

  testWidgets('another tip today: no tip here (one tip at a time)', (
    tester,
  ) async {
    final tips = await _tips();
    tips
      ..visit(TipPlace.recipes)
      ..startArrivalTip(TipId.quantity);
    await _open(tester, tips);
    expect(find.byType(TipRow), findsNothing);
  });

  testWidgets('the older diet hint wiped away: no T7', (tester) async {
    final tips = await _tips({
      'recipes_browse_v1_u1': '{"dietHintDismissed":true}',
    });
    tips
      ..visit(TipPlace.recipes)
      ..markDone(TipId.recipeToList);
    await _open(tester, tips);
    await tester.pumpAndSettle();
    expect(find.text(_t7), findsNothing);
    expect(tips.isFinished(TipId.diet), isTrue);
  });

  testWidgets('"Zutaten auf die Liste" finishes T6', (tester) async {
    final tips = await _tips();
    await _open(tester, tips);
    await tester.tap(find.text('Add ingredients to list'));
    await tester.pump();
    expect(tips.isFinished(TipId.recipeToList), isTrue);
    await tester.pumpAndSettle();
  });
}
