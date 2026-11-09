// A11 Teil R: the recipe screens as a whole in the layout matrix
// (a11-pruefplan §1, §2.1). Each screen is fed through its providers, no
// Supabase: content, empty, loading, error and offline, where the screen
// has that state.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/all_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/category_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/my_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_author_page.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_follow.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

import '../../layout/layout_matrix.dart';
import 'recipes_browse_fakes.dart';
import 'recipes_browse_harness.dart';

/// The default text size and the largest at the narrowest and a common
/// width, for every state besides "content".
final _stateCases = [
  for (final w in [320.0, 390.0])
    for (final s in [1.0, 3.1]) LayoutCase(width: w, scale: s),
];

/// One case for the tap-target sample (§2.3).
const _tapCases = [LayoutCase(width: 390, scale: 1)];

/// A screen with its providers at device height.
Widget _screen(List<Override> overrides, Widget screen) => ProviderScope(
  overrides: overrides,
  child: SizedBox(height: kLayoutHeight, child: screen),
);

/// Checks that the screen really shows [state], not just something that
/// fits: an empty state, a skeleton, a status row (error, offline).
Future<void> Function(WidgetTester) _shows(String state) => (tester) async {
  final empty = find.byType(EmptyState);
  final status = find.byType(StatusRow);
  final loading =
      find.byType(SkeletonSection).evaluate().isNotEmpty ||
      find.bySemanticsLabel('Loading...').evaluate().isNotEmpty;
  switch (state) {
    case 'content':
      expect(empty, findsNothing, reason: 'content without empty state');
      expect(loading, isFalse, reason: 'content is not loading');
    case 'empty':
      expect(empty, findsWidgets, reason: 'empty state');
    case 'loading':
      expect(loading, isTrue, reason: 'skeleton while loading');
    case 'error' || 'errorNoCache' || 'offline':
      expect(status, findsWidgets, reason: '$state status row');
  }
};

// ------------------------------------------------------------------ browse

/// The browse states of the tab, "Alle" and a category.
enum _Browse { content, empty, loading, error, errorNoCache, offline }

List<Override> _browse(_Browse state, {bool planOn = false}) {
  final cat = browseCatalogue();
  return switch (state) {
    _Browse.content => browseOverrides(seed: cat, fresh: cat, planOn: planOn),
    _Browse.empty => browseOverrides(seed: const [], fresh: const []),
    _Browse.loading => browseOverrides(),
    _Browse.error => browseOverrides(seed: cat, freshFails: true),
    _Browse.errorNoCache => browseOverrides(freshFails: true),
    _Browse.offline => browseOverrides(seed: cat, offline: true),
  };
}

void _browseMatrix(String name, Widget Function() screen) {
  layoutMatrix(
    '$name (content)',
    (context) => _screen(_browse(_Browse.content), screen()),
    afterPump: _shows('content'),
  );
  layoutMatrix(
    '$name (content, tap targets)',
    (context) => _screen(_browse(_Browse.content), screen()),
    cases: _tapCases,
    checkTapTargets: true,
  );
  for (final state in _Browse.values.skip(1)) {
    layoutMatrix(
      '$name (${state.name})',
      (context) => _screen(_browse(state), screen()),
      cases: _stateCases,
      afterPump: _shows(state.name),
    );
  }
}

// ----------------------------------------------------------------- library

final _now = DateTime.now();

Recipe _recipe(
  String id,
  String name, {
  String author = 'mara',
  String authorName = 'Mara Köhler',
  double rating = 0,
  int ratings = 0,
  int daysAgo = 3,
}) => Recipe(
  id: id,
  name: name,
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients: const [Ingredient(name: 'Feta', amount: 200, unit: 'g')],
  instructions: const ['Backen'],
  authorId: author,
  authorName: authorName,
  createdAt: _now.subtract(Duration(days: daysAgo)),
  averageRating: rating,
  ratingCount: ratings,
);

