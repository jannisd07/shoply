import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_browse_state.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/presentation/widgets/tips/tip_row.dart';

import 'recipes_browse_fakes.dart';
import 'recipes_browse_harness.dart';

List<Override> _ready({
  RecipeDietProfile profile = RecipeDietProfile.none,
  bool offline = false,
  bool planOn = false,
  List<Set<String>> listItems = const [],
  RecipeHighlights? highlights,
}) => browseOverrides(
  seed: browseCatalogue(),
  fresh: browseCatalogue(),
  profile: profile,
  offline: offline,
  planOn: planOn,
  listItems: listItems,
  highlights: highlights,
);

/// Scrolls the tab (not a chip row) until [finder] shows.
Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('D2: title, search, chips, hero for the list, popular grid', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(
        listItems: [nameStems('Tomaten'), nameStems('Feta')],
        highlights: const RecipeHighlights(popularIds: ['dal', 'pasta']),
      ),
    );
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Recipes, ingredients, creators'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'For you'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'Quick'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'Vegetarian'), findsOneWidget);
    expect(find.byType(RecipeHeroCard), findsOneWidget);
    expect(find.text('FITS YOUR LIST'), findsOneWidget);
    expect(find.text('Shakshuka mit Feta'), findsOneWidget);
    expect(find.text('25 min · ★ 4.8 (126) · vegetarian'), findsOneWidget);
    expect(find.text('Add ingredients to list'), findsOneWidget);
    expect(find.text('Popular this week'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    // Server order first.
    expect(find.text('Rotes Linsen-Dal'), findsOneWidget);
    expect(find.text('Avocado-Pasta'), findsOneWidget);
    expect(find.bySemanticsLabel('Saved recipes'), findsOneWidget);
    expect(find.bySemanticsLabel('More'), findsOneWidget);
    // No meal plan segment while the module is off.
    expect(find.byType(AppSegmentedControl<Object>), findsNothing);
  });

  testWidgets('sets Avo\'s screen context to recipes', (tester) async {
    final container = ProviderContainer(overrides: _ready());
    addTearDown(container.dispose);
    await pumpBrowse(tester, const [], container: container);
    expect(container.read(avoScreenContextProvider)?.screen, 'recipes');
  });

  testWidgets('first start without local recipes: placeholders, no spinner', (
    tester,
  ) async {
    await pumpBrowse(tester, browseOverrides());
    expect(find.bySemanticsLabel('Loading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RecipeHeroCard), findsNothing);
  });

  testWidgets('empty catalogue: first recipe', (tester) async {
    await pumpBrowse(tester, browseOverrides(fresh: const []));
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No recipes in this language yet.'), findsOneWidget);
    expect(find.text('Write the first recipe'), findsOneWidget);
  });

  testWidgets('offline keeps the local recipes and says so', (tester) async {
    await pumpBrowse(
      tester,
      browseOverrides(seed: browseCatalogue(), fresh: const [], offline: true),
    );
    expect(find.text('Offline. You\'re seeing saved recipes.'), findsOneWidget);
    expect(find.byType(RecipeHeroCard), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the recipes and offers a retry', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      browseOverrides(seed: browseCatalogue(), freshFails: true),
    );
    expect(
      find.textContaining('Recipes couldn\'t be updated.'),
      findsOneWidget,
    );
    expect(find.byType(RecipeHeroCard), findsOneWidget);
  });

  testWidgets('allergens: "For you" leaves them out, other chips warn', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(profile: const RecipeDietProfile(allergies: ['sesame'])),
    );
    expect(find.text('Gurkensalat mit Sesam'), findsNothing);
    final healthy = find.widgetWithText(AppFilterChip, 'Healthy');
    await tester.ensureVisible(healthy);
    await tester.pump();
    await tester.tap(healthy);
    await tester.pump(const Duration(milliseconds: 600));
    await _scrollTo(
      tester,
      find.textContaining('Contains sesame', findRichText: true),
    );
    expect(find.text('Gurkensalat mit Sesam'), findsOneWidget);
    // The hero is never the recipe with the allergen.
    final hero = tester.widget<RecipeHeroCard>(find.byType(RecipeHeroCard));
    expect(hero.title, 'Rotes Linsen-Dal');
  });

  testWidgets('a chip narrows the tab to its recipes', (tester) async {
    await pumpBrowse(tester, _ready());
    await tester.tap(find.widgetWithText(AppFilterChip, 'Quick'));
    await tester.pump(const Duration(milliseconds: 600));
    final hero = tester.widget<RecipeHeroCard>(find.byType(RecipeHeroCard));
    expect(hero.eyebrow, 'Quick');
    for (final card in tester.widgetList<RecipeCard>(find.byType(RecipeCard))) {
      expect(
        browseCatalogue()
            .firstWhere((r) => r.name == card.title)
            .totalTimeMinutes,
        lessThanOrEqualTo(kQuickRecipeMinutes),
      );
    }
  });

  testWidgets('search: recipes, "With ingredient", nothing found', (
    tester,
  ) async {
    await pumpBrowse(tester, _ready());
    await tester.enterText(find.byType(EditableText), 'feta');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RecipeHeroCard), findsNothing);
    expect(find.text('Shakshuka mit Feta'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await _scrollTo(tester, find.text('Recipes with feta'));
    expect(find.text('Recipes with feta'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Halloumi-Burger');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Nothing found for “Halloumi-Burger”.'), findsOneWidget);
    expect(
      find.text('Try an ingredient, for example “Halloumi”.'),
      findsOneWidget,
    );
    expect(find.text('Write your own recipe'), findsOneWidget);
  });

  testWidgets('search before typing: diet chips; a hit is remembered', (
    tester,
  ) async {
    final router = browseRouter();
    await pumpBrowse(
      tester,
      _ready(profile: const RecipeDietProfile(diets: ['vegan'])),
      router: router,
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Diet'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'Fits me'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'Low carb'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'dal');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Rotes Linsen-Dal'));
    await tester.pumpAndSettle();
    expect(find.text('at /recipes/dal'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.text('dal'), findsWidgets);
  });

  testWidgets('hero action opens the detail with "to list"', (tester) async {
    final router = browseRouter();
    await pumpBrowse(
      tester,
      _ready(listItems: [nameStems('Tomaten'), nameStems('Feta')]),
      router: router,
    );
    await tester.tap(find.text('Add ingredients to list'));
    await tester.pumpAndSettle();
    expect(find.text('at /recipes/shakshuka?action=to-list'), findsOneWidget);
  });

  testWidgets('"All" of popular opens the popular page', (tester) async {
    final router = browseRouter();
    await pumpBrowse(tester, _ready(), router: router);
    await tester.tap(find.bySemanticsLabel('All').first);
    await tester.pumpAndSettle();
    expect(find.text('By ratings'), findsOneWidget);
  });

  testWidgets('toolbar: saved and the more menu', (tester) async {
    final router = browseRouter();
    await pumpBrowse(tester, _ready(), router: router);
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('My recipes'), findsOneWidget);
    expect(find.text('Drafts'), findsOneWidget);
    expect(find.text('Creators'), findsOneWidget);
    expect(find.text('New recipe'), findsOneWidget);
    await tester.tap(find.text('New recipe'));
    await tester.pumpAndSettle();
    expect(find.text('at /recipes/add'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Saved recipes'));
    await tester.pumpAndSettle();
    expect(find.text('at /recipes/saved'), findsOneWidget);
  });

  testWidgets('meal plan module on: segment "Discover | Meal plan"', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(planOn: true),
      router: browseRouter(initial: '/recipes?segment=plan'),
    );
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Meal plan'), findsOneWidget);
    expect(find.byType(RecipeHeroCard), findsNothing);
    await tester.tap(find.text('Discover'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RecipeHeroCard), findsOneWidget);
  });

  testWidgets(
    'meal plan: grey ground, B\'s toolbar instead of Saved (A-P3/4)',
    (tester) async {
      await pumpBrowse(
        tester,
        _ready(planOn: true),
        router: browseRouter(initial: '/recipes?segment=plan'),
      );
      await tester.pump(const Duration(milliseconds: 600));
      Color ground() => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(RecipesScreen),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      final colors = tester.element(find.byType(RecipesScreen)).colors;
      expect(ground(), colors.background);
      expect(find.bySemanticsLabel('Saved recipes'), findsNothing);

      await tester.tap(find.text('Discover'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(ground(), colors.backgroundPlain);
      expect(find.bySemanticsLabel('Saved recipes'), findsOneWidget);
    },
  );

  testWidgets('without the tip service: no tip and no older diet hint', (
    tester,
  ) async {
    await pumpBrowse(tester, _ready());
    expect(
      find.text('Set your diet and allergies. Recipes adapt to them.'),
      findsNothing,
    );
    expect(find.byType(TipRow), findsNothing);
  });
}
