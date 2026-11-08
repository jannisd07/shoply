import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_author.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_follow.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_destinations.dart';
import 'package:shoply/routes/route_paths.dart';

/// R-06 creator page (Konzept 13 §8, §19.6): who is this, and do I want
/// more from them?
///
/// The head shows at once from what is known (the name passed in, the
/// catalogue, the follow list), the recipes from the catalogue; the
/// creator's full list loads behind it. "Folgen" switches at once and is
/// synced later; "Folge ich" stops following with "Widerrufen". On the
/// person's own page the button is "Profil bearbeiten".
class RecipeAuthorPage extends ConsumerStatefulWidget {
  final String authorId;
  final String? authorName;

  const RecipeAuthorPage({super.key, required this.authorId, this.authorName});

  @override
  ConsumerState<RecipeAuthorPage> createState() => _RecipeAuthorPageState();
}

class _RecipeAuthorPageState extends ConsumerState<RecipeAuthorPage>
    with LibraryAvoContext {
  /// The creator's recipes from the server; null until the first answer.
  List<Recipe>? _loaded;
  bool _failed = false;
  CreatorSort _sort = CreatorSort.newest;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  Future<void> _load() async {
    final actions = ref.read(recipeLibraryActionsProvider);
    try {
      final recipes = await actions.recipesBy(widget.authorId);
      if (!mounted) return;
      // The service answers an empty list when it fails; offline that
      // must not replace what the catalogue already showed.
      if (recipes.isEmpty && ref.read(isOfflineProvider)) return;
      setState(() {
        _loaded = recipes;
        _failed = false;
      });
    } catch (e) {
      debugPrint('❌ [AUTHOR_PAGE] Failed to load ${widget.authorId}: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _markSeen() {
    if (!mounted) return;
    final recipes = _recipes(ref.read(libraryCatalogProvider));
    unawaited(
      ref
          .read(creatorFollowsProvider.notifier)
          .markSeen(
            widget.authorId,
            name: recipes.isEmpty
                ? widget.authorName
                : recipes.first.authorName,
            avatarUrl: recipes.isEmpty ? null : recipes.first.authorAvatarUrl,
          ),
    );
  }

  List<Recipe> _recipes(List<Recipe>? catalog) {
    final loaded = _loaded;
    if (loaded != null) return loaded;
    if (catalog == null) return const [];
    return [
      for (final r in catalog)
        if (r.authorId == widget.authorId) r,
    ];
  }

  void _follow(String name, String? avatarUrl) {
    unawaited(
      ref
          .read(creatorFollowsProvider.notifier)
          .follow(widget.authorId, name: name, avatarUrl: avatarUrl),
    );
  }

  void _unfollow(String name) {
    final notifier = ref.read(creatorFollowsProvider.notifier);
    final previous = ref.read(creatorFollowsProvider).followed[widget.authorId];
    if (previous == null) return;
    unawaited(notifier.unfollow(widget.authorId));
    AvoToast.show(
      context,
      message: context.tr('recipe_lib_unfollowed', params: {'name': name}),
      actionLabel: context.tr('common_undo'),
      onAction: () => notifier.restore(previous),
    );
  }

  @override
  Widget build(BuildContext context) {
    syncAvoContext(context);
    final catalog = ref.watch(libraryCatalogProvider);
    final follows = ref.watch(creatorFollowsProvider);
    final offline = ref.watch(isOfflineProvider);
    final userId = ref.watch(authUserIdProvider);
    final allergies = ref.watch(libraryAllergiesProvider);

    final recipes = sortCreatorRecipes(_recipes(catalog), _sort);
    final followed = follows.followed[widget.authorId];
    final fromRecipes = recipes.isEmpty ? null : recipes.first;
    final knownName = [
      fromRecipes?.authorName,
      widget.authorName,
      followed?.name,
    ].whereType<String>().map((n) => n.trim()).where((n) => n.isNotEmpty);
    final name = knownName.isEmpty
        ? context.tr('recipe_lib_creator_fallback')
        : knownName.first;
    final avatarUrl = fromRecipes?.authorAvatarUrl ?? followed?.avatarUrl;
    final isSelf = userId != null && userId == widget.authorId;

    final LibraryPhase phase;
    if (recipes.isNotEmpty || _loaded != null) {
      phase = LibraryPhase.ready;
    } else if (_failed) {
      phase = LibraryPhase.error;
    } else {
      phase = LibraryPhase.loading;
    }
    final gone =
        phase == LibraryPhase.ready &&
        recipes.isEmpty &&
        knownName.isEmpty &&
        !offline;

    final header = CreatorHeader(
      name: name,
      avatarUrl: avatarUrl,
      meta: creatorMeta(context, recipes),
      isSelf: isSelf,
      following: followed != null,
      onFollow: () => _follow(name, avatarUrl),
      onUnfollow: () => _unfollow(name),
      onEditProfile: () => openAppDestination(context, AppDestinations.profile),
    );

    return RecipesLibraryPage(
      title: name,
      plain: true,
      header: gone ? const SizedBox.shrink() : header,
      collapseAfter: CreatorHeader.collapseAfter(context),
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: gone
              ? EmptyState(
                  title: context.tr('recipe_lib_creator_gone'),
                  actionLabel: context.tr('recipe_lib_to_recipes'),
                  onAction: () => context.go(RoutePaths.recipes),
                )
              : CreatorRecipesSection(
                  phase: phase,
                  recipes: recipes,
                  creatorName: name,
                  sort: _sort,
                  onSort: (s) => setState(() => _sort = s),
                  offline: offline,
                  failed: _failed && recipes.isEmpty,
                  onRetry: _load,
                  allergensOf: (r) =>
                      libraryAllergenNames(context, r, allergies),
                  // Top-level recipe route: this page sits outside the tab
                  // shell today.
                  onOpen: (r) => context.push('/recipe/${r.id}', extra: r),
                ),
        ),
      ],
    );
  }
}
