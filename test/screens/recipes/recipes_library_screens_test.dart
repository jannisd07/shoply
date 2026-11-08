import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/my_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/recipe_author_page.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_follow.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

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
  _recipe('2', 'Kürbis-Risotto', rating: 4.8, ratings: 9),
  _recipe('3', 'Linsen-Dal', author: 'deniz', authorName: 'Deniz Aydın'),
  _recipe('4', 'Pausenbrot', author: 'me', authorName: 'Ich'),
];

final _savedState = StateProvider<LibrarySaved>(
  (ref) =>
      LibrarySaved(ids: const {'1', '3'}, recipes: [_catalog[0], _catalog[2]]),
);

class _FakeBackend implements CreatorFollowBackend {
  final remote = <String>{};

  @override
  Future<Set<String>> fetch(String userId) async => {...remote};
  @override
  Future<void> follow(String userId, String creatorId) async =>
      remote.add(creatorId);
  @override
  Future<void> unfollow(String userId, String creatorId) async =>
      remote.remove(creatorId);
}

class _FakeActions extends RecipeLibraryActions {
  _FakeActions(
    super.ref,
    this._r, {
    this.mine = const [],
    this.drafts_ = const [],
    this.byAuthor,
    this.failDelete = false,
  });

  final Ref _r;
  final List<Recipe> mine;
  final List<RecipeDraft> drafts_;
  final List<Recipe>? byAuthor;
  final bool failDelete;
  final deleted = <String>[];
  final discarded = <String>[];
  final toggled = <String>[];

  @override
  Future<List<Recipe>> myRecipes() async => mine;

  @override
  Future<List<Recipe>> recipesBy(String authorId) async =>
      byAuthor ??
      [
        for (final r in _catalog)
          if (r.authorId == authorId) r,
      ];

  @override
  Future<void> deleteRecipe(String recipeId) async {
    if (failDelete) throw Exception('server says no');
    deleted.add(recipeId);
  }

  @override
  void catalogChanged() {}

  @override
  Future<void> reloadCatalog() async {}

  @override
  Future<void> reloadSaved() async {}

  @override
  Future<bool> toggleSaved(String recipeId) async {
    toggled.add(recipeId);
    final s = _r.read(_savedState);
    final ids = {...s.ids};
    if (!ids.remove(recipeId)) ids.add(recipeId);
    _r.read(_savedState.notifier).state = LibrarySaved(
      ids: ids,
      // Like the real provider: the reload drops unsaved recipes.
      recipes: [
        for (final r in s.recipes)
          if (ids.contains(r.id)) r,
      ],
    );
    return true;
  }

  @override
  Future<List<RecipeDraft>> drafts() async => drafts_;

  @override
  Future<void> deleteDraft(RecipeDraft draft) async => discarded.add(draft.id);

  @override
  Future<void> shareRecipe(Recipe recipe, {Rect? origin}) async {}
}

RecipeDraft _draft(String id, String name) => RecipeDraft(
  id: id,
  name: name,
  description: '',
  ingredients: const [],
  instructions: const [],
  createdAt: _now,
  updatedAt: _now.subtract(const Duration(hours: 2)),
);

