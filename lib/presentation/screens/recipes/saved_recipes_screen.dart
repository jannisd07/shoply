import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_saved.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// The saved recipes to show: the loaded ones still saved, recipes brought
/// back by "Widerrufen" before the reload has them (at their old place), and
/// on the very first open the saved ids found in the catalogue.
List<Recipe> visibleSavedRecipes(
  LibrarySaved saved, {
  List<Recipe>? catalog,
  Map<String, (int, Recipe)> restoring = const {},
}) {
  final list = [
    for (final r in saved.recipes)
      if (saved.ids.contains(r.id)) r,
  ];
  final present = {for (final r in list) r.id};
  final back =
      restoring.entries
          .where((e) => saved.ids.contains(e.key) && !present.contains(e.key))
          .toList()
        ..sort((a, b) => a.value.$1.compareTo(b.value.$1));
  for (final e in back) {
    final at = e.value.$1.clamp(0, list.length);
    list.insert(at, e.value.$2);
    present.add(e.key);
  }
  if (list.isEmpty && saved.recipes.isEmpty && catalog != null) {
    return [
      for (final r in catalog)
        if (saved.ids.contains(r.id)) r,
    ];
  }
  return list;
}

/// R-07 "Gespeichert" (Konzept 13 §9): what did I want to cook?
///
/// Shows the saved recipes at once (provider state, else the catalogue),
/// reloads behind them, never empties the list because of a network error
/// it can see (no reload while offline). Removing is a swipe or a menu
/// entry and can be undone.
class SavedRecipesScreen extends ConsumerStatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  ConsumerState<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends ConsumerState<SavedRecipesScreen>
    with LibraryAvoContext {
  final _search = TextEditingController();
  String _query = '';

  /// Removed rows by id with their place, so "Widerrufen" puts them back
  /// before the reload knows them again.
  final Map<String, (int, Recipe)> _restoring = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(isOfflineProvider)) {
        unawaited(ref.read(recipeLibraryActionsProvider).reloadSaved());
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(isOfflineProvider)) return;
    await ref.read(recipeLibraryActionsProvider).reloadSaved();
  }

  Future<void> _remove(Recipe recipe, int index) async {
    final actions = ref.read(recipeLibraryActionsProvider);
    setState(() => _restoring[recipe.id] = (index, recipe));
    final toastContext = context;
    final message = context.tr('recipe_lib_removed');
    final undo = context.tr('common_undo');
    final failedText = context.tr('action_failed');
    final ok = await actions.toggleSaved(recipe.id);
    if (!ok) {
      unawaited(AvoHaptics.error());
      if (toastContext.mounted) {
        AvoToast.show(toastContext, message: failedText);
      }
      return;
    }
    if (!toastContext.mounted) return;
    AvoToast.show(
      toastContext,
      message: message,
      actionLabel: undo,
      onAction: () async {
        final saved = await actions.toggleSaved(recipe.id);
        if (!saved && toastContext.mounted) {
          unawaited(AvoHaptics.error());
          AvoToast.show(toastContext, message: failedText);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    syncAvoContext(context);
    final saved = ref.watch(librarySavedProvider);
    final catalog = ref.watch(libraryCatalogProvider);
    final offline = ref.watch(isOfflineProvider);
    final allergies = ref.watch(libraryAllergiesProvider);
    final recipes = visibleSavedRecipes(
      saved,
      catalog: catalog,
      restoring: _restoring,
    );
    final phase = recipes.isEmpty && saved.loading && saved.recipes.isEmpty
        ? LibraryPhase.loading
        : LibraryPhase.ready;

    return RecipesLibraryPage(
      title: context.tr('recipe_lib_saved_title'),
      subtitle: recipes.isEmpty
          ? null
          : formatRecipeCount(context, recipes.length),
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(
          child: SavedRecipesContent(
            phase: phase,
            recipes: recipes,
            query: _query,
            searchController: _search,
            onQueryChanged: (q) => setState(() => _query = q),
            offline: offline,
            allergensOf: (r) => libraryAllergenNames(context, r, allergies),
            onOpen: (r) => context.push(RoutePaths.recipe(r.id), extra: r),
            onOpenAuthor: (r) => context.push(
              creatorPath(r.authorId),
              extra: {'authorName': r.authorName},
            ),
            onRemove: (r) => _remove(r, recipes.indexOf(r)),
            onDiscover: () => context.go(RoutePaths.recipes),
          ),
        ),
      ],
    );
  }
}