final _catalog = [
  _recipe('1', 'Ofengemüse mit Feta', rating: 4.6, ratings: 23),
  _recipe(
    '2',
    'Kürbis-Risotto mit gerösteten Kernen und Salbeibutter',
    rating: 4.8,
    ratings: 9,
    daysAgo: 14,
  ),
  _recipe('3', 'Linsen-Dal', author: 'deniz', authorName: 'Deniz Aydın'),
  _recipe(
    '4',
    'Pausenbrot',
    author: 'me',
    authorName: 'Ich',
    rating: 4.1,
    ratings: 3,
  ),
  _recipe(
    '5',
    'Zitronen-Hähnchen aus dem Ofen',
    author: 'me',
    authorName: 'Ich',
    daysAgo: 40,
  ),
  _recipe(
    '6',
    'Gurkensalat',
    author: 'sophie',
    authorName: 'Sophie Brandt-Wellershoff von der Heide',
  ),
];

final _drafts = [
  RecipeDraft(
    id: 'd1',
    name: 'Kürbis-Risotto',
    description: 'Cremig',
    prepTimeMinutes: 10,
    cookTimeMinutes: 30,
    defaultServings: 2,
    ingredients: [DraftIngredient(name: 'Reis', amount: '200', unit: 'g')],
    instructions: const ['Rühren'],
    createdAt: _now,
    updatedAt: _now.subtract(const Duration(hours: 2)),
  ),
  RecipeDraft(
    id: 'd2',
    name: '',
    description: '',
    ingredients: const [],
    instructions: const [],
    createdAt: _now,
    updatedAt: _now.subtract(const Duration(days: 3)),
  ),
];

/// How the fake actions answer a load.
enum _Load { ready, never, fails }

class _FakeBackend implements CreatorFollowBackend {
  @override
  Future<Set<String>> fetch(String userId) async => const {};
  @override
  Future<void> follow(String userId, String creatorId) async {}
  @override
  Future<void> unfollow(String userId, String creatorId) async {}
}

class _FakeActions extends RecipeLibraryActions {
  _FakeActions(super.ref, {required this.load, this.mine, this.drafts_});

  final _Load load;
  final List<Recipe>? mine;
  final List<RecipeDraft>? drafts_;

  Future<T> _answer<T>(T value) => switch (load) {
    _Load.ready => Future.value(value),
    _Load.never => Completer<T>().future,
    _Load.fails => Future<T>.error(Exception('offline')),
  };

  @override
  Future<List<Recipe>> myRecipes() => _answer(mine ?? const []);

  @override
  Future<List<Recipe>> recipesBy(String authorId) => _answer([
    for (final r in mine ?? _catalog)
      if (r.authorId == authorId) r,
  ]);

  @override
  Future<List<RecipeDraft>> drafts() => _answer(drafts_ ?? const []);

  @override
  void catalogChanged() {}

  @override
  Future<void> reloadCatalog() async {}

  @override
  Future<void> reloadSaved() async {}

  @override
  Future<bool> toggleSaved(String recipeId) async => true;

  @override
  Future<void> deleteDraft(RecipeDraft draft) async {}

  @override
  Future<void> deleteRecipe(String recipeId) async {}

  @override
  Future<void> shareRecipe(Recipe recipe, {Rect? origin}) async {}
}

List<Override> _library({
  List<Recipe>? catalog,
  bool catalogFailed = false,
  bool offline = false,
  LibrarySaved saved = const LibrarySaved(),
  _Load load = _Load.ready,
  List<Recipe>? mine,
  List<RecipeDraft>? drafts,
}) => [
  libraryCatalogProvider.overrideWithValue(catalog),
  libraryCatalogFailedProvider.overrideWithValue(catalogFailed),
  libraryAllergiesProvider.overrideWithValue(const ['Erdnüsse']),
  librarySavedProvider.overrideWithValue(saved),
  isOfflineProvider.overrideWithValue(offline),
  authUserIdProvider.overrideWithValue('me'),
  creatorFollowBackendProvider.overrideWithValue(_FakeBackend()),
  recipeLibraryActionsProvider.overrideWith(
    (ref) => _FakeActions(ref, load: load, mine: mine, drafts_: drafts),
  ),
];

