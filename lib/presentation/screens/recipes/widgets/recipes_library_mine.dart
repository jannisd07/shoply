import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

/// Gap above the first group when no heading sits there.
const double _kGroupTop = AvoSpacing.section;

/// Whether an own recipe is visible to others (Konzept 13 §10.1, E-05).
enum RecipeVisibility { published, private }

/// The visibility of [recipe]. The data model has no visibility field yet
/// (E-05), so every own recipe counts as published until it does.
RecipeVisibility visibilityOf(Recipe recipe) => RecipeVisibility.published;

// ------------------------------------------------------------ my recipes

/// The body of "Meine Rezepte" (R-08): a "Entwürfe" row while drafts exist,
/// then "Veröffentlicht" with rating and age, then "Nur für mich". Tap opens
/// the recipe; a long press offers Bearbeiten, Teilen, Löschen; swiping
/// deletes after the confirmation.
class MyRecipesContent extends StatelessWidget {
  const MyRecipesContent({
    super.key,
    required this.phase,
    required this.recipes,
    required this.now,
    required this.onOpen,
    required this.onEdit,
    required this.onShare,
    required this.confirmDelete,
    required this.onDelete,
    this.draftCount = 0,
    this.onOpenDrafts,
    this.onWrite,
    this.offline = false,
    this.failed = false,
    this.onRetry,
  });

  final LibraryPhase phase;

  /// Own recipes, newest first.
  final List<Recipe> recipes;
  final DateTime now;
  final ValueChanged<Recipe> onOpen;
  final ValueChanged<Recipe> onEdit;
  final void Function(Recipe recipe, BuildContext anchor) onShare;

  /// Asks "„…“ löschen?"; true when confirmed.
  final Future<bool> Function(Recipe recipe) confirmDelete;

  /// Deletes without asking again (after [confirmDelete]).
  final ValueChanged<Recipe> onDelete;
  final int draftCount;
  final VoidCallback? onOpenDrafts;

