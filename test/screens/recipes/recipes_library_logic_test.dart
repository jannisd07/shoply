import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/presentation/screens/recipes/creators_screen.dart';
import 'package:shoply/presentation/screens/recipes/saved_recipes_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_author.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_follow.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_saved.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';

final _now = DateTime(2026, 11, 8, 12);

Recipe _recipe(
  String id, {
  String name = 'Ofengemüse mit Feta',
  String author = 'mara',
  String authorName = 'Mara Köhler',
  int minutes = 35,
  double rating = 0,
  int ratings = 0,
  int views = 0,
  DateTime? created,
  List<String> ingredients = const ['Zucchini', 'Feta'],
  String? source,
}) => Recipe(
  id: id,
  name: name,
  description: '',
  imageUrl: '',
  prepTimeMinutes: minutes ~/ 2,
  cookTimeMinutes: minutes - minutes ~/ 2,
  defaultServings: 2,
  ingredients: [
    for (final i in ingredients) Ingredient(name: i, amount: 1, unit: 'Stück'),
  ],
  instructions: const ['Kochen'],
  authorId: author,
  authorName: authorName,
  createdAt: created ?? _now.subtract(const Duration(days: 3)),
  averageRating: rating,
  ratingCount: ratings,
  viewCount: views,
  sourceUrl: source,
);

RecipeDraft _draft({
  String name = '',
  String description = '',
  String? image,
  int? prep,
  int? cook,
  int? servings,
  List<DraftIngredient> ingredients = const [],
  List<String> steps = const [],
}) => RecipeDraft(
  id: 'd1',
  name: name,
  description: description,
  localImagePath: image,
  prepTimeMinutes: prep,
  cookTimeMinutes: cook,
  defaultServings: servings,
  ingredients: ingredients,
  instructions: steps,
  createdAt: _now,
  updatedAt: _now,
);

/// Runs [body] with a BuildContext in [locale].
Future<void> _withContext(
  WidgetTester tester,
  void Function(BuildContext context) body, {
  Locale locale = const Locale('de'),
}) async {
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            body(context);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
}

class _FakeBackend implements CreatorFollowBackend {
  _FakeBackend({this.remote = const {}, this.offline = false});

  Set<String> remote;
  bool offline;
  final List<String> calls = [];

  @override
  Future<Set<String>> fetch(String userId) async {
    if (offline) throw Exception('offline');
    return {...remote};
  }

  @override
  Future<void> follow(String userId, String creatorId) async {
    if (offline) throw Exception('offline');
    calls.add('+$creatorId');
    remote = {...remote, creatorId};
  }

  @override
  Future<void> unfollow(String userId, String creatorId) async {
    if (offline) throw Exception('offline');
    calls.add('-$creatorId');
    remote = {...remote}..remove(creatorId);
  }
}

