import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';

import '../screens/recipes/recipes_browse_fakes.dart';
import '../screens/recipes/recipes_browse_harness.dart';

/// Teil A6's diet hint below the chips is tip T7 while Rezepte has no tip
/// slot under its large title yet.
const _dietHint = 'Set your diet and allergies. Recipes adapt to them.';

Future<TipService> _tips() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return TipService(clock: () => DateTime(2026, 11, 8, 10))..attach(prefs);
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

void main() {
  testWidgets('T7 from the second visit; closing it finishes the tip', (
    tester,
  ) async {
    final tips = await _tips();
    await _open(tester, tips);
    expect(find.text(_dietHint), findsNothing);
    expect(tips.visits(TipPlace.recipes), 1);
    // T6 cannot be drawn here yet, so it is not used up.
    expect(tips.isFinished(TipId.recipeToList), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester, tips);
    expect(find.text(_dietHint), findsOneWidget);
    expect(tips.active, TipId.diet);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_dietHint), findsNothing);
    expect(tips.isFinished(TipId.diet), isTrue);
  });

  testWidgets('with a diet set, T7 is done and never shows', (tester) async {
    final tips = await _tips();
    tips
      ..visit(TipPlace.recipes)
      ..visit(TipPlace.recipes);
    await _open(
      tester,
      tips,
      profile: const RecipeDietProfile(diets: ['vegan']),
    );
    expect(find.text(_dietHint), findsNothing);
    await tester.pump();
    expect(tips.isFinished(TipId.diet), isTrue);
  });

  testWidgets('another tip today: no diet hint (one tip at a time)', (
    tester,
  ) async {
    final tips = await _tips();
    tips
      ..visit(TipPlace.recipes)
      ..startArrivalTip(TipId.quantity);
    await _open(tester, tips);
    expect(find.text(_dietHint), findsNothing);
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
