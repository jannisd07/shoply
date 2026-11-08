import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

import '../../layout/layout_matrix.dart';

String _en(String key, [Map<String, String>? params]) =>
    AppTranslations.get(key, 'en', params: params);

final _at = DateTime(2026, 1, 1);

final _recipe = Recipe(
  id: 'r1',
  name: 'Roast vegetables',
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients: const [
    Ingredient(name: 'Kartoffeln', amount: 500, unit: 'g'),
    Ingredient(name: 'Olivenöl', amount: 2, unit: 'EL'),
    Ingredient(name: 'Milch', amount: 200, unit: 'ml'),
    Ingredient(name: 'Salz', amount: 0, unit: ''),
    Ingredient(name: 'Zucchini', amount: 1, unit: ''),
    Ingredient(name: 'Olivenöl', amount: 1, unit: 'EL'),
  ],
  instructions: const ['Bake.'],
  authorId: 'a1',
  authorName: 'Mara',
  createdAt: _at,
);

ShoppingListModel _list(String id, String name, {int open = 0}) =>
    ShoppingListModel(
      id: id,
      name: name,
      ownerId: 'u1',
      createdAt: _at,
      updatedAt: _at,
      uncheckedCount: open,
    );

ShoppingItemModel _item(String name) => ShoppingItemModel(
  id: 'i-$name',
  listId: 'l1',
  name: name,
  quantity: 1,
  unit: 'bottle',
  createdAt: _at,
  updatedAt: _at,
);

class _Repo extends Fake implements ItemRepository {
  final batches = <(String, List<NewItem>)>[];
  final undone = <String>[];
  Object? error;

  @override
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    final e = error;
    if (e != null) throw e;
    batches.add((listId, items));
    return AddItemsResult(token: 't${batches.length}', items: const []);
  }

  @override
  Future<void> undoAddItems(String token) async => undone.add(token);
}

/// Records new lists instead of creating them.
class _Actions extends RecipeDetailActions {
  final created = <String>[];
  final refreshed = <String>[];

  @override
  Future<ShoppingListModel> createList(
    ProviderContainer container,
    String name,
  ) async {
    created.add(name);
    return _list('new', name);
  }

  @override
  void refreshList(ProviderContainer container, String listId) =>
      refreshed.add(listId);
}

class _Setup {
  _Setup({
    this.lists = const [],
    this.onList = const [],
    this.allergies = const [],
  });

  final List<ShoppingListModel> lists;
  final List<String> onList;
  final List<String> allergies;
  final repo = _Repo();
  final actions = _Actions();

  List<Override> get overrides => [
    currentUserProvider.overrideWith(
      (ref) async => UserModel(
        id: 'u1',
        email: 'a@b.c',
        allergies: allergies,
        createdAt: _at,
        updatedAt: _at,
      ),
    ),
    itemRepositoryProvider.overrideWithValue(repo),
    recipeDetailActionsProvider.overrideWithValue(actions),
    recipeTargetListsProvider.overrideWithValue(lists),
    recipeTargetListProvider.overrideWith(
      (ref, id) => lists.isEmpty ? null : lists.first,
    ),
    recipeListOpenItemsProvider.overrideWith(
      (ref, id) => [for (final n in onList) _item(n)],
    ),
  ];
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _Setup setup, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: setup.overrides,
      child: layoutHarness(
        layout,
        RecipeToListScreen(recipe: _recipe, servings: 2),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// A host page with a button that runs [openIngredientsToList].
Future<void> _pumpHost(WidgetTester tester, _Setup setup) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: setup.overrides,
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  openIngredientsToList(context, recipe: _recipe, servings: 2),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('preselection: staples and items on the list stay off', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _Setup(
        lists: [_list('l1', 'Weekly shop', open: 9)],
        onList: ['Olivenöl'],
      ),
    );
    // Olive oil appears once with the sum of both mentions.
    expect(find.textContaining('Olivenöl'), findsOneWidget);
    expect(find.text('3 EL'), findsOneWidget);
    expect(
      find.text(
        _en('recipe_detail_on_list_quantity', {
          'list': 'Weekly shop',
          'quantity': '1 btl.',
        }),
      ),
      findsOneWidget,
    );
    expect(find.text(_en('recipe_detail_tolist_staple')), findsOneWidget);
    // Kartoffeln, Milch, Zucchini are on; Olivenöl and Salz off.
    expect(
      find.text(
        _en('recipe_detail_tolist_count', {'selected': '3', 'total': '5'}),
      ),
      findsOneWidget,
    );
    expect(
      find.text(_en('recipe_detail_tolist_add_many', {'count': '3'})),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row toggles it, no ingredient disables the button', (
    tester,
  ) async {
    await _pumpScreen(tester, _Setup(lists: [_list('l1', 'Weekly shop')]));
    for (final name in ['Kartoffeln', 'Milch', 'Zucchini']) {
      await tester.tap(find.textContaining(name).first);
      await tester.pump();
    }
    expect(find.text(_en('recipe_detail_tolist_none')), findsOneWidget);
    // Olive oil is a basic people have at home, but can be ticked.
    await tester.tap(find.textContaining('Olivenöl').first);
    await tester.pump();
    expect(find.text(_en('recipe_detail_tolist_add_one')), findsOneWidget);
  });

