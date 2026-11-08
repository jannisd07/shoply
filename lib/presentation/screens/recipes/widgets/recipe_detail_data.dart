import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/cooking_mode_screen.dart';
import 'package:shoply/presentation/screens/recipes/widgets/select_list_bottom_sheet.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

// Data and actions of the recipe detail (Konzept 13 §12), apart from the
// widgets so tests can replace them.

/// Link that opens a recipe in the app or on the web (Konzept 13 §12.4).
String recipeShareLink(String recipeId) =>
    'https://shoplyai.app/recipe/$recipeId';

/// Everything the detail does outside itself. Tests override
/// [recipeDetailActionsProvider] with a recorder.
class RecipeDetailActions {
  const RecipeDetailActions();

  /// The full recipe from the server.
  Future<Recipe> load(String recipeId) =>
      RecipeService.instance.getRecipeById(recipeId);

  /// Whether [error] from [load] means the recipe is gone (deleted or
  /// private) rather than a failed request.
  bool isNotFound(Object error) =>
      error.toString().contains('Recipe not found');

  /// A recipe some list already loaded this session (Rezepte tab, saved).
  Recipe? known(WidgetRef ref, String recipeId) {
    final all = ref.read(recipesProvider).valueOrNull ?? const <Recipe>[];
    for (final r in all) {
      if (r.id == recipeId) return r;
    }
    for (final r in ref.read(savedRecipesProvider).savedRecipes) {
      if (r.id == recipeId) return r;
    }
    return null;
  }

  /// The recipe from the device's offline cache, if it was ever stored.
  Future<Recipe?> onDevice(String recipeId) async {
    final cached = await OfflineCacheService.instance.getCachedRecipes();
    for (final r in cached) {
      if (r.id == recipeId) return r;
    }
    return null;
  }

  /// Counts one view (fire and forget).
  Future<void> trackView(String recipeId) =>
      RecipeService.instance.trackRecipeView(recipeId);

  Future<void> rate(String recipeId, int stars) =>
      RecipeService.instance.rateRecipe(recipeId, stars);

  Future<void> delete(String recipeId) =>
      RecipeService.instance.deleteRecipe(recipeId);

  /// Saves or unsaves the recipe (optimistic in the provider).
  Future<void> toggleSave(WidgetRef ref, String recipeId) async {
    await ref.read(savedRecipesProvider.notifier).toggleSave(recipeId);
  }

  /// The system share sheet from the share button (no emoji, localised).
  Future<void> share(BuildContext context, Recipe recipe, Rect? origin) async {
    final author = recipe.authorName.trim();
    final intro = recipe.isImported || author.isEmpty
        ? context.tr(
            'recipe_detail_share_text_plain',
            params: {'name': recipe.name},
          )
        : context.tr(
            'recipe_detail_share_text',
            params: {'name': recipe.name, 'author': author},
          );
    await Share.share(
      '$intro ${recipeShareLink(recipe.id)}',
      subject: recipe.name,
      sharePositionOrigin: origin,
    );
  }

  /// Opens the editor for an own recipe; true when it was saved.
  Future<bool> edit(BuildContext context, String recipeId) async {
    final saved = await context.push<bool>(
      '${RoutePaths.recipes}/add?recipeId=$recipeId',
      extra: {'recipeId': recipeId},
    );
    return saved == true;
  }

  /// The creator page (Konzept 13 §7).
  void openAuthor(BuildContext context, Recipe recipe) {
    unawaited(
      context.push(
        '/author/${recipe.authorId}',
        extra: {'authorName': recipe.authorName},
      ),
    );
  }

  /// The cooking mode with [recipe] as the person cooks it (adapted when
  /// chosen); goes through the Pro gate (nothing gated until A9).
  Future<void> cook(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
    int servings,
  ) async {
    await ProGate.run(
      context,
      ref,
      feature: kCookModeFeature,
      action: () =>
          openCookingMode(context, recipe: recipe, servings: servings),
    );
  }

  /// "Zutaten auf die Liste" as a full screen.
  Future<void> openToList(
    BuildContext context,
    Recipe recipe,
    int servings, {
    required bool adapted,
  }) => openIngredientsToList(
    context,
    recipe: recipe,
    servings: servings,
    adapted: adapted,
  );

  /// Teil B's "Ins Tagebuch eintragen".
  Future<void> logRecipe(BuildContext context, Recipe recipe) =>
      openLogRecipe(context, recipe);

