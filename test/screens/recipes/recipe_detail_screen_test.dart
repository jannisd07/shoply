import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_detail_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

final _at = DateTime(2026, 1, 1);

Recipe _recipe({
  String id = 'r1',
  String authorId = 'a1',
  String description = 'One tray, little washing up.',
  List<Ingredient>? ingredients,
  List<String>? steps,
  NutritionInfo? nutrition,
  int ratingCount = 128,
  String? sourceUrl,
}) => Recipe(
  id: id,
  name: 'Roast vegetables with feta',
  description: description,
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients:
      ingredients ??
      const [
        Ingredient(name: 'Kartoffeln', amount: 500, unit: 'g'),
        Ingredient(name: 'Milch', amount: 200, unit: 'ml'),
        Ingredient(name: 'Erdnüsse', amount: 50, unit: 'g'),
        Ingredient(name: 'Salz', amount: 0, unit: ''),
      ],
  instructions:
      steps ??
      const ['Heat the oven.', 'Pour the Milch over it.', 'Bake 25 minutes.'],
  authorId: authorId,
  authorName: 'Mara Köhler',
  createdAt: _at,
  averageRating: 4.7,
  ratingCount: ratingCount,
  labels: const ['vegetarian'],
  nutrition:
      nutrition ??
      const NutritionInfo(calories: 540, proteinG: 18, carbsG: 52, fatG: 29),
  sourceUrl: sourceUrl,
  sourceName: sourceUrl == null ? null : 'wikibooks',
);

UserModel _user({
  String id = 'u1',
  List<String> allergies = const [],
  List<String> diets = const [],
}) => UserModel(
  id: id,
  email: 'a@b.c',
  allergies: allergies,
  dietPreferences: diets,
  createdAt: _at,
  updatedAt: _at,
);

final _list = ShoppingListModel(
  id: 'l1',
  name: 'Weekly shop',
  ownerId: 'u1',
  createdAt: _at,
  updatedAt: _at,
);

ShoppingItemModel _item(String name) => ShoppingItemModel(
  id: 'i-$name',
  listId: 'l1',
  name: name,
  quantity: 1,
  createdAt: _at,
  updatedAt: _at,
);

/// Records every action; [load] answers with [loadResult] or [loadError].
class _Actions extends RecipeDetailActions {
  _Actions({this.loadError, this.loadGate});

  Recipe? loadResult;
  Object? loadError;
  Completer<void>? loadGate;
  Object? rateError;
  final calls = <String>[];
  final cooked = <Recipe>[];
  final toList = <({String id, int servings, bool adapted})>[];
  int loads = 0;

  @override
  Future<Recipe> load(String recipeId) async {
    loads++;
    final gate = loadGate;
    if (gate != null) await gate.future;
    final error = loadError;
    if (error != null) throw error;
    return loadResult ?? _recipe(id: recipeId);
  }

  @override
  Recipe? known(WidgetRef ref, String recipeId) => null;

  @override
  Future<Recipe?> onDevice(String recipeId) async => null;

  @override
  Future<void> trackView(String recipeId) async => calls.add('view');

  @override
  Future<void> rate(String recipeId, int stars) async {
    calls.add('rate:$stars');
    final error = rateError;
    if (error != null) throw error;
  }

  @override
  Future<void> delete(String recipeId) async => calls.add('delete:$recipeId');

  @override
  Future<void> toggleSave(WidgetRef ref, String recipeId) async =>
      calls.add('save');

  @override
  Future<void> share(BuildContext context, Recipe recipe, Rect? origin) async =>
      calls.add('share');

  @override
  Future<bool> edit(BuildContext context, String recipeId) async {
    calls.add('edit');
    return false;
  }

  @override
  void openAuthor(BuildContext context, Recipe recipe) => calls.add('author');

  @override
  Future<void> cook(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    int servings,
  ) async {
    calls.add('cook:$servings');
    cooked.add(recipe);
  }

  @override
  Future<void> openToList(
    BuildContext context,
    Recipe recipe,
    int servings, {
    required bool adapted,
  }) async {
    toList.add((id: recipe.id, servings: servings, adapted: adapted));
  }