  /// "Rezept schreiben".
  final VoidCallback? onWrite;
  final bool offline;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final published = [
      for (final r in recipes)
        if (visibilityOf(r) == RecipeVisibility.published) r,
    ];
    final private = [
      for (final r in recipes)
        if (visibilityOf(r) == RecipeVisibility.private) r,
    ];
    final children = <Widget>[
      LibraryStatus(
        offline: offline,
        failed: failed,
        hasContent: recipes.isNotEmpty,
        onRetry: onRetry,
      ),
      if (draftCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: _kGroupTop),
          child: InsetSection(
            children: [
              NavRow(
                title: context.tr('recipe_lib_drafts_row'),
                value: '$draftCount',
                onTap: onOpenDrafts,
              ),
            ],
          ),
        ),
    ];

    if (recipes.isEmpty) {
      if (phase == LibraryPhase.loading) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: _kGroupTop),
            child: SkeletonSection(
              rows: 3,
              loadingLabel: context.tr('recipe_lib_loading'),
            ),
          ),
        );
      } else if (!offline && !failed) {
        children.add(
          EmptyState(
            pose: draftCount > 0 ? null : AvoPose.excited,
            title: context.tr('recipe_lib_my_empty_title'),
            message: context.tr('recipe_lib_my_empty_text'),
            actionLabel: onWrite == null
                ? null
                : context.tr('recipe_lib_write_recipe'),
            onAction: onWrite,
          ),
        );
      }
    } else {
      for (final (key, list) in [
        ('recipe_lib_published', published),
        ('recipe_lib_private', private),
      ]) {
        if (list.isEmpty) continue;
        children.add(
          InsetSection(
            header: context.tr(key),
            separatorIndent: ListRow.separatorIndent,
            children: [for (final r in list) _myRow(context, r)],
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

  Widget _myRow(BuildContext context, Recipe r) {
    final edit = context.tr('recipe_lib_edit');
    final share = context.tr('recipe_lib_share');
    final delete = context.tr('recipe_lib_delete');
    final isPublic = visibilityOf(r) == RecipeVisibility.published;
    final meta = joinMeta([
      if (isPublic)
        formatRatingWithCount(context, r) ?? context.tr('recipe_lib_not_rated'),
      formatAgo(context, r.createdAt, now),
    ]);
    Future<void> askAndDelete() async {
      if (await confirmDelete(r)) onDelete(r);
    }

    return LibrarySwipe(
      key: ValueKey<String>('mine-${r.id}'),
      id: 'mine-${r.id}',
      label: delete,
      icon: AvoIcons.trash,
      destructive: true,
      enabled: !offline,
      confirm: () => confirmDelete(r),
      onSwiped: () => onDelete(r),
      child: Builder(
        builder: (anchor) => LibraryPressMenu(
          semanticLabel: r.name,
          items: () => [
            AvoMenuItem(label: edit, onSelected: () => onEdit(r)),
            AvoMenuItem(
              label: share,
              icon: AvoIcons.share,
              enabled: isPublic,
              onSelected: () => onShare(r, anchor),
            ),
            const AvoMenuDivider(),
            AvoMenuItem(
              label: delete,
              icon: AvoIcons.trash,
              destructive: true,
              enabled: !offline,
              subtitle: offline ? context.tr('common_needs_connection') : null,
              onSelected: askAndDelete,
            ),
          ],
          child: ListRow(
            title: r.name,
            meta: meta,
            cover: LibraryRecipeThumb(url: r.imageUrl),
            onTap: () => onOpen(r),
            semanticActions: {
              edit: () => onEdit(r),
              if (isPublic) share: () => onShare(r, anchor),
              if (!offline) delete: askAndDelete,
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- drafts

/// The body of "Entwürfe" (R-09): one group of drafts, newest first, with
/// "Bereit zum Veröffentlichen" or what is missing and when it was last
/// changed. Tap is "Weiterschreiben"; swipe or the menu discards after the
/// confirmation (it is final).
class RecipeDraftsContent extends StatelessWidget {
  const RecipeDraftsContent({
    super.key,
    required this.phase,
    required this.drafts,
    required this.now,
    required this.onContinue,
    required this.confirmDiscard,
    required this.onDiscard,
    this.onWrite,
    this.onRetry,
  });

  /// [LibraryPhase.error]: the last load failed; the drafts shown (if any)
  /// are the ones from before, and a row offers "Erneut versuchen" instead
  /// of the empty state claiming there are none (A11b).
  final LibraryPhase phase;
  final List<RecipeDraft> drafts;
  final DateTime now;
  final ValueChanged<RecipeDraft> onContinue;

  /// Asks "Entwurf verwerfen?"; true when confirmed.
  final Future<bool> Function(RecipeDraft draft) confirmDiscard;

  /// Discards without asking again.
  final ValueChanged<RecipeDraft> onDiscard;

  /// "Rezept schreiben" in the empty state.
  final VoidCallback? onWrite;

  /// "Erneut versuchen" after a failed load.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = phase == LibraryPhase.error;
    final status = LibraryStatus(
      failed: failed,
      hasContent: drafts.isNotEmpty,
      onRetry: onRetry,
      failedKey: 'recipe_lib_drafts_load_failed',
    );
    if (drafts.isEmpty && failed) return status;
    if (drafts.isEmpty) {
      if (phase == LibraryPhase.loading) {
        return Padding(
          padding: const EdgeInsets.only(top: _kGroupTop),
          child: SkeletonSection(
            rows: 2,
            loadingLabel: context.tr('recipe_lib_loading'),
          ),
        );
      }
      return EmptyState(
        pose: AvoPose.excited,
        title: context.tr('recipe_lib_drafts_empty_title'),
        message: context.tr('recipe_lib_drafts_empty_text'),
        actionLabel: onWrite == null
            ? null
            : context.tr('recipe_lib_write_recipe'),
        onAction: onWrite,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        Padding(
          padding: const EdgeInsets.only(top: _kGroupTop),
          child: InsetSection(
            separatorIndent: ListRow.separatorIndent,
            footer: context.tr('recipe_lib_drafts_footer'),
            children: [for (final d in drafts) _draftRow(context, d)],
          ),
        ),
      ],
    );
  }

  Widget _draftRow(BuildContext context, RecipeDraft d) {
    final resume = context.tr('recipe_lib_continue');
    final discard = context.tr('common_discard');
    final path = d.localImagePath;
    Future<void> askAndDiscard() async {
      if (await confirmDiscard(d)) onDiscard(d);
    }

    return LibrarySwipe(
      key: ValueKey<String>('draft-${d.id}'),
      id: 'draft-${d.id}',
      label: discard,
      icon: AvoIcons.trash,
      destructive: true,
      confirm: () => confirmDiscard(d),
      onSwiped: () => onDiscard(d),
      child: LibraryPressMenu(
        semanticLabel: draftTitle(context, d),
        items: () => [
          AvoMenuItem(label: resume, onSelected: () => onContinue(d)),
          const AvoMenuDivider(),
          AvoMenuItem(
            label: discard,
            icon: AvoIcons.trash,
            destructive: true,
            onSelected: askAndDiscard,
          ),
        ],
        child: ListRow(
          title: draftTitle(context, d),
          meta: joinMeta([
            draftStatus(context, d),
            formatAgo(context, d.updatedAt, now),
          ]),
          cover: LibraryRecipeThumb(
            url: '',
            file: path == null ? null : FileImage(File(path)),
          ),
          onTap: () => onContinue(d),
          semanticActions: {discard: askAndDiscard},
        ),
      ),
    );
  }
}
