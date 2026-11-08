import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/multi_step_recipe_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_backend.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

import '../../layout/layout_matrix.dart';

class _Drafts implements RecipeEditorDrafts {
  _Drafts([Map<String, RecipeDraft>? initial]) : store = {...?initial};

  final Map<String, RecipeDraft> store;
  final deleted = <String>[];

  @override
  Future<RecipeDraft?> get(String id) async => store[id];

  @override
  Future<void> save(RecipeDraft draft) async => store[draft.id] = draft;

  @override
  Future<void> delete(String id) async {
    store.remove(id);
    deleted.add(id);
  }

  @override
  Future<String> keepPhoto(String draftId, File file) async =>
      '/drafts/$draftId.jpg';

  @override
  Future<File?> photo(String? path) async => null;

  @override
  Future<void> deletePhoto(String? path) async {}
}

class _Backend implements RecipeEditorBackend {
  _Backend({this.recipe, this.fail = false});

  final Recipe? recipe;
  bool fail;
  final created = <(Recipe, String)>[];
  final updated = <Recipe>[];

  @override
  Future<Recipe> load(String recipeId) async {
    if (fail || recipe == null) throw Exception('offline');
    return recipe!;
  }

  @override
  Future<String> uploadPhoto(File file) async => 'https://x/photo.jpg';

  @override
  Future<String> create(Recipe recipe, {required String difficulty}) async {
    if (fail) throw Exception('server');
    created.add((recipe, difficulty));
    return 'new-id';
  }

  @override
  Future<void> update(Recipe recipe) async {
    if (fail) throw Exception('server');
    updated.add(recipe);
  }
}

final _fullDraft = RecipeDraft(
  id: 'd1',
  name: 'Omas Kartoffelsalat',
  description: 'Lauwarm am besten.',
  prepTimeMinutes: 20,
  cookTimeMinutes: 30,
  defaultServings: 4,
  ingredients: [
    DraftIngredient(name: 'Kartoffeln, festkochend', amount: '1', unit: 'kg'),
    DraftIngredient(name: 'Zwiebel', amount: '1', unit: ''),
    DraftIngredient(name: 'Brühe', amount: '150', unit: 'ml'),
    DraftIngredient(name: 'Salz nach Geschmack', amount: '', unit: ''),
  ],
  instructions: [
    'Kartoffeln 25 Minuten kochen, pellen und in Scheiben schneiden.',
    'Brühe erhitzen und über die Kartoffeln gießen.',
  ],
  createdAt: DateTime(2026, 11, 7),
  updatedAt: DateTime(2026, 11, 7),
);

final _published = Recipe(
  id: 'r1',
  name: 'Ofengemüse mit Feta',
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: 25,
  defaultServings: 2,
  ingredients: const [Ingredient(name: 'Feta', amount: 200, unit: 'g')],
  instructions: const ['Alles 15 Minuten backen.'],
  labels: const ['healthy', 'easy'],
  authorId: 'me',
  authorName: 'Jannis D.',
  createdAt: DateTime(2026, 11, 1),
);

List<Override> _overrides({
  _Drafts? drafts,
  _Backend? backend,
  bool offline = false,
  String? author = 'Jannis D.',
}) => [
  recipeEditorDraftsProvider.overrideWithValue(drafts ?? _Drafts()),
  recipeEditorBackendProvider.overrideWithValue(backend ?? _Backend()),
  recipeEditorPhotoPickerProvider.overrideWithValue((_) async => null),
  recipeEditorAuthorNameProvider.overrideWithValue(author),
  isOfflineProvider.overrideWithValue(offline),
];

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapNext(WidgetTester tester, [String label = 'Next']) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await _settle(tester);
}

/// Opens the editor from a host page, as the route does.
class _Host extends StatelessWidget {
  const _Host({this.draftId, this.recipeId});

  final String? draftId;
  final String? recipeId;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () async {
        final result = await Navigator.of(context).push<Object?>(
          MaterialPageRoute(
            builder: (_) =>
                MultiStepRecipeScreen(draftId: draftId, recipeId: recipeId),
          ),
        );
        _lastResult = result;
      },
      child: const Text('open'),
    ),
  );
}

Object? _lastResult;

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: Scaffold(body: home),
  ),
);

void _editorTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester, 15);
    });

Widget _editor({String? draftId, String? recipeId, List<Override>? o}) =>
    ProviderScope(
      overrides:
          o ??
          _overrides(
            drafts: _Drafts({'d1': _fullDraft}),
            backend: _Backend(recipe: _published),
          ),
      child: MultiStepRecipeScreen(draftId: draftId, recipeId: recipeId),
    );

