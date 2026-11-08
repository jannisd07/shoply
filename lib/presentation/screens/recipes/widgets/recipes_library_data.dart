import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/recipe_draft_images.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Data and helpers shared by the recipe library screens (Konzept 13 §7–§11:
/// Ersteller, Ersteller-Seite, Gespeichert, Meine Rezepte, Entwürfe).
///
/// Screens read everything through the providers here, so widget tests can
/// override them without Supabase.

// ------------------------------------------------------------------ phase

/// What a library screen can show right now.
enum LibraryPhase {
  /// Nothing known yet (first open without a local state): skeleton.
  loading,

  /// Content is known (it may be empty).
  ready,

  /// Loading failed and nothing is known: status row with retry.
  error,
}

// --------------------------------------------------------------- providers

/// The recipe catalogue as far as it is known: the loaded
/// [recipesProvider], else the offline cache that was warmed before the
/// first frame. Null when neither is available yet.
final libraryCatalogProvider = Provider<List<Recipe>?>((ref) {
  final loaded = ref.watch(recipesProvider).valueOrNull;
  return loaded ?? OfflineCacheService.instance.getCachedRecipesSync();
});

/// The catalogue could not be loaded and nothing is cached.
final libraryCatalogFailedProvider = Provider<bool>((ref) {
  final async = ref.watch(recipesProvider);
  return async.hasError && ref.watch(libraryCatalogProvider) == null;
});

/// One creator with the numbers the creator list shows.
@immutable
class LibraryCreator {
  const LibraryCreator({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.recipes,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  /// The creator's recipes in the catalogue, newest first.
  final List<Recipe> recipes;

  int get recipeCount => recipes.length;

  /// Mean of the rated recipes' ratings, 0 when none is rated.
  double get averageRating {
    final rated = [
      for (final r in recipes)
        if (r.ratingCount > 0) r.averageRating,
    ];
    return rated.isEmpty ? 0 : rated.reduce((a, b) => a + b) / rated.length;
  }

  /// Popularity and quality, as the tab ranks creators: recipes × 10,
  /// views × 0.1, ratings × 2, mean rating × 5.
  double get score {
    final views = recipes.fold<int>(0, (s, r) => s + r.viewCount);
    final ratings = recipes.fold<int>(0, (s, r) => s + r.ratingCount);
    return recipes.length * 10 + views * 0.1 + ratings * 2 + averageRating * 5;
  }
}

/// Creators of [catalog], best ranked first (imported recipes have no
/// creator and are left out).
List<LibraryCreator> rankCreators(List<Recipe> catalog) {
  final byAuthor = <String, List<Recipe>>{};
  for (final r in catalog) {
    if (r.authorId.isEmpty || r.isImported) continue;
    byAuthor.putIfAbsent(r.authorId, () => []).add(r);
  }
  final creators = [
    for (final e in byAuthor.entries)
      LibraryCreator(
        id: e.key,
        name: e.value.first.authorName,
        avatarUrl: e.value.first.authorAvatarUrl,
        recipes: e.value..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return creators;
}

/// The person's allergies as stored in the profile (enum names or free
/// text), for the warnings on cards (Konzept 13 §2.3).
final libraryAllergiesProvider = Provider<List<String>>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.allergies ?? const [];
});

/// The saved recipes of the account (from [savedRecipesProvider]).
@immutable
class LibrarySaved {
  const LibrarySaved({
    this.ids = const {},
    this.recipes = const [],
    this.loading = false,
  });

  /// Ids saved right now (optimistic).
  final Set<String> ids;

  /// Full recipes in save order, newest first, from the last load.
  final List<Recipe> recipes;

  /// A load is running.
  final bool loading;
}

/// Saved ids and recipes, derived from [savedRecipesProvider].
final librarySavedProvider = Provider<LibrarySaved>((ref) {
  final state = ref.watch(savedRecipesProvider);
  return LibrarySaved(
    ids: state.savedIds,
    recipes: state.savedRecipes,
    loading: state.isLoading,
  );
});

/// Everything the library screens do that leaves the screen: loading,
/// deleting, sharing, saving. One object so tests can swap it.
class RecipeLibraryActions {
  RecipeLibraryActions(this._ref);

  final Ref _ref;

  RecipeService get _recipes => RecipeService.instance;

  /// The signed-in person's own recipes, newest first.
  Future<List<Recipe>> myRecipes() => _recipes.getMyRecipes();

  /// All recipes of one creator, newest first.
  Future<List<Recipe>> recipesBy(String authorId) =>
      _recipes.getRecipesByAuthor(authorId);

  /// Deletes an own recipe for everyone. Throws when it failed.
  Future<void> deleteRecipe(String recipeId) async {
    await _recipes.deleteRecipe(recipeId);
    catalogChanged();
  }

  /// Tells every recipe screen that the catalogue changed (the tab, Alle,
  /// Kategorie and Ersteller read it again).
  void catalogChanged() {
    _ref.read(recipeRefreshTriggerProvider.notifier).state++;
    _ref.invalidate(recipesProvider);
  }

  /// Loads the catalogue again and completes when it is there (pull to
  /// refresh); a failure keeps the cached state.
  Future<void> reloadCatalog() async {
    catalogChanged();
    try {
      await _ref.read(recipesProvider.future);
    } catch (e) {
      debugPrint('⚠️ [RECIPE_LIBRARY] Catalogue reload failed: $e');
    }
  }

  /// Reloads the saved recipes in the background.
  Future<void> reloadSaved() =>
      _ref.read(savedRecipesProvider.notifier).loadSavedRecipes();

  /// Saves or unsaves [recipeId]; false when it failed.
  Future<bool> toggleSaved(String recipeId) =>
      _ref.read(savedRecipesProvider.notifier).toggleSave(recipeId);

  /// Local drafts, newest first, with their photo path resolved for this
  /// app container (it changes across updates).
  Future<List<RecipeDraft>> drafts() async {
    final stored = await RecipeDraftService().getDrafts();
    return Future.wait(
      stored.map((draft) async {
        final image = await RecipeDraftImages.resolve(draft.localImagePath);
        if (image?.path == draft.localImagePath) return draft;
        return RecipeDraft(
          id: draft.id,
          name: draft.name,
          description: draft.description,
          localImagePath: image?.path,
          prepTimeMinutes: draft.prepTimeMinutes,
          cookTimeMinutes: draft.cookTimeMinutes,
          defaultServings: draft.defaultServings,
          ingredients: draft.ingredients,
          instructions: draft.instructions,
          createdAt: draft.createdAt,
          updatedAt: draft.updatedAt,
        );
      }),
    );
  }

  /// Deletes a draft and its stored photo.
  Future<void> deleteDraft(RecipeDraft draft) async {
    await RecipeDraftService().deleteDraft(draft.id);
    await RecipeDraftImages.delete(draft.localImagePath);
  }

  /// Opens the share sheet of iOS for [recipe].
  Future<void> shareRecipe(Recipe recipe, {Rect? origin}) async {
    await Share.share(
      _recipes.getShareText(recipe),
      subject: recipe.name,
      sharePositionOrigin: origin,
    );
  }
}

/// The actions of the library screens.
final recipeLibraryActionsProvider = Provider<RecipeLibraryActions>(
  RecipeLibraryActions.new,
);

// -------------------------------------------------------------- Avo context

/// Tells Avo that the person is in the recipes area while a library screen
/// is the current route, and clears it again when the screen goes away
/// (A6 brief: `AvoScreenContext(screen: 'recipes')`).
mixin LibraryAvoContext<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _mine = AvoScreenContext(screen: 'recipes');

  late final StateController<AvoScreenContext?> _avo;
  bool _wasCurrent = false;

  @override
  void initState() {
    super.initState();
    _avo = ref.read(avoScreenContextProvider.notifier);
  }

  /// Call from build: sets the context whenever the route becomes current
  /// again (after the detail on top was closed).
  void syncAvoContext(BuildContext context) {
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_wasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _avo.state = _mine;
      });
    }
    _wasCurrent = current;
  }

  @override
  void dispose() {
    final avo = _avo;
    Future.microtask(() {
      try {
        if (avo.state == _mine) avo.state = null;
      } catch (_) {
        // The provider scope is gone (app or test shut down).
      }
    });
    super.dispose();
  }
}