  testWidgets('servings scale the amounts', (tester) async {
    await _pumpScreen(tester, _Setup(lists: [_list('l1', 'Weekly shop')]));
    await tester.tap(find.bySemanticsLabel(_en('common_increase')).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('750 g'), findsOneWidget);
  });

  testWidgets('the list menu shows every list with its open count', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _Setup(
        lists: [
          _list('l1', 'Weekly shop', open: 9),
          _list('l2', 'Party', open: 2),
        ],
      ),
    );
    await tester.tap(find.text('Weekly shop'));
    await tester.pumpAndSettle();
    expect(
      find.text(_en('recipe_detail_tolist_open_count', {'count': '2'})),
      findsOneWidget,
    );
    await tester.tap(find.text('Party'));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsOneWidget);
  });

  testWidgets('adds one batch with undo and remembers the list', (
    tester,
  ) async {
    final setup = _Setup(lists: [_list('l1', 'Weekly shop')]);
    await _pumpHost(tester, setup);
    await tester.tap(
      find.text(_en('recipe_detail_tolist_add_many', {'count': '3'})),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecipeToListScreen), findsNothing);
    final (listId, items) = setup.repo.batches.single;
    expect(listId, 'l1');
    expect(
      [for (final i in items) i.name],
      ['Kartoffeln', 'Milch', 'Zucchini'],
    );
    expect(setup.actions.refreshed, ['l1']);
    expect(items.first.quantity, 500);
    expect(items.first.unit, 'g');
    // Zucchini: one piece, no unit.
    expect(items.last.unit, isNull);
    expect(
      find.text(
        _en('recipe_detail_tolist_added_many', {
          'count': '3',
          'list': 'Weekly shop',
        }),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(_en('common_undo')));
    await tester.pump();
    await tester.pump();
    expect(setup.repo.undone, ['t1']);
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );
    expect(container.read(recipeChosenListProvider('r1')), 'l1');
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('without lists a new list "Shopping" is created', (tester) async {
    final setup = _Setup();
    await _pumpHost(tester, setup);
    expect(
      find.text(
        _en('recipe_detail_tolist_new_list_value', {
          'name': _en('recipe_detail_tolist_default_name'),
        }),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.text(_en('recipe_detail_tolist_add_many', {'count': '3'})),
    );
    await tester.pumpAndSettle();
    expect(setup.actions.created, ['Shopping']);
    expect(setup.repo.batches.single.$1, 'new');
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('a failed add says so and offers a retry', (tester) async {
    final setup = _Setup(lists: [_list('l1', 'Weekly shop')])
      ..repo.error = Exception('offline');
    await _pumpHost(tester, setup);
    await tester.tap(
      find.text(_en('recipe_detail_tolist_add_many', {'count': '3'})),
    );
    await tester.pumpAndSettle();
    expect(find.text(_en('recipe_detail_tolist_failed')), findsOneWidget);
    setup.repo.error = null;
    await tester.tap(find.text(_en('common_try_again')));
    await tester.pumpAndSettle();
    expect(setup.repo.batches, hasLength(1));
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('adapted for the person, with the reason', (tester) async {
    await _pumpScreen(
      tester,
      _Setup(lists: [_list('l1', 'Weekly shop')], allergies: ['lactose']),
    );
    expect(find.textContaining('Hafermilch'), findsOneWidget);
    expect(
      find.textContaining(
        _en('recipe_detail_instead_allergen', {
          'name': 'Milch',
          'reason': 'lactose',
        }),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(_en('recipe_detail_variant_original')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Hafermilch'), findsNothing);
  });

  layoutMatrix(
    'RecipeToListScreen',
    (context) => ProviderScope(
      overrides: _Setup(
        lists: [_list('l1', 'Weekly shop', open: 9)],
        onList: ['Olivenöl'],
        allergies: ['lactose'],
      ).overrides,
      child: SizedBox(
        height: kLayoutHeight,
        child: RecipeToListScreen(recipe: _recipe, servings: 2),
      ),
    ),
  );
}
