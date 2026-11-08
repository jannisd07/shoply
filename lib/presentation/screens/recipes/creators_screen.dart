import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_creators.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_follow.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Without a search, the creator list shows this many (Konzept 13 §7.1).
const int kCreatorsListed = 50;

/// The creator rows for [catalog] and [follows]: the followed creators
/// (newest follow first, "neu: …" for a recipe since the last visit) and the
/// ranked rest.
({List<CreatorRowData> following, List<CreatorRowData> popular}) creatorRows(
  List<LibraryCreator> ranked,
  CreatorFollowsState follows, {
  bool searching = false,
}) {
  final byId = {for (final c in ranked) c.id: c};
  final following = <CreatorRowData>[];
  for (final f in follows.ordered) {
    final known = byId[f.id];
    final seen = f.lastSeen ?? f.followedAt;
    final fresh = known?.recipes.where((r) => r.createdAt.isAfter(seen));
    following.add(
      CreatorRowData(
        id: f.id,
        name: (known?.name.trim().isNotEmpty ?? false) ? known!.name : f.name,
        avatarUrl: known?.avatarUrl ?? f.avatarUrl,
        recipeCount: known?.recipeCount ?? 0,
        averageRating: known?.averageRating ?? 0,
        newRecipe: (fresh == null || fresh.isEmpty) ? null : fresh.first.name,
      ),
    );
  }
  final popular = [
    for (final c in searching ? ranked : ranked.take(kCreatorsListed))
      CreatorRowData(
        id: c.id,
        name: c.name,
        avatarUrl: c.avatarUrl,
        recipeCount: c.recipeCount,
        averageRating: c.averageRating,
      ),
  ];
  return (following: following, popular: popular);
}

/// R-05 "Ersteller" (Konzept 13 §7): whose recipes do I want to see?
///
/// Rows come from the local catalogue at once; following is kept on the
/// device and synced in the background. Swiping a followed creator stops
/// following, with "Widerrufen".
class CreatorsScreen extends ConsumerStatefulWidget {
  const CreatorsScreen({super.key});

  @override
  ConsumerState<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends ConsumerState<CreatorsScreen>
    with LibraryAvoContext {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await (
      ref.read(recipeLibraryActionsProvider).reloadCatalog(),
      ref.read(creatorFollowsProvider.notifier).sync(),
    ).wait;
  }

  void _open(CreatorRowData c) {
    context.push(creatorPath(c.id), extra: {'authorName': c.name});
  }

  void _unfollow(CreatorRowData c) {
    final notifier = ref.read(creatorFollowsProvider.notifier);
    final previous = ref.read(creatorFollowsProvider).followed[c.id];
    if (previous == null) return;
    unawaited(notifier.unfollow(c.id));
    AvoToast.show(
      context,
      message: context.tr('recipe_lib_unfollowed', params: {'name': c.name}),
      actionLabel: context.tr('common_undo'),
      onAction: () => notifier.restore(previous),
    );
  }

  @override
  Widget build(BuildContext context) {
    syncAvoContext(context);
    final catalog = ref.watch(libraryCatalogProvider);
    final failed = ref.watch(libraryCatalogFailedProvider);
    final follows = ref.watch(creatorFollowsProvider);
    final offline = ref.watch(isOfflineProvider);

    final ranked = catalog == null
        ? const <LibraryCreator>[]
        : rankCreators(catalog);
    final rows = creatorRows(
      ranked,
      follows,
      searching: _query.trim().isNotEmpty,
    );
    final phase = catalog != null
        ? LibraryPhase.ready
        : failed
        ? LibraryPhase.error
        : LibraryPhase.loading;

    return RecipesLibraryPage(
      title: context.tr('recipe_lib_creators_title'),
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(
          child: CreatorsContent(
            phase: phase,
            following: rows.following,
            popular: rows.popular,
            query: _query,
            searchController: _search,
            onQueryChanged: (q) => setState(() => _query = q),
            offline: offline,
            onOpen: _open,
            onUnfollow: _unfollow,
            onRetry: () =>
                ref.read(recipeLibraryActionsProvider).catalogChanged(),
            onWrite: () => context.push('/recipes/add'),
          ),
        ),
      ],
    );
  }
}
