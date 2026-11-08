import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

/// From this many saved recipes on, a search field sits under the title
/// (Konzept 13 §9.1).
const int kSavedSearchFrom = 10;

/// Space between the search field and the title (D2-Rezepte: 6).
const double _kSearchTop = 6; // D2

/// Gap above the group.
const double _kGroupTop = AvoSpacing.section;

/// Rows of "Gespeichert" match [query] by name, creator or label.
List<Recipe> filterSavedRecipes(List<Recipe> recipes, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return recipes;
  return [
    for (final r in recipes)
      if (r.name.toLowerCase().contains(q) ||
          r.authorName.toLowerCase().contains(q) ||
          r.labels.any((l) => l.toLowerCase().contains(q)))
        r,
  ];
}

/// The body of "Gespeichert" (R-07): optional search, then one inset group
/// of recipe rows in save order ("Shakshuka · 25 Min · von Deniz Aydın").
/// Swipe or the context menu removes a row (neutral grey, the screen offers
/// undo); a long press opens "Öffnen", "Mehr von …", "Entfernen".
class SavedRecipesContent extends StatelessWidget {
  const SavedRecipesContent({
    super.key,
    required this.phase,
    required this.recipes,
    required this.onOpen,
    required this.onRemove,
    this.onOpenAuthor,
    this.query = '',
    this.onQueryChanged,
    this.searchController,
    this.allergensOf,
    this.offline = false,
    this.onDiscover,
  });

  final LibraryPhase phase;

  /// All saved recipes, newest saved first.
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpen;
  final ValueChanged<Recipe> onRemove;
  final ValueChanged<Recipe>? onOpenAuthor;
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final TextEditingController? searchController;
  final List<String> Function(Recipe recipe)? allergensOf;
  final bool offline;

  /// "Rezepte entdecken" in the empty state (goes to the tab root).
  final VoidCallback? onDiscover;

  @override
  Widget build(BuildContext context) {
    final shown = filterSavedRecipes(recipes, query);
    final children = <Widget>[
      if (recipes.length >= kSavedSearchFrom)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kSearchTop,
            AvoSpacing.screen,
            0,
          ),
          child: AvoSearchField(
            controller: searchController,
            hint: context.tr('recipe_lib_saved_search'),
            onChanged: onQueryChanged,
          ),
        ),
      LibraryStatus(offline: offline, hasContent: recipes.isNotEmpty),
    ];

    if (recipes.isEmpty) {
      if (phase == LibraryPhase.loading) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: _kGroupTop),
            child: SkeletonSection(
              rows: 4,
              loadingLabel: context.tr('recipe_lib_loading'),
            ),
          ),
        );
      } else if (!offline) {
        children.add(
          EmptyState(
            pose: AvoPose.excited,
            title: context.tr('recipe_lib_saved_empty_title'),
            message: context.tr('recipe_lib_saved_empty_text'),
            actionLabel: onDiscover == null
                ? null
                : context.tr('recipe_lib_discover'),
            onAction: onDiscover,
          ),
        );
      }
    } else if (shown.isEmpty) {
      children.add(
        EmptyState(
          title: context.tr(
            'recipe_lib_no_match',
            params: {'query': query.trim()},
          ),
        ),
      );
    } else {
      final remove = context.tr('recipe_lib_remove');
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: _kGroupTop),
          child: InsetSection(
            separatorIndent: ListRow.separatorIndent,
            children: [
              for (final r in shown)
                LibrarySwipe(
                  key: ValueKey<String>('saved-${r.id}'),
                  id: 'saved-${r.id}',
                  label: remove,
                  icon: AvoIcons.bookmark,
                  onSwiped: () => onRemove(r),
                  child: _SavedRow(
                    recipe: r,
                    allergens: allergensOf?.call(r) ?? const [],
                    onOpen: () => onOpen(r),
                    onRemove: () => onRemove(r),
                    onOpenAuthor: onOpenAuthor == null || r.authorId.isEmpty
                        ? null
                        : () => onOpenAuthor!(r),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.recipe,
    required this.allergens,
    required this.onOpen,
    required this.onRemove,
    this.onOpenAuthor,
  });

  final Recipe recipe;
  final List<String> allergens;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback? onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final author = r.authorName.trim();
    final remove = context.tr('recipe_lib_remove');
    final moreFrom = author.isEmpty
        ? null
        : context.tr('recipe_lib_more_from', params: {'name': author});
    final openAuthor = onOpenAuthor;
    final meta = joinMeta([
      if (r.totalTimeMinutes > 0) formatDuration(context, r.totalTimeMinutes),
      if (author.isNotEmpty)
        context.tr('recipe_lib_by', params: {'name': author}),
    ]);
    return LibraryPressMenu(
      semanticLabel: r.name,
      items: () => [
        AvoMenuItem(label: context.tr('recipe_lib_open'), onSelected: onOpen),
        if (openAuthor != null && moreFrom != null)
          AvoMenuItem(
            label: moreFrom,
            icon: AvoIcons.person,
            onSelected: openAuthor,
          ),
        const AvoMenuDivider(),
        AvoMenuItem(
          label: remove,
          icon: AvoIcons.bookmark,
          onSelected: onRemove,
        ),
      ],
      child: ListRow(
        title: r.name,
        meta: meta.isEmpty ? null : meta,
        cover: LibraryRecipeThumb(url: r.imageUrl),
        badge: allergens.isEmpty
            ? null
            : LibraryAllergenBadge(names: allergens),
        onTap: onOpen,
        semanticActions: {
          remove: onRemove,
          if (openAuthor != null && moreFrom != null) moreFrom: openAuthor,
        },
      ),
    );
  }
}