/// Content with the full matrix, the other states at [_stateCases].
void _libraryMatrix(
  String name,
  Widget Function() screen, {
  required List<Override> content,
  required Map<String, List<Override>> states,
  Map<String, String> shows = const {},
}) {
  layoutMatrix(
    '$name (content)',
    (context) => _screen(content, screen()),
    afterPump: _shows('content'),
  );
  layoutMatrix(
    '$name (content, tap targets)',
    (context) => _screen(content, screen()),
    cases: _tapCases,
    checkTapTargets: true,
  );
  for (final MapEntry(key: state, value: overrides) in states.entries) {
    layoutMatrix(
      '$name ($state)',
      (context) => _screen(overrides, screen()),
      cases: _stateCases,
      afterPump: _shows(shows[state] ?? state),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // -------------------------------------------------------------- browse

  _browseMatrix('RecipesScreen', () => const RecipesScreen());
  layoutMatrix(
    'RecipesScreen (meal plan module on)',
    (context) =>
        _screen(_browse(_Browse.content, planOn: true), const RecipesScreen()),
    cases: _stateCases,
  );
  layoutMatrix(
    'RecipesScreen (search)',
    (context) => _screen(
      _browse(_Browse.content),
      const RecipesScreen(initialQuery: 'Paprika'),
    ),
    cases: _stateCases,
  );

  _browseMatrix('AllRecipesScreen', () => const AllRecipesScreen());
  layoutMatrix(
    'AllRecipesScreen (popular)',
    (context) => _screen(
      _browse(_Browse.content),
      const AllRecipesScreen(popularOnly: true),
    ),
    cases: _stateCases,
  );

  _browseMatrix(
    'CategoryRecipesScreen',
    () => const CategoryRecipesScreen(categoryId: 'vegetarian'),
  );

  // ------------------------------------------------------------- library

  _libraryMatrix(
    'MyRecipesScreen',
    () => const MyRecipesScreen(),
    content: _library(
      catalog: _catalog,
      mine: [_catalog[3], _catalog[4]],
      drafts: _drafts,
    ),
    states: {
      'empty': _library(catalog: _catalog, mine: const []),
      'loading': _library(load: _Load.never),
      'error': _library(load: _Load.fails),
      'offline': _library(catalog: _catalog, offline: true),
    },
  );

  _libraryMatrix(
    'RecipeDraftsScreen',
    () => const RecipeDraftsScreen(),
    content: _library(drafts: _drafts),
    states: {
      'empty': _library(drafts: const []),
      'loading': _library(load: _Load.never),
      'error': _library(load: _Load.fails),
    },
    // A failed read says so with "Erneut versuchen", not "no drafts"
    // (A11b).
  );

  _libraryMatrix(
    'SavedRecipesScreen',
    () => const SavedRecipesScreen(),
    content: _library(
      catalog: _catalog,
      saved: LibrarySaved(
        ids: const {'1', '2', '3', '6'},
        recipes: [_catalog[0], _catalog[1], _catalog[2], _catalog[5]],
      ),
    ),
    states: {
      'empty': _library(catalog: _catalog),
      'loading': _library(saved: const LibrarySaved(loading: true)),
      'offline': _library(
        catalog: _catalog,
        offline: true,
        saved: LibrarySaved(ids: const {'1'}, recipes: [_catalog[0]]),
      ),
    },
  );

  _libraryMatrix(
    'CreatorsScreen',
    () => const CreatorsScreen(),
    content: _library(catalog: _catalog),
    states: {
      'empty': _library(catalog: const []),
      'loading': _library(),
      'error': _library(catalogFailed: true),
      'offline': _library(offline: true),
    },
  );

  _libraryMatrix(
    'RecipeAuthorPage',
    () => const RecipeAuthorPage(authorId: 'mara', authorName: 'Mara Köhler'),
    content: _library(catalog: _catalog),
    states: {
      'empty': _library(catalog: const [], mine: const []),
      'loading': _library(load: _Load.never),
      'error': _library(load: _Load.fails),
      'offline': _library(catalog: _catalog, offline: true, mine: const []),
    },
  );
  layoutMatrix(
    'RecipeAuthorPage (own page)',
    (context) => _screen(
      _library(catalog: _catalog),
      const RecipeAuthorPage(authorId: 'me'),
    ),
    cases: _stateCases,
  );
  layoutMatrix(
    'RecipeAuthorPage (gone)',
    (context) => _screen(
      _library(catalog: const [], mine: const []),
      const RecipeAuthorPage(authorId: 'gone'),
    ),
    cases: _stateCases,
    afterPump: _shows('empty'),
  );
}
