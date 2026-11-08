import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_features_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';

// ---------------------------------------------------------------- catalogue

/// The recipe catalogue warmed before `runApp` (OfflineCacheService), read
/// once. Overridden in tests.
final recipeCatalogueSeedProvider = Provider<List<Recipe>?>(
  (ref) => OfflineCacheService.instance.getCachedRecipesSync(),
);

/// What the browse screens know about the catalogue.
@immutable
class RecipeCatalogue {
  const RecipeCatalogue({
    this.recipes = const [],
    this.known = false,
    this.refreshFailed = false,
  });

  /// The recipes, local first, replaced by the server's answer.
  final List<Recipe> recipes;

  /// Something is known (local state or an answer). False only on the very
  /// first start before the first answer: placeholders, never a spinner.
  final bool known;

  /// The last refresh failed; [recipes] is the older local state.
  final bool refreshFailed;
}

/// Keeps the last good catalogue: a failed refresh (an error or the empty
/// list `RecipeService.getRecipes` returns offline) never empties the tab
/// (Konzept 13 §2.1).
class RecipeCatalogueNotifier extends StateNotifier<RecipeCatalogue> {
  RecipeCatalogueNotifier(List<Recipe>? seed)
    : super(
        RecipeCatalogue(
          recipes: seed ?? const [],
          known: seed != null && seed.isNotEmpty,
        ),
      );

  void apply(AsyncValue<List<Recipe>> next) {
    if (next.hasValue) {
      final fresh = next.requireValue;
      if (fresh.isEmpty && state.recipes.isNotEmpty) {
        state = RecipeCatalogue(
          recipes: state.recipes,
          known: true,
          refreshFailed: true,
        );
      } else {
        state = RecipeCatalogue(recipes: fresh, known: true);
      }
    } else if (next.hasError) {
      state = RecipeCatalogue(
        recipes: state.recipes,
        known: true,
        refreshFailed: true,
      );
    }
  }
}

/// The catalogue of the browse screens: the local state in frame 1, then
/// [recipesProvider].
final recipeCatalogueProvider =
    StateNotifierProvider<RecipeCatalogueNotifier, RecipeCatalogue>((ref) {
      final notifier = RecipeCatalogueNotifier(
        ref.read(recipeCatalogueSeedProvider),
      );
      ref.listen<AsyncValue<List<Recipe>>>(
        recipesProvider,
        (_, next) => notifier.apply(next),
        fireImmediately: true,
      );
      return notifier;
    });

/// Reloads the catalogue and waits for the answer (pull to refresh).
Future<void> refreshRecipeCatalogue(WidgetRef ref) async {
  ref.invalidate(recipesProvider);
  try {
    await ref.read(recipesProvider.future);
  } catch (e) {
    debugPrint('⚠️ [RECIPES] Refresh failed: $e');
  }
}

// ------------------------------------------------------------- diet profile

/// The person's allergies and diet (Konzept 13 §2.3).
final recipeDietProfileProvider = Provider<RecipeDietProfile>(
  (ref) => RecipeDietProfile.of(ref.watch(currentUserProvider).valueOrNull),
);

/// True once the profile is known (or there is nobody signed in), so the tab
/// can fix "Für dich" only after allergies are taken into account.
final recipeDietProfileKnownProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.hasValue || user.hasError;
});

/// How every recipe of the catalogue fits the person, by id (recipes without
/// remarks are missing).
final recipeFitsProvider = Provider<Map<String, RecipeFit>>((ref) {
  final recipes = ref.watch(recipeCatalogueProvider.select((c) => c.recipes));
  return recipeFitsFor(recipes, ref.watch(recipeDietProfileProvider));
});

// --------------------------------------------------------------- list match

/// Stems of the open items of the person's main list (the big card of the
/// Listen tab: pinned, else last opened, else last used), from the local
/// item cache only, for "Passt zu deiner Liste".
final recipeListItemStemsProvider = Provider<List<Set<String>>>((ref) {
  final lists = ref.watch(allListsSourceProvider).valueOrNull;
  if (lists == null || lists.isEmpty) return const [];
  final hero = pickHeroList(
    lists,
    pinnedId: ref.watch(pinnedListProvider).listId,
    lastOpenedId: ref.watch(lastAccessedListProvider).valueOrNull,
  );
  if (hero == null) return const [];
  final items = OfflineCacheService.instance.getCachedListItemsSync(hero.id);
  if (items == null) return const [];
  return [
    for (final item in items)
      if (!item.isChecked) nameStems(item.name),
  ];
});

// ---------------------------------------------------------------- highlights

/// The server's "Beliebt diese Woche" ranking and "Rezept der Woche", kept on
/// the device so the tab shows them in frame 1.
@immutable
class RecipeHighlights {
  const RecipeHighlights({this.popularIds = const [], this.weekId});

  final List<String> popularIds;
  final String? weekId;

  Map<String, Object?> toJson() => {'popular': popularIds, 'week': weekId};

  static RecipeHighlights? fromJson(Object? json) {
    if (json is! Map) return null;
    final popular = json['popular'];
    final week = json['week'];
    return RecipeHighlights(
      popularIds: popular is List
          ? popular.whereType<String>().toList()
          : const [],
      weekId: week is String ? week : null,
    );
  }
}

/// Popular recipes fetched for the tab and the popular page.
const int kPopularFetchLimit = 50;