  @override
  Future<void> logRecipe(BuildContext context, Recipe recipe) async =>
      calls.add('log');

  @override
  Future<void> openSource(String url) async => calls.add('source');

  @override
  void back(BuildContext context) => calls.add('back');

  @override
  void openRecipes(BuildContext context) => calls.add('recipes');

  @override
  void refreshRecipes(ProviderContainer container) => calls.add('refresh');
}

class _Setup {
  _Setup({
    _Actions? actions,
    this.user,
    this.saved = false,
    this.offline = false,
    this.calories = false,
    this.onList = const [],
    this.resumePage,
    this.autoAdapt = true,
  }) : actions = actions ?? _Actions();

  /// "Rezepte automatisch anpassen".
  final bool autoAdapt;

  /// Saved cooking page (1 = step 1); null without progress.
  final int? resumePage;

  final _Actions actions;
  final UserModel? user;
  final bool saved;
  final bool offline;
  final bool calories;
  final List<String> onList;

  List<Override> get overrides => [
    recipeDetailActionsProvider.overrideWithValue(actions),
    recipeAutoAdaptProvider.overrideWith(
      (ref) => RecipeAutoAdaptNotifier(null)..set(autoAdapt),
    ),
    currentUserProvider.overrideWith((ref) async => user),
    isRecipeSavedProvider.overrideWith((ref, id) => saved),
    isOfflineProvider.overrideWithValue(offline),
    offersAvailableProvider.overrideWithValue(false),
    moduleEnabledProvider.overrideWith(
      (ref, m) => m == AppModule.calories && calories,
    ),
    recipeTargetListsProvider.overrideWithValue([_list]),
    recipeTargetListProvider.overrideWith((ref, id) => _list),
    recipeListOpenItemsProvider.overrideWith(
      (ref, id) => [for (final n in onList) _item(n)],
    ),
    cookingProgressProvider.overrideWith(
      (ref, id) async => resumePage == null
          ? null
          : CookingProgress(
              recipeId: id,
              page: resumePage!,
              servings: 2,
              savedAt: _at,
            ),
    ),
  ];
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Setup setup, {
  Recipe? initial,
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  if (initial != null) setup.actions.loadResult ??= initial;
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: setup.overrides,
      child: layoutHarness(
        layout,
        RecipeDetailScreen(recipeId: 'r1', initialRecipe: initial),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(RecipeDetailScreen)),
  );
}

