import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import 'recipes_browse_fakes.dart';
import 'recipes_browse_harness.dart';

List<Override> _ready({
  RecipeDietProfile profile = RecipeDietProfile.none,
  bool offline = false,
}) => browseOverrides(
  seed: browseCatalogue(),
  fresh: browseCatalogue(),
  profile: profile,
  offline: offline,
);

List<String> _titles(WidgetTester tester) => [
  for (final c in tester.widgetList<RecipeCard>(find.byType(RecipeCard)))
    c.title,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('category: title, count, chips and the grid', (tester) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/category/vegetarian'),
    );
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('3 recipes'), findsOneWidget);
    expect(find.byType(RecipeCard), findsNWidgets(3));
    // Its own label is not offered again; occurring filters are.
    expect(find.widgetWithText(AppFilterChip, 'Vegetarian'), findsNothing);
    expect(find.widgetWithText(AppFilterChip, 'Under 20 min'), findsOneWidget);
    expect(find.widgetWithText(AppFilterChip, 'Fits me'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Back')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Sort, Popular')), findsOneWidget);

    await tester.tap(find.widgetWithText(AppFilterChip, 'Under 20 min'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1 of 3 recipes'), findsOneWidget);
    expect(_titles(tester), ['Avocado-Pasta']);

    await tester.tap(find.text('Reset'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('3 recipes'), findsOneWidget);
  });

  testWidgets('sort menu with the current order checked', (tester) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/category/vegetarian'),
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Sort')));
    await tester.pumpAndSettle();
    expect(find.text('Quickest first'), findsOneWidget);
    await tester.tap(find.text('Quickest first'));
    await tester.pumpAndSettle();
    expect(_titles(tester).first, 'Avocado-Pasta');
    expect(
      find.bySemanticsLabel(RegExp('^Sort, Quickest first')),
      findsOneWidget,
    );
  });

  testWidgets('"Fits me" starts on with allergies and warns elsewhere', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(profile: const RecipeDietProfile(allergies: ['sesame'])),
      router: browseRouter(initial: '/recipes/category/healthy'),
    );
    final fitsMe = tester.widget<AppFilterChip>(
      find.widgetWithText(AppFilterChip, 'Fits me'),
    );
    expect(fitsMe.selected, isTrue);
    expect(_titles(tester), ['Rotes Linsen-Dal']);
    expect(find.text('1 of 2 recipes'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppFilterChip, 'Fits me'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_titles(tester), contains('Gurkensalat mit Sesam'));
    expect(
      find.textContaining('Contains sesame', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('ingredient page and an empty category', (tester) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/category/ingredient:feta'),
    );
    expect(find.text('Recipes with feta'), findsOneWidget);
    expect(_titles(tester), ['Shakshuka mit Feta']);
  });

  testWidgets('a category without recipes', (tester) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/category/seafood'),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.textContaining('There are no recipes in'), findsOneWidget);
    expect(find.text('Write a recipe'), findsOneWidget);
  });

  testWidgets('filters that leave nothing: one sentence and reset', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/category/soup?filter=under-20'),
    );
    expect(find.text('No recipes with these filters.'), findsOneWidget);
    await tester.tap(find.text('Reset filters'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RecipeCard), findsOneWidget);
  });

  testWidgets('all recipes: newest first, preset filter from the link', (
    tester,
  ) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/all?filter=under-20'),
    );
    expect(find.text('All recipes'), findsOneWidget);
    final quick = browseCatalogue()
        .where((r) => r.totalTimeMinutes <= kQuickRecipeMinutes)
        .length;
    expect(find.text('$quick of 10 recipes'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Sort, Newest')), findsOneWidget);
  });

  testWidgets('popular: by ratings, no filters, no sort', (tester) async {
    await pumpBrowse(
      tester,
      _ready(),
      router: browseRouter(initial: '/recipes/popular'),
    );
    expect(find.text('Popular this week'), findsOneWidget);
    expect(find.text('By ratings'), findsOneWidget);
    expect(find.byType(AppFilterChip), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Sort')), findsNothing);
  });

  testWidgets('offline status on a page', (tester) async {
    await pumpBrowse(
      tester,
      _ready(offline: true),
      router: browseRouter(initial: '/recipes/all'),
    );
    expect(find.text('Offline. You\'re seeing saved recipes.'), findsOneWidget);
  });

  testWidgets('pages set Avo\'s context to recipes', (tester) async {
    final container = ProviderContainer(overrides: _ready());
    addTearDown(container.dispose);
    await pumpBrowse(
      tester,
      const [],
      container: container,
      router: browseRouter(initial: '/recipes/all'),
    );
    expect(container.read(avoScreenContextProvider)?.screen, 'recipes');
  });
}
