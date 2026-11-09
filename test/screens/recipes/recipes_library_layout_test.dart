import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_author.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_creators.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_mine.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_saved.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';

import '../../layout/layout_matrix.dart';

final _now = DateTime(2026, 11, 8, 12);

Recipe _recipe(
  String id,
  String name, {
  String authorName = 'Mara Köhler',
  int minutes = 35,
  double rating = 0,
  int ratings = 0,
  int daysAgo = 3,
}) => Recipe(
  id: id,
  name: name,
  description: '',
  imageUrl: '',
  prepTimeMinutes: 10,
  cookTimeMinutes: minutes - 10,
  defaultServings: 2,
  ingredients: const [Ingredient(name: 'Feta', amount: 200, unit: 'g')],
  instructions: const ['Backen'],
  authorId: 'mara',
  authorName: authorName,
  createdAt: _now.subtract(Duration(days: daysAgo)),
  averageRating: rating,
  ratingCount: ratings,
);

final _recipes = [
  _recipe('1', 'Ofengemüse mit Feta', rating: 4.6, ratings: 23),
  _recipe(
    '2',
    'Kürbis-Risotto mit gerösteten Kernen und Salbeibutter',
    minutes: 70,
    rating: 4.8,
    ratings: 9,
    daysAgo: 14,
  ),
  _recipe('3', 'Linsen-Dal mit Spinat', authorName: 'Deniz Aydın'),
  _recipe('4', 'Zitronen-Hähnchen aus dem Ofen', minutes: 55, daysAgo: 1),
  _recipe('5', 'Shakshuka', minutes: 25),
];

const _following = [
  CreatorRowData(
    id: 'mara',
    name: 'Mara Köhler',
    recipeCount: 24,
    averageRating: 4.6,
    newRecipe: 'Kürbis-Risotto mit Salbeibutter',
  ),
  CreatorRowData(id: 'deniz', name: 'Deniz Aydın', recipeCount: 17),
];

const _popular = [
  CreatorRowData(
    id: 'sophie',
    name: 'Sophie Brandt-Wellershoff von der Heide',
    recipeCount: 11,
    averageRating: 4.6,
  ),
  CreatorRowData(id: 'jonas', name: 'Jonas Meier', recipeCount: 1),
  CreatorRowData(id: 'kim', name: 'Kim', recipeCount: 9, averageRating: 4.4),
];

RecipeDraft _draft(String id, String name, {bool complete = false}) =>
    RecipeDraft(
      id: id,
      name: name,
      description: complete ? 'Cremig' : '',
      localImagePath: null,
      prepTimeMinutes: complete ? 10 : null,
      cookTimeMinutes: complete ? 30 : null,
      defaultServings: complete ? 2 : null,
      ingredients: complete
          ? [DraftIngredient(name: 'Reis', amount: '200', unit: 'g')]
          : const [],
      instructions: complete ? const ['Rühren'] : const [],
      createdAt: _now,
      updatedAt: _now.subtract(const Duration(hours: 2)),
    );

/// The default text size and the largest, at the narrowest and a common
/// width, for the extra states.
final _stateCases = [
  for (final w in [320.0, 390.0])
    for (final s in [1.0, 3.1]) LayoutCase(width: w, scale: s),
];

