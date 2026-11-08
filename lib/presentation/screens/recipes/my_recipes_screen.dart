import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_mine.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// R-08 "Meine Rezepte" (Konzept 13 §10): what did I write, and how is it
/// received?
///
/// Own recipes show at once from the catalogue and load in full behind it.
/// "Bearbeiten" opens the editor with the recipe, "Löschen" asks first and
/// removes the row at once (it comes back if the server says no). The plus
/// in the toolbar writes a new recipe.
class MyRecipesScreen extends ConsumerStatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  ConsumerState<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends ConsumerState<MyRecipesScreen>
    with LibraryAvoContext {
  List<Recipe>? _recipes;
  bool _failed = false;
  int _draftCount = 0;

  /// Deleted here and not confirmed by the server yet.
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final actions = ref.read(recipeLibraryActionsProvider);
    try {
      final (recipes, drafts) = await (
        actions.myRecipes(),
        actions.drafts(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _draftCount = drafts.length;
        // The service answers an empty list when it fails; offline that
        // must not replace what is on screen.
        if (recipes.isNotEmpty || !ref.read(isOfflineProvider)) {
          _recipes = recipes;
        }
        _failed = false;
      });
    } catch (e) {
      debugPrint('❌ [MY_RECIPES] Load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// The loaded recipes, or until they arrive the own ones in the
  /// catalogue.
  List<Recipe> _source(List<Recipe>? catalog, String? userId) =>
      _recipes ??
      [
        if (catalog != null && userId != null)
          for (final r in catalog)
            if (r.authorId == userId) r,
      ];

  List<Recipe> _visible(List<Recipe>? catalog, String? userId) => [
    for (final r in _source(catalog, userId))
      if (!_deleting.contains(r.id)) r,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _write() async {
    await context.push('/recipes/add');
    if (mounted) unawaited(_load());
  }

  Future<void> _edit(Recipe r) async {
    await context.push(editRecipePath(r.id), extra: {'recipeId': r.id});
    if (mounted) unawaited(_load());
  }

  Future<void> _openDrafts() async {
    await context.push('/recipes/drafts');
    if (mounted) unawaited(_load());
  }

  void _share(Recipe r, BuildContext anchor) {
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    unawaited(
      ref.read(recipeLibraryActionsProvider).shareRecipe(r, origin: origin),
    );
  }

  Future<bool> _confirmDelete(Recipe r) => showAvoConfirm(
    context,
    title: context.tr('recipe_lib_delete_title', params: {'name': r.name}),
    message: context.tr('recipe_lib_delete_message'),
    confirmLabel: context.tr('recipe_lib_delete'),
  );

  Future<void> _delete(Recipe r) async {
    setState(() => _deleting.add(r.id));
    // Let the row leave the tree first: a swiped row that came back in the
    // same frame would still be dismissed.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final toastContext = context;
    final done = context.tr('recipe_lib_deleted');
    final failed = context.tr('recipe_lib_delete_failed');
    try {
      await ref.read(recipeLibraryActionsProvider).deleteRecipe(r.id);
      if (!mounted) return;
      final source = _source(
        ref.read(libraryCatalogProvider),
        ref.read(authUserIdProvider),
      );
      setState(() {
        _recipes = [
          for (final x in source)
            if (x.id != r.id) x,
        ];
        _deleting.remove(r.id);
      });
      if (toastContext.mounted) AvoToast.show(toastContext, message: done);
    } catch (e) {
      debugPrint('❌ [MY_RECIPES] Delete failed: $e');
      unawaited(AvoHaptics.error());
      if (!mounted) return;
      setState(() => _deleting.remove(r.id));
      if (toastContext.mounted) AvoToast.show(toastContext, message: failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    syncAvoContext(context);
    // The editor and the detail announce changes through this trigger.
    ref.listen<int>(recipeRefreshTriggerProvider, (_, _) => _load());
    final catalog = ref.watch(libraryCatalogProvider);
    final userId = ref.watch(authUserIdProvider);
    final offline = ref.watch(isOfflineProvider);
    final recipes = _visible(catalog, userId);

    final LibraryPhase phase;
    if (recipes.isNotEmpty || _recipes != null) {
      phase = LibraryPhase.ready;
    } else if (_failed) {
      phase = LibraryPhase.error;
    } else {
      phase = LibraryPhase.loading;
    }

    return RecipesLibraryPage(
      title: context.tr('recipe_lib_my_title'),
      onRefresh: _load,
      trailing: [
        GlassIconButton(
          icon: const AvoIcon(AvoIcons.plus),
          semanticLabel: context.tr('recipe_lib_new_recipe_button'),
          tinted: true,
          onPressed: _write,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: MyRecipesContent(
            phase: phase,
            recipes: recipes,
            now: DateTime.now(),
            draftCount: _draftCount,
            offline: offline,
            failed: _failed && recipes.isEmpty,
            onRetry: _load,
            onOpen: (r) => context.push(RoutePaths.recipe(r.id), extra: r),
            onEdit: _edit,
            onShare: _share,
            confirmDelete: _confirmDelete,
            onDelete: _delete,
            onOpenDrafts: _openDrafts,
            onWrite: _write,
          ),
        ),
      ],
    );
  }
}