late _FakeActions _actions;
late ProviderContainer _container;

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Recipe> mine = const [],
  List<RecipeDraft> drafts = const [],
  List<Recipe>? byAuthor,
  bool failDelete = false,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await loadLayoutFonts();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryCatalogProvider.overrideWithValue(_catalog),
        libraryCatalogFailedProvider.overrideWithValue(false),
        libraryAllergiesProvider.overrideWithValue(const []),
        librarySavedProvider.overrideWith((ref) => ref.watch(_savedState)),
        isOfflineProvider.overrideWithValue(false),
        authUserIdProvider.overrideWithValue('me'),
        creatorFollowBackendProvider.overrideWithValue(_FakeBackend()),
        recipeLibraryActionsProvider.overrideWith(
          (ref) => _actions = _FakeActions(
            ref,
            ref,
            mine: mine,
            drafts_: drafts,
            byAuthor: byAuthor,
            failDelete: failDelete,
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          _container = ProviderScope.containerOf(context);
          return layoutHarness(
            const LayoutCase(width: 390, scale: 1),
            SizedBox(height: kLayoutHeight, child: screen),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A button of the confirmation dialog (the swipe background below says
/// the same word).
Finder _dialogButton(String label) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(label),
);

/// Lets the undo toast run out so no timer is left.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Ersteller', () {
    testWidgets('lists popular creators from the catalogue, own rows first', (
      tester,
    ) async {
      await _pump(tester, const CreatorsScreen());
      expect(find.text('Creators'), findsWidgets);
      expect(find.text('POPULAR CREATORS'), findsOneWidget);
      expect(find.text('Mara Köhler'), findsOneWidget);
      expect(find.text('2 recipes · avg 4.7'), findsOneWidget);
      expect(find.text('Deniz Aydın'), findsOneWidget);
      expect(_container.read(avoScreenContextProvider)?.screen, 'recipes');
    });

    testWidgets('search filters at once and says when nobody matches', (
      tester,
    ) async {
      await _pump(tester, const CreatorsScreen());
      await tester.enterText(find.byType(EditableText), 'deniz');
      await tester.pump();
      expect(find.text('Mara Köhler'), findsNothing);
      expect(find.text('Deniz Aydın'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'kim');
      await tester.pump();
      expect(find.text('No one found for “kim”.'), findsOneWidget);
    });

    testWidgets('swiping a followed creator unfollows with undo', (
      tester,
    ) async {
      await _pump(tester, const CreatorsScreen());
      await _container
          .read(creatorFollowsProvider.notifier)
          .follow('mara', name: 'Mara Köhler');
      await tester.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsOneWidget);

      await tester.drag(find.text('Mara Köhler'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsNothing);
      expect(find.text('Unfollowed Mara Köhler'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(
        _container.read(creatorFollowsProvider).isFollowing('mara'),
        isTrue,
      );
      await _settleToast(tester);
    });
  });

  group('Ersteller-Seite', () {
    testWidgets('head with numbers, follow and following', (tester) async {
      await _pump(
        tester,
        const RecipeAuthorPage(authorId: 'mara', authorName: 'Mara Köhler'),
      );
      expect(find.text('Mara Köhler'), findsOneWidget);
      expect(find.text('2 recipes · avg 4.7'), findsOneWidget);
      expect(find.text('Ofengemüse mit Feta'), findsOneWidget);
      expect(find.text('Kürbis-Risotto'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
      expect(
        _container.read(creatorFollowsProvider).isFollowing('mara'),
        isTrue,
      );

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Unfollowed Mara Köhler'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('sorting by popular puts the best rated first', (tester) async {
      await _pump(
        tester,
        const RecipeAuthorPage(authorId: 'mara', authorName: 'Mara Köhler'),
      );
      double top(String text) => tester.getTopLeft(find.text(text)).dx;
      // Newest first: both are 3 days old, so the order is stable; switch.
      await tester.tap(find.bySemanticsLabel('Sort by: Newest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();
      expect(top('Kürbis-Risotto'), lessThan(top('Ofengemüse mit Feta')));
    });

    testWidgets('own page offers "Edit profile" instead of follow', (
      tester,
    ) async {
      await _pump(tester, const RecipeAuthorPage(authorId: 'me'));
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('an unknown creator without recipes is no longer available', (
      tester,
    ) async {
      await _pump(
        tester,
        const RecipeAuthorPage(authorId: 'gone'),
        byAuthor: const [],
      );
      expect(find.text('This page is no longer available.'), findsOneWidget);
      expect(find.text('Go to recipes'), findsOneWidget);
    });
  });

  group('Gespeichert', () {
    testWidgets('rows with creator, swipe removes, undo brings it back', (
      tester,
    ) async {
      await _pump(tester, const SavedRecipesScreen());
      expect(find.text('Saved'), findsWidgets);
      expect(find.text('2 recipes'), findsOneWidget);
      expect(find.text('35 min · by Mara Köhler'), findsOneWidget);

      await tester.drag(
        find.text('Ofengemüse mit Feta'),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ofengemüse mit Feta'), findsNothing);
      expect(find.text('Removed from Saved'), findsOneWidget);
      expect(_actions.toggled, ['1']);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Ofengemüse mit Feta'), findsOneWidget);
      expect(_actions.toggled, ['1', '1']);
      // Back at its old place, above "Linsen-Dal".
      expect(
        tester.getTopLeft(find.text('Ofengemüse mit Feta')).dy,
        lessThan(tester.getTopLeft(find.text('Linsen-Dal')).dy),
      );
      await _settleToast(tester);
    });

    testWidgets('empty state offers to discover recipes', (tester) async {
      await _pump(tester, const SavedRecipesScreen());
      _container.read(_savedState.notifier).state = const LibrarySaved();
      await tester.pumpAndSettle();
      expect(find.text('No saved recipes yet.'), findsOneWidget);
      expect(find.text('Discover recipes'), findsOneWidget);
    });
  });

  group('Meine Rezepte', () {
    testWidgets('status sections, drafts row and delete after confirmation', (
      tester,
    ) async {
      await _pump(
        tester,
        const MyRecipesScreen(),
        mine: [_catalog[0], _catalog[3]],
        drafts: [_draft('d1', 'Kürbis-Risotto')],
      );
      expect(find.text('My recipes'), findsWidgets);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('PUBLISHED'), findsOneWidget);
      expect(find.text('4.6 (23) · 3 days ago'), findsOneWidget);
      expect(find.text('Not rated yet · 3 days ago'), findsOneWidget);

      await tester.longPress(find.text('Pausenbrot'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Pausenbrot”?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(_actions.deleted, ['4']);
      expect(find.text('Pausenbrot'), findsNothing);
      expect(find.text('Recipe deleted'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('a failed delete puts the recipe back', (tester) async {
      await _pump(
        tester,
        const MyRecipesScreen(),
        mine: [_catalog[3]],
        failDelete: true,
      );
      await tester.drag(find.text('Pausenbrot'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Pausenbrot”?'), findsOneWidget);
      await tester.tap(_dialogButton('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Pausenbrot'), findsOneWidget);
      expect(
        find.text('The recipe couldn\'t be deleted. Try again.'),
        findsOneWidget,
      );
      await _settleToast(tester);
    });

    testWidgets('no recipes: empty state with "Write a recipe"', (
      tester,
    ) async {
      await _pump(tester, const MyRecipesScreen());
      expect(find.text('You haven\'t written a recipe yet.'), findsOneWidget);
      expect(find.text('Write a recipe'), findsOneWidget);
    });
  });

  group('Entwürfe', () {
    testWidgets('status per draft; discard asks first', (tester) async {
      await _pump(
        tester,
        const RecipeDraftsScreen(),
        drafts: [_draft('d1', 'Kürbis-Risotto'), _draft('d2', '')],
      );
      expect(find.text('Untitled draft'), findsOneWidget);
      expect(
        find.textContaining('Missing: description, photo and 4 more'),
        findsNWidgets(1),
      );
      expect(find.text('Drafts are kept on this device only.'), findsOneWidget);

      // Cancel keeps the draft.
      await tester.drag(find.text('Kürbis-Risotto'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Discard draft?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Kürbis-Risotto'), findsOneWidget);
      expect(_actions.discarded, isEmpty);

      await tester.drag(find.text('Kürbis-Risotto'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Kürbis-Risotto'), findsNothing);
      expect(_actions.discarded, ['d1']);
      expect(find.text('Draft discarded'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('no drafts: empty state', (tester) async {
      await _pump(tester, const RecipeDraftsScreen());
      expect(find.text('No drafts.'), findsOneWidget);
    });
  });
}