/// Loads [RecipeHighlights] from the server; null when nothing came back.
/// Overridden in tests.
final recipeHighlightsLoaderProvider =
    Provider<Future<RecipeHighlights?> Function()>(
      (ref) => () async {
        final results = await Future.wait<Object?>([
          RecipeService.instance.getPopularRecipes(
            limit: kPopularFetchLimit,
            thisWeekOnly: true,
          ),
          RecipeFeaturesService.instance.getRecipeOfTheWeek(),
        ]);
        final popular = results[0] as List<Recipe>;
        final week = results[1] as Recipe?;
        if (popular.isEmpty && week == null) return null;
        return RecipeHighlights(
          popularIds: [for (final r in popular) r.id],
          weekId: week?.id,
        );
      },
    );

// -------------------------------------------------------- device preferences

/// What the browse screens remember on this device, per account.
@immutable
class RecipesBrowsePrefs {
  const RecipesBrowsePrefs({
    this.recentSearches = const [],
    this.dietHintDismissed = false,
    this.highlights,
  });

  /// Newest first, at most [kRecentSearchCount].
  final List<String> recentSearches;

  /// The diet tip was wiped away (never again).
  final bool dietHintDismissed;

  /// The last server highlights.
  final RecipeHighlights? highlights;

  RecipesBrowsePrefs copyWith({
    List<String>? recentSearches,
    bool? dietHintDismissed,
    RecipeHighlights? highlights,
  }) => RecipesBrowsePrefs(
    recentSearches: recentSearches ?? this.recentSearches,
    dietHintDismissed: dietHintDismissed ?? this.dietHintDismissed,
    highlights: highlights ?? this.highlights,
  );
}

/// "Zuletzt gesucht" keeps this many queries.
const int kRecentSearchCount = 5;

class RecipesBrowsePrefsNotifier extends StateNotifier<RecipesBrowsePrefs> {
  RecipesBrowsePrefsNotifier(this._userId, SharedPreferences? prefs)
    : _prefs = prefs,
      super(_read(prefs, _userId));

  final String? _userId;
  SharedPreferences? _prefs;

  String get _key => 'recipes_browse_v1_${_userId ?? 'anon'}';

  static RecipesBrowsePrefs _read(SharedPreferences? prefs, String? userId) {
    final raw = prefs?.getString('recipes_browse_v1_${userId ?? 'anon'}');
    if (raw == null) return const RecipesBrowsePrefs();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const RecipesBrowsePrefs();
      final recent = json['recent'];
      return RecipesBrowsePrefs(
        recentSearches: recent is List
            ? recent.whereType<String>().take(kRecentSearchCount).toList()
            : const [],
        dietHintDismissed: json['dietHintDismissed'] == true,
        highlights: RecipeHighlights.fromJson(json['highlights']),
      );
    } catch (e) {
      debugPrint('⚠️ [RECIPES] Could not read browse prefs: $e');
      return const RecipesBrowsePrefs();
    }
  }

  /// Late preferences (not preloaded, as in tests): read them once.
  void attach(SharedPreferences prefs) {
    if (_prefs != null) return;
    _prefs = prefs;
    if (!mounted) return;
    final stored = _read(prefs, _userId);
    state = RecipesBrowsePrefs(
      recentSearches: state.recentSearches.isNotEmpty
          ? state.recentSearches
          : stored.recentSearches,
      dietHintDismissed: state.dietHintDismissed || stored.dietHintDismissed,
      highlights: state.highlights ?? stored.highlights,
    );
  }

  void addRecentSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final lower = q.toLowerCase();
    _set(
      state.copyWith(
        recentSearches: [
          q,
          for (final s in state.recentSearches)
            if (s.toLowerCase() != lower) s,
        ].take(kRecentSearchCount).toList(),
      ),
    );
  }

  void removeRecentSearch(String query) => _set(
    state.copyWith(
      recentSearches: [
        for (final s in state.recentSearches)
          if (s != query) s,
      ],
    ),
  );

  void clearRecentSearches() => _set(state.copyWith(recentSearches: const []));

  void dismissDietHint() => _set(state.copyWith(dietHintDismissed: true));

  void saveHighlights(RecipeHighlights highlights) =>
      _set(state.copyWith(highlights: highlights));

  void _set(RecipesBrowsePrefs next) {
    state = next;
    final prefs = _prefs;
    if (prefs == null) return;
    final json = jsonEncode({
      'recent': next.recentSearches,
      'dietHintDismissed': next.dietHintDismissed,
      'highlights': next.highlights?.toJson(),
    });
    unawaited(
      prefs.setString(_key, json).catchError((Object e) {
        debugPrint('⚠️ [RECIPES] Could not save browse prefs: $e');
        return false;
      }),
    );
  }
}

/// Device preferences of the browse screens, per account. Read from the
/// preferences `main()` preloads, so they are there in frame 1.
final recipesBrowsePrefsProvider =
    StateNotifierProvider<RecipesBrowsePrefsNotifier, RecipesBrowsePrefs>((
      ref,
    ) {
      final userId = ref.watch(authUserIdProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      final notifier = RecipesBrowsePrefsNotifier(userId, prefs.valueOrNull);
      if (!prefs.hasValue) {
        unawaited(
          ref
              .read(sharedPreferencesProvider.future)
              .then(notifier.attach)
              .catchError((Object e) {
                debugPrint('⚠️ [RECIPES] Preferences unavailable: $e');
              }),
        );
      }
      return notifier;
    });