  /// The source page of an imported recipe, in Safari.
  Future<void> openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Prepares a report mail; false when no mail app opened.
  Future<bool> report({required String subject, required String body}) async {
    final uri = Uri.parse(
      'mailto:${LegalLinks.supportEmail}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('⚠️ [RECIPE_DETAIL] Mail not opened: $e');
      return false;
    }
  }

  /// Back to where the person came from; the Rezepte tab after a deep link.
  void back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(RoutePaths.recipes);
    }
  }

  /// The Rezepte tab (from "Dieses Rezept gibt es nicht mehr").
  void openRecipes(BuildContext context) => context.go(RoutePaths.recipes);

  /// A new shopping list ("Neue Liste" in "Zutaten auf die Liste").
  Future<ShoppingListModel> createList(
    ProviderContainer container,
    String name,
  ) => container.read(listsNotifierProvider.notifier).createList(name);

  /// The lists (open counts) and the items of [listId] load again.
  void refreshList(ProviderContainer container, String listId) {
    if (container.exists(itemsNotifierProvider(listId))) {
      unawaited(
        container.read(itemsNotifierProvider(listId).notifier).loadItems(),
      );
    }
    unawaited(
      container.read(listsNotifierProvider.notifier).loadLists().catchError((
        Object e,
      ) {
        debugPrint('⚠️ [RECIPE_TO_LIST] Lists not refreshed: $e');
      }),
    );
  }

  /// Lists, cards and the saved tab load again (rating, delete).
  void refreshRecipes(ProviderContainer container) {
    container.read(recipeRefreshTriggerProvider.notifier).state++;
  }
}

final recipeDetailActionsProvider = Provider<RecipeDetailActions>(
  (ref) => const RecipeDetailActions(),
);

// ------------------------------------------------------- remembered choices

String _servingsKey(String recipeId) => 'recipe_servings_$recipeId';
String _targetListKey(String recipeId) => 'recipe_target_list_$recipeId';

/// Servings chosen for a recipe, kept per recipe on this device (Konzept 13
/// §12.4); null until the person changed them.
final recipeServingsProvider = StateProvider.family<int?, String>((
  ref,
  recipeId,
) {
  final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
  return prefs?.getInt(_servingsKey(recipeId));
});

/// Remembers [servings] for [recipeId].
void rememberRecipeServings(WidgetRef ref, String recipeId, int servings) {
  ref.read(recipeServingsProvider(recipeId).notifier).state = servings;
  final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
  unawaited(
    prefs?.setInt(_servingsKey(recipeId), servings).catchError((_) => false),
  );
}

/// The list last chosen in "Zutaten auf die Liste" for a recipe.
final recipeChosenListProvider = StateProvider.family<String?, String>((
  ref,
  recipeId,
) {
  final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
  return prefs?.getString(_targetListKey(recipeId));
});

/// Remembers [listId] as the target of [recipeId].
void rememberRecipeTargetList(
  ProviderContainer container,
  String recipeId,
  String listId,
) {
  container.read(recipeChosenListProvider(recipeId).notifier).state = listId;
  final prefs = container.read(sharedPreferencesProvider).valueOrNull;
  unawaited(
    prefs?.setString(_targetListKey(recipeId), listId).catchError((_) => false),
  );
}

/// The signed-in person's lists, newest change first; empty while unknown.
final recipeTargetListsProvider = Provider<List<ShoppingListModel>>((ref) {
  final lists = ref.watch(listsNotifierProvider).valueOrNull;
  if (lists == null) return const [];
  return [...lists]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

/// Where a recipe's ingredients go (Konzept 13 §12.1 Nr. 7): the list last
/// chosen for this recipe, else the list of today (the one opened last),
/// else the one changed last; null without lists.
final recipeTargetListProvider = Provider.family<ShoppingListModel?, String>((
  ref,
  recipeId,
) {
  final lists = ref.watch(recipeTargetListsProvider);
  if (lists.isEmpty) return null;
  ShoppingListModel? byId(String? id) {
    if (id == null) return null;
    for (final l in lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  return byId(ref.watch(recipeChosenListProvider(recipeId))) ??
      byId(ref.watch(lastAccessedListProvider).valueOrNull) ??
      lists.first;
});

/// The open items of [listId], or null while they are not loaded
/// ("Schon auf Wocheneinkauf" shows only with data).
final recipeListOpenItemsProvider =
    Provider.family<List<ShoppingItemModel>?, String>((ref, listId) {
      final items = ref.watch(itemsNotifierProvider(listId)).valueOrNull;
      if (items == null) return null;
      return [
        for (final i in items)
          if (!i.isChecked) i,
      ];
    });