Finder _icon(AvoIconData icon) =>
    find.byWidgetPredicate((w) => w is AvoIcon && identical(w.icon, icon));

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('content', () {
    testWidgets('the recipe from the card shows at once', (tester) async {
      final setup = _Setup(user: _user());
      await _pump(tester, setup, initial: _recipe());
      expect(find.text('Roast vegetables with feta'), findsWidgets);
      expect(find.text('35 min · ★ 4.7 (128) · vegetarian'), findsOneWidget);
      expect(
        find.text(_en('recipe_detail_by', {'name': 'Mara Köhler'})),
        findsOneWidget,
      );
      expect(find.textContaining('Kartoffeln'), findsOneWidget);
      expect(find.text('500 g'), findsOneWidget);
      // Salt without an amount: no "0".
      expect(find.text('0'), findsNothing);
      expect(setup.actions.loads, 1);
      expect(setup.actions.calls, contains('view'));
    });

    testWidgets('fewer than three ratings: no average', (tester) async {
      await _pump(
        tester,
        _Setup(user: _user()),
        initial: _recipe(ratingCount: 2),
      );
      expect(find.text('35 min · vegetarian'), findsOneWidget);
    });

    testWidgets('own recipes are not counted as a view', (tester) async {
      final setup = _Setup(user: _user(id: 'a1'));
      await _pump(tester, setup, initial: _recipe());
      expect(setup.actions.calls, isNot(contains('view')));
    });

    testWidgets('servings stepper scales the amounts', (tester) async {
      await _pump(tester, _Setup(user: _user()), initial: _recipe());
      await tester.tap(find.bySemanticsLabel(_en('common_increase')).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('750 g'), findsOneWidget);
    });

    testWidgets('author line opens the creator', (tester) async {
      final setup = _Setup(user: _user());
      await _pump(tester, setup, initial: _recipe());
      await tester.tap(
        find.text(_en('recipe_detail_by', {'name': 'Mara Köhler'})),
      );
      expect(setup.actions.calls, contains('author'));
    });

    testWidgets('an ingredient already on the list says so', (tester) async {
      await _pump(
        tester,
        _Setup(user: _user(), onList: ['Kartoffeln']),
        initial: _recipe(),
      );
      expect(
        find.text(_en('recipe_detail_on_list', {'list': 'Weekly shop'})),
        findsOneWidget,
      );
    });

    testWidgets('imported recipes show the source with the licence', (
      tester,
    ) async {
      final setup = _Setup(user: _user());
      await _pump(
        tester,
        setup,
        initial: _recipe(sourceUrl: 'https://en.wikibooks.org/wiki/x'),
      );
      expect(
        find.text(
          _en('recipe_detail_from_source', {
            'source': _en('recipe_detail_source_wikibooks'),
          }),
        ),
        findsOneWidget,
      );
      final footer = find.bySemanticsLabel(RegExp('CC BY-SA 4.0'));
      await _scrollTo(tester, footer);
      await tester.tap(footer);
      expect(setup.actions.calls, contains('source'));
    });
  });

  group('allergies first (Konzept 13 §2.3)', () {
    testWidgets('notice names allergen, substitute and the footnote', (
      tester,
    ) async {
      await _pump(
        tester,
        _Setup(user: _user(allergies: ['lactose', 'peanuts'])),
        initial: _recipe(),
      );
      expect(
        find.textContaining(
          _en('recipe_detail_contains', {
            'allergen': 'peanut',
            'ingredients': 'Erdnüsse',
          }),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          _en('recipe_detail_no_safe_substitute', {'allergen': 'peanut'}),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en('recipe_detail_substitute_suggested')),
        findsOneWidget,
      );
      expect(find.text(_en('recipe_detail_allergy_footnote')), findsOneWidget);
      // Adapted by default: oat milk instead of milk, with the reason.
      expect(find.textContaining('Hafermilch'), findsOneWidget);
      expect(
        find.text(
          _en('recipe_detail_instead_allergen', {
            'name': 'Milch',
            'reason': 'lactose',
          }),
        ),
        findsOneWidget,
      );
      // The step names the substitute too.
      await _scrollTo(tester, find.text('Pour the Hafermilch over it.'));
      expect(find.text('Pour the Hafermilch over it.'), findsOneWidget);
    });

    testWidgets('"Original" brings the original back, warnings stay', (
      tester,
    ) async {
      await _pump(
        tester,
        _Setup(user: _user(allergies: ['lactose'])),
        initial: _recipe(),
      );
      await tester.tap(find.text(_en('recipe_detail_variant_original')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining(RegExp(r'^Milch')), findsOneWidget);
      expect(find.textContaining('Hafermilch'), findsNothing);
      expect(
        find.textContaining(_en('recipe_detail_substitute_suggested')),
        findsOneWidget,
      );
      await _scrollTo(tester, find.text('Pour the Milch over it.'));
      expect(find.text('Pour the Milch over it.'), findsOneWidget);
    });

    testWidgets('"Rezepte automatisch anpassen" off: opens on "Original"', (
      tester,
    ) async {
      await _pump(
        tester,
        _Setup(user: _user(allergies: ['lactose']), autoAdapt: false),
        initial: _recipe(),
      );
      expect(find.textContaining(RegExp(r'^Milch')), findsOneWidget);
      expect(find.textContaining('Hafermilch'), findsNothing);
      // The warning stays, and the switch still offers the adapted version.
      expect(
        find.textContaining(_en('recipe_detail_substitute_suggested')),
        findsOneWidget,
      );
      expect(find.text(_en('recipe_detail_variant_original')), findsOneWidget);
    });

    testWidgets('no profile: no notice, no segment', (tester) async {
      await _pump(tester, _Setup(user: _user()), initial: _recipe());
      expect(find.text(_en('recipe_detail_allergy_footnote')), findsNothing);
      expect(find.text(_en('recipe_detail_variant_original')), findsNothing);
    });

    testWidgets('cooking gets the adapted recipe', (tester) async {
      final setup = _Setup(user: _user(allergies: ['lactose']));
      await _pump(tester, setup, initial: _recipe());
      await tester.tap(find.text(_en('recipe_detail_cook')));
      await tester.pump();
      expect(setup.actions.calls, contains('cook:2'));
      expect(
        setup.actions.cooked.single.ingredients.map((i) => i.name),
        contains('Hafermilch'),
      );
    });
  });

  group('actions', () {
    testWidgets('toolbar: back, save, share', (tester) async {
      final setup = _Setup(user: _user());
      await _pump(tester, setup, initial: _recipe());
      await tester.tap(find.bySemanticsLabel(_en('back')));
      await tester.tap(find.bySemanticsLabel(_en('recipe_detail_save')));
      await tester.tap(find.bySemanticsLabel(_en('recipe_detail_share')));
      expect(setup.actions.calls, containsAll(['back', 'save', 'share']));
    });

    testWidgets('saved recipes offer "Remove from saved"', (tester) async {
      await _pump(
        tester,
        _Setup(user: _user(), saved: true),
        initial: _recipe(),
      );
      expect(
        find.bySemanticsLabel(_en('recipe_detail_unsave')),
        findsOneWidget,
      );
    });

    testWidgets('"Add ingredients to list" opens with servings', (
      tester,
    ) async {
      final setup = _Setup(user: _user());
      await _pump(tester, setup, initial: _recipe());
      await tester.tap(find.text(_en('recipe_detail_to_list')));
      await tester.pump();
      expect(setup.actions.toList.single, (
        id: 'r1',
        servings: 2,
        adapted: true,
      ));
    });

    testWidgets('cooking progress: "Continue: step 3"', (tester) async {
      final setup = _Setup(user: _user(), resumePage: 3);
      await _pump(tester, setup, initial: _recipe());
      await tester.pump();
      final label = _en('recipe_detail_cook_continue', {'n': '3'});
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(setup.actions.calls, contains('cook:2'));
    });

    testWidgets('own recipe: edit capsule, delete after confirming', (
      tester,
    ) async {
      final setup = _Setup(user: _user(id: 'a1'));
      await _pump(tester, setup, initial: _recipe());
      expect(find.bySemanticsLabel(_en('recipe_detail_save')), findsNothing);
      await tester.tap(find.text(_en('recipe_detail_edit')));
      await tester.pump();
      expect(setup.actions.calls, contains('edit'));
      // No rating of the own recipe.
      expect(find.text(_en('recipe_detail_your_rating')), findsNothing);

      await tester.tap(_icon(AvoIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en('recipe_detail_delete')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          _en('recipe_detail_delete_title', {
            'name': 'Roast vegetables with feta',
          }),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(_en('recipe_detail_delete')).last);
      await tester.pumpAndSettle();
      expect(setup.actions.calls, containsAll(['back', 'delete:r1']));
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('menu: report for others, diary with the calories module', (
      tester,
    ) async {
      final setup = _Setup(user: _user(), calories: true);
      await _pump(tester, setup, initial: _recipe());
      await tester.tap(_icon(AvoIcons.more));
      await tester.pumpAndSettle();
      expect(find.text(_en('recipe_detail_report')), findsOneWidget);
      expect(find.text(_en('recipe_detail_delete')), findsNothing);
      await tester.tap(find.text(_en('recipe_detail_log')).last);
      await tester.pumpAndSettle();
      expect(setup.actions.calls, contains('log'));
    });

    testWidgets('rating is optimistic and rolls back on failure', (
      tester,
    ) async {
      final setup = _Setup(user: _user())..actions.rateError = Exception('x');
      await _pump(tester, setup, initial: _recipe());
      final row = find.bySemanticsLabel(_en('recipe_detail_your_rating'));
      await _scrollTo(tester, row);
      final rect = tester.getRect(row);
      // Fourth star: 4 × 44 pt from the right end of the five stars.
      await tester.tapAt(Offset(rect.right - 16 - 44 * 1.5, rect.center.dy));
      await tester.pump();
      expect(setup.actions.calls, contains('rate:4'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_en('recipe_detail_rating_failed')), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('sets the Avo context to the recipe', (tester) async {
      final container = await _pump(
        tester,
        _Setup(user: _user()),
        initial: _recipe(),
      );
      expect(container.read(avoScreenContextProvider)?.screen, 'recipe');
    });
  });

  group('states', () {
    testWidgets('nothing known yet: calm placeholders, then the recipe', (
      tester,
    ) async {
      final gate = Completer<void>();
      final setup = _Setup(
        user: _user(),
        actions: _Actions(loadGate: gate),
      );
      await _pump(tester, setup);
      expect(
        find.bySemanticsLabel(_en('recipe_detail_loading')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Roast vegetables with feta'), findsWidgets);
    });

    testWidgets('deleted recipe: "no longer available", to the recipes', (
      tester,
    ) async {
      final setup = _Setup(
        user: _user(),
        actions: _Actions(loadError: Exception('Recipe not found with ID: r1')),
      );
      await _pump(tester, setup, initial: _recipe());
      expect(find.text(_en('recipe_detail_gone_title')), findsOneWidget);
      await tester.tap(find.text(_en('recipe_detail_gone_action')));
      expect(setup.actions.calls, contains('recipes'));
    });

    testWidgets('load error without a copy: retry', (tester) async {
      final actions = _Actions(loadError: Exception('network'));
      await _pump(tester, _Setup(user: _user(), actions: actions));
      expect(find.text(_en('recipe_detail_failed_title')), findsOneWidget);
      actions.loadError = null;
      await tester.tap(find.text(_en('common_try_again')));
      await tester.pump();
      await tester.pump();
      expect(actions.loads, 2);
      expect(find.text('Roast vegetables with feta'), findsWidgets);
    });

    testWidgets('a failed refresh keeps the shown recipe', (tester) async {
      await _pump(
        tester,
        _Setup(
          user: _user(),
          actions: _Actions(loadError: Exception('x')),
        ),
        initial: _recipe(),
      );
      expect(find.text('Roast vegetables with feta'), findsWidgets);
      expect(find.text(_en('recipe_detail_failed_title')), findsNothing);
    });

    testWidgets('offline: saved version', (tester) async {
      await _pump(
        tester,
        _Setup(user: _user(), offline: true),
        initial: _recipe(),
      );
      expect(find.text(_en('recipe_detail_offline')), findsOneWidget);
    });
  });

  testWidgets('"?action=to-list" starts "Zutaten auf die Liste" once', (
    tester,
  ) async {
    final setup = _Setup(user: _user());
    final router = GoRouter(
      initialLocation: '/recipes/r1?action=to-list',
      routes: [
        GoRoute(
          path: '/recipes/:id',
          builder: (context, state) => RecipeDetailScreen(
            recipeId: state.pathParameters['id']!,
            initialRecipe: _recipe(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: setup.overrides,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AvoDesignScope(child: child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(setup.actions.toList, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(setup.actions.toList, hasLength(1));
  });

  layoutMatrix(
    'RecipeDetailScreen',
    (context) => ProviderScope(
      overrides: _Setup(
        user: _user(allergies: ['lactose', 'peanuts'], diets: ['vegetarian']),
        calories: true,
        onList: const ['Kartoffeln'],
      ).overrides,
      child: SizedBox(
        height: kLayoutHeight,
        child: RecipeDetailScreen(
          recipeId: 'r1',
          initialRecipe: _recipe(sourceUrl: 'https://en.wikibooks.org/wiki/x'),
        ),
      ),
    ),
  );
}