void main() {
  layoutMatrix(
    'CreatorsContent',
    (context) => CreatorsContent(
      phase: LibraryPhase.ready,
      following: _following,
      popular: _popular,
      onOpen: (_) {},
      onUnfollow: (_) {},
    ),
    scrollable: true,
  );

  layoutMatrix(
    'CreatorsContent empty, offline, no match',
    (context) => Column(
      children: [
        CreatorsContent(
          phase: LibraryPhase.ready,
          following: const [],
          popular: const [],
          onOpen: (_) {},
          onUnfollow: (_) {},
          onWrite: () {},
        ),
        CreatorsContent(
          phase: LibraryPhase.loading,
          following: const [],
          popular: const [],
          offline: true,
          onOpen: (_) {},
          onUnfollow: (_) {},
        ),
        CreatorsContent(
          phase: LibraryPhase.ready,
          following: _following,
          popular: _popular,
          query: 'Zzyzx Unbekannt',
          onOpen: (_) {},
          onUnfollow: (_) {},
        ),
      ],
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'Creator page head and grid',
    (context) => Column(
      children: [
        const CreatorHeader(
          name: 'Mara Köhler-Brandtwellershoff',
          meta: '24 Rezepte · Ø 4,6',
        ),
        CreatorRecipesSection(
          phase: LibraryPhase.ready,
          recipes: _recipes,
          creatorName: 'Mara Köhler',
          onSort: (_) {},
          allergensOf: (r) =>
              r.id == '1' ? const ['Erdnüsse', 'Milch'] : const [],
          onOpen: (_) {},
        ),
      ],
    ),
    scrollable: true,
    checkTapTargets: true,
    cases: [
      for (final s in kLayoutTextScales) LayoutCase(width: 320, scale: s),
      for (final s in kLayoutTextScales) LayoutCase(width: 390, scale: s),
      const LayoutCase(width: 440, scale: 1),
      const LayoutCase(width: 390, scale: 1, brightness: Brightness.dark),
      const LayoutCase(width: 390, scale: 1, highContrast: true),
      const LayoutCase(width: 320, scale: 3.1, bold: true),
    ],
  );

  layoutMatrix(
    'Creator page states',
    (context) => Column(
      children: [
        const CreatorHeader(name: 'Deniz Aydın', following: true),
        const CreatorHeader(name: 'Ich', isSelf: true),
        CreatorRecipesSection(
          phase: LibraryPhase.ready,
          recipes: const [],
          creatorName: 'Deniz Aydın',
          onOpen: (_) {},
        ),
        CreatorRecipesSection(
          phase: LibraryPhase.loading,
          recipes: const [],
          creatorName: 'Deniz Aydın',
          failed: true,
          onRetry: () {},
          onOpen: (_) {},
        ),
      ],
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'SavedRecipesContent',
    (context) => SavedRecipesContent(
      phase: LibraryPhase.ready,
      recipes: [
        for (var i = 0; i < 11; i++)
          _recipe(
            's$i',
            i.isEven ? 'Shakshuka' : 'Kürbissuppe mit Ingwer und Kokosmilch',
          ),
      ],
      allergensOf: (r) => r.id == 's1' ? const ['Erdnüsse'] : const [],
      onOpen: (_) {},
      onRemove: (_) {},
      onOpenAuthor: (_) {},
    ),
    scrollable: true,
  );

  layoutMatrix(
    'SavedRecipesContent empty and loading',
    (context) => Column(
      children: [
        SavedRecipesContent(
          phase: LibraryPhase.ready,
          recipes: const [],
          onOpen: (_) {},
          onRemove: (_) {},
          onDiscover: () {},
        ),
        SavedRecipesContent(
          phase: LibraryPhase.loading,
          recipes: const [],
          onOpen: (_) {},
          onRemove: (_) {},
        ),
      ],
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'MyRecipesContent',
    (context) => MyRecipesContent(
      phase: LibraryPhase.ready,
      recipes: _recipes,
      now: _now,
      draftCount: 2,
      onOpen: (_) {},
      onEdit: (_) {},
      onShare: (_, _) {},
      confirmDelete: (_) async => true,
      onDelete: (_) {},
      onOpenDrafts: () {},
    ),
    scrollable: true,
  );

  layoutMatrix(
    'MyRecipesContent empty and error',
    (context) => Column(
      children: [
        MyRecipesContent(
          phase: LibraryPhase.ready,
          recipes: const [],
          now: _now,
          onOpen: (_) {},
          onEdit: (_) {},
          onShare: (_, _) {},
          confirmDelete: (_) async => true,
          onDelete: (_) {},
          onWrite: () {},
        ),
        MyRecipesContent(
          phase: LibraryPhase.error,
          recipes: const [],
          now: _now,
          failed: true,
          onRetry: () {},
          onOpen: (_) {},
          onEdit: (_) {},
          onShare: (_, _) {},
          confirmDelete: (_) async => true,
          onDelete: (_) {},
        ),
      ],
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDraftsContent',
    (context) => RecipeDraftsContent(
      phase: LibraryPhase.ready,
      drafts: [_draft('a', 'Kürbis-Risotto', complete: true), _draft('b', '')],
      now: _now,
      onContinue: (_) {},
      confirmDiscard: (_) async => true,
      onDiscard: (_) {},
    ),
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDraftsContent empty',
    (context) => RecipeDraftsContent(
      phase: LibraryPhase.ready,
      drafts: const [],
      now: _now,
      onContinue: (_) {},
      confirmDiscard: (_) async => true,
      onDiscard: (_) {},
      onWrite: () {},
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'RecipeDraftsContent failed',
    (context) => RecipeDraftsContent(
      phase: LibraryPhase.error,
      drafts: const [],
      now: _now,
      onContinue: (_) {},
      confirmDiscard: (_) async => true,
      onDiscard: (_) {},
      onWrite: () {},
      onRetry: () {},
    ),
    cases: _stateCases,
    scrollable: true,
  );

  testWidgets('drafts: a failed load says so instead of "no drafts"', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        SingleChildScrollView(
          child: RecipeDraftsContent(
            phase: LibraryPhase.error,
            drafts: const [],
            now: _now,
            onContinue: (_) {},
            confirmDiscard: (_) async => true,
            onDiscard: (_) {},
            onWrite: () {},
            onRetry: () => retried++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Drafts couldn\'t be loaded.'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  layoutMatrix(
    'LibraryStatus and AuthorAvatar',
    (context) => const Column(
      children: [
        LibraryStatus(offline: true),
        LibraryStatus(failed: true, hasContent: false),
        AuthorAvatar(name: 'Mara', size: 64),
        AuthorAvatar(name: 'Mara', size: 24),
        AuthorAvatar(name: '', size: 36),
        LibraryAllergenBadge(names: ['Erdnüsse', 'Nachtschattengewächse']),
      ],
    ),
    cases: _stateCases,
    scrollable: true,
  );

  layoutMatrix(
    'RecipesLibraryPage',
    (context) => SizedBox(
      height: kLayoutHeight,
      child: RecipesLibraryPage(
        title: 'Gespeichert',
        subtitle: '12 Rezepte',
        slivers: [
          SliverToBoxAdapter(
            child: SavedRecipesContent(
              phase: LibraryPhase.ready,
              recipes: _recipes,
              onOpen: (_) {},
              onRemove: (_) {},
            ),
          ),
        ],
      ),
    ),
    cases: _stateCases,
  );
}