void main() {
  group('formatting', () {
    testWidgets('durations, ratings and counts in German', (tester) async {
      await _withContext(tester, (context) {
        expect(formatDuration(context, 35), '35 Min');
        expect(formatDuration(context, 60), '1 Std.');
        expect(formatDuration(context, 70), '1 Std. 10 Min');
        expect(formatRating(context, 4.64), '4,6');
        expect(formatRecipeCount(context, 1), '1 Rezept');
        expect(formatRecipeCount(context, 24), '24 Rezepte');
        expect(
          formatRatingWithCount(
            context,
            _recipe('a', rating: 4.6, ratings: 23),
          ),
          '4,6 (23)',
        );
        expect(formatRatingWithCount(context, _recipe('b')), isNull);
        expect(
          recipeCardMeta(context, _recipe('c', rating: 4.6, ratings: 3)),
          '35 Min · ★ 4,6',
        );
        expect(recipeCardMeta(context, _recipe('d')), '35 Min');
        expect(
          recipeCardVoice(context, _recipe('e', rating: 4.5, ratings: 2)),
          'Ofengemüse mit Feta, 35 Minuten, Bewertung 4,5',
        );
      });
    });

    testWidgets('English uses a decimal point', (tester) async {
      await _withContext(tester, locale: const Locale('en'), (context) {
        expect(formatRating(context, 4.6), '4.6');
        expect(formatDuration(context, 70), '1 h 10 min');
      });
    });

    testWidgets('relative times', (tester) async {
      await _withContext(tester, (context) {
        String ago(Duration d) => formatAgo(context, _now.subtract(d), _now);
        expect(ago(Duration.zero), 'gerade eben');
        expect(ago(const Duration(minutes: 5)), 'vor 5 Min.');
        expect(ago(const Duration(hours: 2)), 'vor 2 Std.');
        expect(ago(const Duration(hours: 30)), 'gestern');
        expect(ago(const Duration(days: 3)), 'vor 3 Tagen');
        expect(ago(const Duration(days: 8)), 'vor 1 Woche');
        expect(ago(const Duration(days: 15)), 'vor 2 Wochen');
        expect(ago(const Duration(days: 40)), 'vor 1 Monat');
        expect(ago(const Duration(days: 400)), 'vor 1 Jahr');
        expect(ago(const Duration(days: 800)), 'vor 2 Jahren');
      });
    });

    test('meta parts skip empty ones', () {
      expect(joinMeta(['35 Min', null, '', 'von Mara']), '35 Min · von Mara');
    });
  });

  group('drafts', () {
    test('an empty draft misses everything, in editor order', () {
      expect(draftMissingKeys(_draft()), [
        'recipe_lib_part_title',
        'recipe_lib_part_description',
        'recipe_lib_part_photo',
        'recipe_lib_part_times',
        'recipe_lib_part_servings',
        'recipe_lib_part_ingredients',
        'recipe_lib_part_steps',
      ]);
    });

    test('a complete draft misses nothing, like isComplete', () {
      final draft = _draft(
        name: 'Kürbis-Risotto',
        description: 'Cremig',
        image: '/docs/recipe_drafts/d1.jpg',
        prep: 10,
        cook: 30,
        servings: 2,
        ingredients: [DraftIngredient(name: 'Reis', amount: '200', unit: 'g')],
        steps: const ['Rühren'],
      );
      expect(draftMissingKeys(draft), isEmpty);
      expect(draft.isComplete, isTrue);
    });

    testWidgets('status line names what is missing', (tester) async {
      await _withContext(tester, (context) {
        final draft = _draft(
          name: 'Kürbis-Risotto',
          description: 'Cremig',
          image: '/x.jpg',
          prep: 10,
          cook: 30,
          servings: 2,
        );
        expect(draftStatus(context, draft), 'Es fehlen: Zutaten, Anleitung');
        expect(draftTitle(context, _draft()), 'Unbenannter Entwurf');
        expect(
          draftStatus(context, _draft()),
          'Es fehlen: Titel, Beschreibung und 5 weitere',
        );
      });
    });

    test('editor paths carry the ids', () {
      expect(editRecipePath('r1'), '/recipes/add?recipeId=r1');
      expect(continueDraftPath('draft_1'), '/recipes/add?draftId=draft_1');
      expect(creatorPath('mara'), '/author/mara');
    });
  });

  group('creators', () {
    final catalog = [
      _recipe('1', author: 'mara', rating: 4.6, ratings: 10),
      _recipe('2', author: 'mara', name: 'Kürbis-Risotto', created: _now),
      _recipe('3', author: 'deniz', authorName: 'Deniz Aydın'),
      _recipe(
        '4',
        author: 'wiki',
        authorName: 'Wikibooks',
        source: 'https://x',
      ),
    ];

    test('ranks creators and leaves imported recipes out', () {
      final ranked = rankCreators(catalog);
      expect(ranked.map((c) => c.id), ['mara', 'deniz']);
      expect(ranked.first.recipeCount, 2);
      expect(ranked.first.averageRating, 4.6);
      expect(ranked.first.recipes.first.name, 'Kürbis-Risotto');
    });

    test('followed rows say "neu" for a recipe since the last visit', () {
      final follows = CreatorFollowsState(
        loaded: true,
        followed: {
          'mara': FollowedCreator(
            id: 'mara',
            name: 'Mara Köhler',
            followedAt: _now.subtract(const Duration(days: 10)),
            lastSeen: _now.subtract(const Duration(days: 1)),
          ),
        },
      );
      final rows = creatorRows(rankCreators(catalog), follows);
      expect(rows.following.single.newRecipe, 'Kürbis-Risotto');
      expect(rows.following.single.recipeCount, 2);
      expect(rows.popular.map((c) => c.id), ['mara', 'deniz']);
    });

    test('creator recipes sort by newest or by rating', () {
      final list = [
        _recipe('old', rating: 4.9, ratings: 3, created: DateTime(2026)),
        _recipe('new', created: _now),
      ];
      expect(sortCreatorRecipes(list, CreatorSort.newest).first.id, 'new');
      expect(sortCreatorRecipes(list, CreatorSort.popular).first.id, 'old');
    });
  });

  group('saved', () {
    test('visible rows follow the saved ids and keep undo places', () {
      final a = _recipe('a');
      final b = _recipe('b');
      final c = _recipe('c');
      // "b" was removed (no longer loaded), then brought back by undo.
      final saved = LibrarySaved(ids: const {'a', 'b', 'c'}, recipes: [a, c]);
      final shown = visibleSavedRecipes(saved, restoring: {'b': (1, b)});
      expect(shown.map((r) => r.id), ['a', 'b', 'c']);
    });

    test('unsaved rows leave at once', () {
      final saved = LibrarySaved(
        ids: const {'a'},
        recipes: [_recipe('a'), _recipe('b')],
      );
      expect(visibleSavedRecipes(saved).map((r) => r.id), ['a']);
    });

    test('first open falls back to the catalogue', () {
      const saved = LibrarySaved(ids: {'b'}, loading: true);
      final shown = visibleSavedRecipes(
        saved,
        catalog: [_recipe('a'), _recipe('b')],
      );
      expect(shown.map((r) => r.id), ['b']);
    });

    test('search matches name, creator and labels', () {
      final list = [
        _recipe('a', name: 'Shakshuka', authorName: 'Deniz Aydın'),
        _recipe('b', name: 'Kürbissuppe'),
      ];
      expect(filterSavedRecipes(list, 'deniz').single.id, 'a');
      expect(filterSavedRecipes(list, 'suppe').single.id, 'b');
      expect(filterSavedRecipes(list, ''), hasLength(2));
    });
  });

  group('allergens', () {
    testWidgets('names the person\'s allergens found in a recipe', (
      tester,
    ) async {
      await _withContext(tester, (context) {
        final recipe = _recipe('a', ingredients: ['Erdnussbutter', 'Reis']);
        expect(libraryAllergenNames(context, recipe, ['peanuts']), [
          'Erdnüsse',
        ]);
        expect(libraryAllergenNames(context, recipe, ['milk']), isEmpty);
        expect(libraryAllergenNames(context, recipe, const []), isEmpty);
      });
    });
  });

  group('follows', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('follow is immediate, synced and stored per account', () async {
      final backend = _FakeBackend();
      final n = CreatorFollowsNotifier(userId: 'me', backend: backend);
      await n.load();
      await n.follow('mara', name: 'Mara Köhler');
      expect(n.state.isFollowing('mara'), isTrue);
      await n.sync();
      expect(backend.calls, ['+mara']);

      final again = CreatorFollowsNotifier(userId: 'me', backend: backend);
      await again.load();
      expect(again.state.followed['mara']?.name, 'Mara Köhler');

      final other = CreatorFollowsNotifier(
        userId: 'you',
        backend: _FakeBackend(),
      );
      await other.load();
      expect(other.state.followed, isEmpty);
    });

    test('offline changes wait and are sent later', () async {
      final backend = _FakeBackend(offline: true);
      final n = CreatorFollowsNotifier(userId: 'me', backend: backend);
      await n.load();
      await n.follow('mara', name: 'Mara Köhler');
      await n.sync();
      expect(n.state.isFollowing('mara'), isTrue);
      expect(backend.calls, isEmpty);

      backend.offline = false;
      await n.sync();
      expect(backend.calls, ['+mara']);
      expect(backend.remote, {'mara'});
    });

    test('unfollow and restore keep the original date', () async {
      final backend = _FakeBackend();
      final n = CreatorFollowsNotifier(userId: 'me', backend: backend);
      await n.load();
      await n.follow('mara', name: 'Mara Köhler');
      final before = n.state.followed['mara']!;
      await n.unfollow('mara');
      expect(n.state.isFollowing('mara'), isFalse);
      await n.restore(before);
      expect(n.state.followed['mara']?.followedAt, before.followedAt);
    });

    test('server follows from the other device are taken over', () async {
      final backend = _FakeBackend(remote: {'deniz'});
      final n = CreatorFollowsNotifier(userId: 'me', backend: backend);
      await n.load();
      await n.sync();
      expect(n.state.isFollowing('deniz'), isTrue);
      await n.markSeen('deniz', name: 'Deniz Aydın');
      expect(n.state.followed['deniz']?.name, 'Deniz Aydın');
    });

    test('nobody follows themselves', () async {
      final n = CreatorFollowsNotifier(userId: 'me', backend: _FakeBackend());
      await n.load();
      await n.follow('me', name: 'Ich');
      expect(n.state.followed, isEmpty);
    });
  });
}