Future<void> _toStep(WidgetTester tester, int step) async {
  await _settle(tester, 3);
  for (var i = 0; i < step; i++) {
    await _tapNext(tester);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _lastResult = null;
  });

  layoutMatrix(
    'Rezept-Editor neu, Name fehlt',
    (context) => _editor(),
    afterPump: (tester) async {
      await _tapNext(tester);
    },
  );

  layoutMatrix(
    'Rezept-Editor Zeiten',
    (context) => _editor(draftId: 'd1'),
    afterPump: (tester) => _toStep(tester, 1),
  );

  layoutMatrix(
    'Rezept-Editor Zutaten',
    (context) => _editor(draftId: 'd1'),
    afterPump: (tester) => _toStep(tester, 2),
  );

  layoutMatrix(
    'Rezept-Editor Zubereitung',
    (context) => _editor(draftId: 'd1'),
    afterPump: (tester) => _toStep(tester, 3),
  );

  _editorTest('Next with an empty name shows the sentence at the field', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_overrides(), _editor(o: _overrides())));
    await _settle(tester, 3);
    expect(find.text('Photo and name'), findsOneWidget);
    expect(find.text('New recipe · 1 of 4'), findsOneWidget);
    await _tapNext(tester);
    expect(find.text('Give the recipe a name.'), findsOneWidget);
    expect(find.text('Photo and name'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'Ofengemüse');
    await _settle(tester);
    expect(find.text('Give the recipe a name.'), findsNothing);
    await _tapNext(tester);
    expect(find.text('Times and servings'), findsOneWidget);
    expect(find.text('Total 30 min'), findsOneWidget);
  });

  _editorTest('a new recipe is saved as a draft 1 s after typing', (
    tester,
  ) async {
    final drafts = _Drafts();
    await tester.pumpWidget(
      _app(_overrides(drafts: drafts), const _Host()),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(drafts.store, isEmpty);
    await tester.enterText(find.byType(EditableText).first, 'Ofengemüse');
    await tester.pump(const Duration(milliseconds: 500));
    expect(drafts.store, isEmpty);
    await _settle(tester);
    expect(drafts.store.values.single.name, 'Ofengemüse');

    // X closes at once and says it was kept.
    await tester.tap(find.bySemanticsLabel('Close').first);
    await _settle(tester);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Saved as a draft'), findsOneWidget);
  });

  _editorTest('closing an untouched new recipe leaves no draft', (
    tester,
  ) async {
    final drafts = _Drafts();
    await tester.pumpWidget(_app(_overrides(drafts: drafts), const _Host()));
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Close').first);
    await _settle(tester);
    expect(drafts.store, isEmpty);
    expect(find.text('Saved as a draft'), findsNothing);
  });

  _editorTest('ingredients: parsed line, Return adds a row, delete undoes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_overrides(), _editor(draftId: 'd1')));
    await _toStep(tester, 2);
    expect(find.text('1 kg · Kartoffeln, festkochend'), findsOneWidget);
    expect(find.text('150 ml · Brühe'), findsOneWidget);
    expect(find.text('Salz nach Geschmack · no amount'), findsOneWidget);

    final rows = find.byType(EditableText);
    final before = rows.evaluate().length;
    await tester.tap(rows.at(1));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await _settle(tester);
    expect(find.byType(EditableText).evaluate().length, before + 1);

    await tester.drag(find.text('1 · Zwiebel'), const Offset(-500, 0));
    await _settle(tester);
    expect(find.text('1 · Zwiebel'), findsNothing);
    expect(find.text('Zwiebel removed'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('1 · Zwiebel'), findsOneWidget);
  });

  _editorTest('publish: all steps checked, draft deleted, detail opened', (
    tester,
  ) async {
    final drafts = _Drafts({'d1': _fullDraft});
    final backend = _Backend();
    await tester.pumpWidget(
      _app(
        _overrides(drafts: drafts, backend: backend),
        const _Host(draftId: 'd1'),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _toStep(tester, 3);
    expect(find.text('Shown under your name: Jannis D.'), findsOneWidget);
    expect(find.text('Timer 25 min in cooking mode'), findsOneWidget);
    await _tapNext(tester, 'Publish');
    expect(backend.created, hasLength(1));
    final (recipe, difficulty) = backend.created.single;
    expect(recipe.name, 'Omas Kartoffelsalat');
    expect(recipe.defaultServings, 4);
    expect(recipe.ingredients.first.unit, 'kg');
    expect(recipe.ingredients.last.amount, 0);
    expect(difficulty, 'easy');
    expect(drafts.deleted, ['d1']);
    expect(_lastResult, 'new-id');
  });

  _editorTest('publish without a display name asks for one', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(
      _app(
        _overrides(
          drafts: _Drafts({'d1': _fullDraft}),
          backend: backend,
          author: null,
        ),
        _editor(
          draftId: 'd1',
          o: _overrides(
            drafts: _Drafts({'d1': _fullDraft}),
            backend: backend,
            author: null,
          ),
        ),
      ),
    );
    await _toStep(tester, 3);
    await _tapNext(tester, 'Publish');
    expect(backend.created, isEmpty);
    expect(
      find.text('Set a name first, so your email address is never shown.'),
      findsOneWidget,
    );
  });

  _editorTest('offline: nothing is sent, the draft stays, a status says so', (
    tester,
  ) async {
    final backend = _Backend();
    final o = _overrides(
      drafts: _Drafts({'d1': _fullDraft}),
      backend: backend,
      offline: true,
    );
    await tester.pumpWidget(_app(o, _editor(draftId: 'd1', o: o)));
    await _toStep(tester, 3);
    await _tapNext(tester, 'Publish');
    expect(backend.created, isEmpty);
    expect(find.textContaining('You are offline'), findsOneWidget);
  });

  _editorTest('a server error keeps everything and offers a retry', (
    tester,
  ) async {
    final backend = _Backend(fail: true);
    final drafts = _Drafts({'d1': _fullDraft});
    final o = _overrides(drafts: drafts, backend: backend);
    await tester.pumpWidget(_app(o, _editor(draftId: 'd1', o: o)));
    await _toStep(tester, 3);
    await _tapNext(tester, 'Publish');
    expect(
      find.text('Not published yet. Your draft is kept.'),
      findsOneWidget,
    );
    expect(drafts.store.containsKey('d1'), isTrue);
    backend.fail = false;
    await tester.tap(find.text('Try again'));
    await _settle(tester);
    expect(backend.created, hasLength(1));
  });

  _editorTest('discard asks, then deletes the draft', (tester) async {
    final drafts = _Drafts({'d1': _fullDraft});
    await tester.pumpWidget(
      _app(_overrides(drafts: drafts), const _Host(draftId: 'd1')),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('More'));
    await _settle(tester);
    await tester.tap(find.text('Discard draft'));
    await _settle(tester);
    expect(find.text('Discard draft?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(drafts.deleted, ['d1']);
    expect(find.text('open'), findsOneWidget);
  });

  _editorTest('edit: no draft, changes saved to the same recipe', (
    tester,
  ) async {
    final drafts = _Drafts();
    final backend = _Backend(recipe: _published);
    await tester.pumpWidget(
      _app(
        _overrides(drafts: drafts, backend: backend),
        const _Host(recipeId: 'r1'),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Editing · 1 of 4'), findsOneWidget);

    // Untouched: X closes without asking.
    await tester.tap(find.bySemanticsLabel('Close').first);
    await _settle(tester);
    expect(find.text('open'), findsOneWidget);

    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText).first, 'Ofengemüse neu');
    await _settle(tester, 15);
    expect(drafts.store, isEmpty);
    await tester.tap(find.bySemanticsLabel('Close').first);
    await _settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);

    await _toStep(tester, 3);
    await _tapNext(tester, 'Save changes');
    expect(backend.updated.single.id, 'r1');
    expect(backend.updated.single.name, 'Ofengemüse neu');
    expect(_lastResult, isTrue);
  });

  _editorTest('a recipe that cannot be loaded shows a status, no form', (
    tester,
  ) async {
    final o = _overrides(backend: _Backend(fail: true));
    await tester.pumpWidget(_app(o, _editor(recipeId: 'r1', o: o)));
    await _settle(tester);
    expect(
      find.text('This recipe cannot be loaded right now.'),
      findsOneWidget,
    );
    expect(find.byType(EditableText), findsNothing);
  });

  _editorTest('the step title opens the step menu and jumps', (tester) async {
    await tester.pumpWidget(_app(_overrides(), _editor(draftId: 'd1')));
    await _settle(tester);
    await tester.tap(find.text('Photo and name'));
    await _settle(tester);
    await tester.tap(find.text('Ingredients').last);
    await _settle(tester);
    expect(find.text('Draft · 3 of 4'), findsNothing);
    expect(find.text('New recipe · 3 of 4'), findsOneWidget);
  });

  _editorTest('tells Avo the person is in recipes', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      _app(
        _overrides(),
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return const _Host();
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(ref.read(avoScreenContextProvider)?.screen, 'recipes');
    await tester.tap(find.bySemanticsLabel('Close').first);
    await _settle(tester);
    expect(ref.read(avoScreenContextProvider), isNull);
  });
}
