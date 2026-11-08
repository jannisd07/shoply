import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

/// Space between the search field and the title above it (D2-Rezepte: 6).
const double _kSearchTop = 6; // D2

/// Avatar in creator rows: the 44 pt leading square of [ListRow].
const double _kRowAvatar = AvoSizes.thumbSmall;

/// One creator row (Konzept 13 §7.1).
@immutable
class CreatorRowData {
  const CreatorRowData({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.recipeCount = 0,
    this.averageRating = 0,
    this.newRecipe,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final int recipeCount;

  /// Mean rating of the rated recipes; 0 when none is rated.
  final double averageRating;

  /// Name of a recipe published since the last visit ("neu: Kürbis-Risotto").
  final String? newRecipe;
}

/// The body of "Ersteller" (R-05) below the large title: search, then
/// "Folge ich" (swipe to unfollow) and "Beliebte Ersteller", or the empty,
/// loading, offline and error states.
class CreatorsContent extends StatelessWidget {
  const CreatorsContent({
    super.key,
    required this.phase,
    required this.following,
    required this.popular,
    required this.onOpen,
    required this.onUnfollow,
    this.query = '',
    this.onQueryChanged,
    this.searchController,
    this.offline = false,
    this.onRetry,
    this.onWrite,
  });

  final LibraryPhase phase;

  /// Creators the person follows, newest follow first.
  final List<CreatorRowData> following;

  /// Ranked creators (top 50 without a query, all matches with one).
  final List<CreatorRowData> popular;

  final ValueChanged<CreatorRowData> onOpen;
  final ValueChanged<CreatorRowData> onUnfollow;

  /// The current search text (filters both sections at once).
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final TextEditingController? searchController;
  final bool offline;
  final VoidCallback? onRetry;

  /// "Rezept schreiben" in the empty state.
  final VoidCallback? onWrite;

  static bool _matches(CreatorRowData c, String q) =>
      q.isEmpty || c.name.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final followed = {for (final c in following) c.id};
    final mine = [
      for (final c in following)
        if (c.name.trim().isNotEmpty && _matches(c, q)) c,
    ];
    final others = [
      for (final c in popular)
        if (!followed.contains(c.id) && _matches(c, q)) c,
    ];
    final known = following.isNotEmpty || popular.isNotEmpty;

    final children = <Widget>[
      if (known)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kSearchTop,
            AvoSpacing.screen,
            0,
          ),
          child: AvoSearchField(
            controller: searchController,
            hint: context.tr('recipe_lib_creators_search'),
            onChanged: onQueryChanged,
          ),
        ),
      LibraryStatus(
        offline: offline,
        failed: phase == LibraryPhase.error,
        hasContent: known,
        onRetry: onRetry,
      ),
    ];

    if (phase == LibraryPhase.loading && !known) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: SkeletonSection(
            rows: 5,
            loadingLabel: context.tr('recipe_lib_loading'),
          ),
        ),
      );
    } else if (!known && phase == LibraryPhase.ready && !offline) {
      children.add(
        EmptyState(
          pose: AvoPose.excited,
          title: context.tr('recipe_lib_creators_empty_title'),
          message: context.tr('recipe_lib_creators_empty_text'),
          actionLabel: onWrite == null
              ? null
              : context.tr('recipe_lib_write_recipe'),
          onAction: onWrite,
        ),
      );
    } else if (known && mine.isEmpty && others.isEmpty && q.isNotEmpty) {
      children.add(
        EmptyState(
          title: context.tr(
            'recipe_lib_creators_no_match',
            params: {'query': query.trim()},
          ),
        ),
      );
    } else {
      final unfollow = context.tr('recipe_lib_unfollow');
      if (mine.isNotEmpty) {
        children.add(
          InsetSection(
            header: context.tr('recipe_lib_following'),
            separatorIndent: ListRow.separatorIndent,
            children: [
              for (final c in mine)
                LibrarySwipe(
                  key: ValueKey<String>('following-${c.id}'),
                  id: 'follow-${c.id}',
                  label: unfollow,
                  icon: AvoIcons.person,
                  onSwiped: () => onUnfollow(c),
                  child: _CreatorRow(
                    creator: c,
                    followed: true,
                    onTap: () => onOpen(c),
                    actions: {unfollow: () => onUnfollow(c)},
                  ),
                ),
            ],
          ),
        );
      }
      if (others.isNotEmpty) {
        children.add(
          InsetSection(
            header: context.tr('recipe_lib_popular_creators'),
            separatorIndent: ListRow.separatorIndent,
            children: [
              for (final c in others)
                _CreatorRow(
                  key: ValueKey<String>('popular-${c.id}'),
                  creator: c,
                  followed: false,
                  onTap: () => onOpen(c),
                ),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Avatar, name, "24 Rezepte · neu: Kürbis-Risotto" or "24 Rezepte · Ø 4,6".
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    super.key,
    required this.creator,
    required this.followed,
    required this.onTap,
    this.actions = const {},
  });

  final CreatorRowData creator;
  final bool followed;
  final VoidCallback onTap;
  final Map<String, VoidCallback> actions;

  @override
  Widget build(BuildContext context) {
    final c = creator;
    final newRecipe = c.newRecipe;
    final meta = joinMeta([
      if (c.recipeCount > 0) formatRecipeCount(context, c.recipeCount),
      if (followed && newRecipe != null)
        context.tr('recipe_lib_new_recipe', params: {'name': newRecipe})
      else if (!followed && c.averageRating > 0)
        context.tr(
          'recipe_lib_average',
          params: {'rating': formatRating(context, c.averageRating)},
        ),
    ]);
    return ListRow(
      title: c.name,
      meta: meta.isEmpty ? null : meta,
      cover: AuthorAvatar(
        name: c.name,
        avatarUrl: c.avatarUrl,
        size: _kRowAvatar,
      ),
      onTap: onTap,
      semanticActions: actions,
    );
  }
}