// --------------------------------------------------------------- formatting

/// "4,6" in German, "4.6" in English.
String formatRating(BuildContext context, double rating) {
  final locale = Localizations.localeOf(context).languageCode;
  return NumberFormat('0.0', locale).format(rating);
}

/// "35 Min", "1 Std. 10 Min", "2 Std." (Konzept 13 §2.2).
String formatDuration(BuildContext context, int minutes) {
  if (minutes < 60) {
    return context.tr('recipe_lib_minutes', params: {'n': '$minutes'});
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return context.tr('recipe_lib_hours', params: {'h': '$h'});
  return context.tr('recipe_lib_hours_minutes', params: {'h': '$h', 'm': '$m'});
}

/// "1 Rezept", "24 Rezepte".
String formatRecipeCount(BuildContext context, int count) => count == 1
    ? context.tr('recipe_lib_count_one')
    : context.tr('recipe_lib_count', params: {'n': '$count'});

/// "4,6 (23)": the rating with its count, without a star (Konzept 13 §10.1).
String? formatRatingWithCount(BuildContext context, Recipe recipe) {
  if (recipe.ratingCount <= 0) return null;
  return '${formatRating(context, recipe.averageRating)} '
      '(${recipe.ratingCount})';
}

/// "vor 3 Tagen", "gestern", "vor 2 Std." relative to [now].
String formatAgo(BuildContext context, DateTime date, DateTime now) {
  final diff = now.difference(date);
  String t(String key, int n) => context.tr(key, params: {'n': '$n'});
  if (diff.inMinutes < 1) return context.tr('recipe_lib_ago_now');
  if (diff.inMinutes < 60) return t('recipe_lib_ago_minutes', diff.inMinutes);
  if (diff.inHours < 24) return t('recipe_lib_ago_hours', diff.inHours);
  final days = diff.inDays;
  if (days < 2) return context.tr('recipe_lib_ago_yesterday');
  if (days < 7) return t('recipe_lib_ago_days', days);
  if (days < 14) return context.tr('recipe_lib_ago_week_one');
  if (days < 30) return t('recipe_lib_ago_weeks', days ~/ 7);
  if (days < 60) return context.tr('recipe_lib_ago_month_one');
  if (days < 365) return t('recipe_lib_ago_months', days ~/ 30);
  if (days < 730) return context.tr('recipe_lib_ago_year_one');
  return t('recipe_lib_ago_years', days ~/ 365);
}

/// Meta line of a grid card: "35 Min · ★ 4,6" (D2-Rezepte).
String recipeCardMeta(BuildContext context, Recipe recipe) => joinMeta([
  if (recipe.totalTimeMinutes > 0)
    formatDuration(context, recipe.totalTimeMinutes),
  if (recipe.ratingCount > 0)
    '★ ${formatRating(context, recipe.averageRating)}',
]);

/// What VoiceOver reads for a card: "Avocado-Pasta, 15 Minuten,
/// Bewertung 4,5" instead of the star.
String recipeCardVoice(BuildContext context, Recipe recipe) => [
  recipe.name,
  if (recipe.totalTimeMinutes > 0)
    context.tr(
      'recipe_lib_minutes_voice',
      params: {'n': '${recipe.totalTimeMinutes}'},
    ),
  if (recipe.ratingCount > 0)
    context.tr(
      'recipe_lib_rating_voice',
      params: {'rating': formatRating(context, recipe.averageRating)},
    ),
].join(', ');

/// Joins meta parts with " · ", skipping empty ones.
String joinMeta(Iterable<String?> parts) =>
    parts.whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');

// ------------------------------------------------------------------ drafts

/// What a draft still needs before it can be published, in the order the
/// editor asks for it. Empty when it is complete
/// ([RecipeDraft.isComplete]).
List<String> draftMissingKeys(RecipeDraft draft) {
  return [
    if (draft.name.trim().isEmpty) 'recipe_lib_part_title',
    if (draft.description.trim().isEmpty) 'recipe_lib_part_description',
    if (draft.localImagePath == null) 'recipe_lib_part_photo',
    if (draft.prepTimeMinutes == null || draft.cookTimeMinutes == null)
      'recipe_lib_part_times',
    if (draft.defaultServings == null) 'recipe_lib_part_servings',
    if (draft.ingredients.isEmpty ||
        !draft.ingredients.every(
          (i) => i.name.isNotEmpty && i.amount.isNotEmpty && i.unit.isNotEmpty,
        ))
      'recipe_lib_part_ingredients',
    if (!draft.instructions.any((s) => s.trim().isNotEmpty))
      'recipe_lib_part_steps',
  ];
}

/// "Bereit zum Veröffentlichen", "Es fehlen: Zutaten, Anleitung", or with
/// more than three gaps "Es fehlen: Titel, Beschreibung und 5 weitere".
String draftStatus(BuildContext context, RecipeDraft draft) {
  final missing = draftMissingKeys(draft);
  if (missing.isEmpty) return context.tr('recipe_lib_ready');
  if (missing.length > 3) {
    return context.tr(
      'recipe_lib_missing_more',
      params: {
        'parts': missing.take(2).map(context.tr).join(', '),
        'n': '${missing.length - 2}',
      },
    );
  }
  return context.tr(
    'recipe_lib_missing',
    params: {'parts': missing.map(context.tr).join(', ')},
  );
}

/// The draft's name or "Unbenannter Entwurf".
String draftTitle(BuildContext context, RecipeDraft draft) {
  final name = draft.name.trim();
  return name.isEmpty ? context.tr('recipe_lib_untitled') : name;
}

// --------------------------------------------------------------- navigation

/// Editor path for an own recipe. The query carries the id for the router;
/// the route of the "browse" part reads it from `extra` today.
String editRecipePath(String recipeId) => Uri(
  path: '/recipes/add',
  queryParameters: {'recipeId': recipeId},
).toString();

/// Editor path for a draft ("Weiterschreiben").
String continueDraftPath(String draftId) =>
    Uri(path: '/recipes/add', queryParameters: {'draftId': draftId}).toString();

/// Path of a creator page.
String creatorPath(String authorId) => '/author/$authorId';
