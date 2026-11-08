import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipes_library_scaffold.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/recipe_card.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

/// Profile head (E-17): avatar 64, name 22/28 bold, meta line.
const double _kAvatar = 64;
const double _kNameTop = AvoSpacing.m;
const double _kMetaTop = AvoSpacing.xxs;
const double _kButtonTop = AvoSpacing.l;

/// D2-Rezepte grid: 12 between columns, 20 between rows, the section title
/// 20 above and 10 below.
const double _kColumnGap = AvoSpacing.m; // D2
const double _kRowGap = AvoSpacing.xl; // D2
const double _kSectionTop = AvoSpacing.xxxl;
const double _kGridTop = 10; // D2

/// Height of the sort button's chevron next to its label.
const double _kSortChevron = 14;

/// Order of a creator's recipes (Konzept 13 §8.1 item 5).
enum CreatorSort { newest, popular }

/// Sorts [recipes] by [sort]: newest first, or best rated (then most
/// rated, then newest).
List<Recipe> sortCreatorRecipes(List<Recipe> recipes, CreatorSort sort) {
  final list = [...recipes];
  switch (sort) {
    case CreatorSort.newest:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case CreatorSort.popular:
      list.sort((a, b) {
        final byRating = b.averageRating.compareTo(a.averageRating);
        if (byRating != 0) return byRating;
        final byCount = b.ratingCount.compareTo(a.ratingCount);
        if (byCount != 0) return byCount;
        return b.createdAt.compareTo(a.createdAt);
      });
  }
  return list;
}

/// "24 Rezepte · Ø 4,6" for a creator's recipes, or null without any.
String? creatorMeta(BuildContext context, List<Recipe> recipes) {
  if (recipes.isEmpty) return null;
  final rated = [
    for (final r in recipes)
      if (r.ratingCount > 0) r,
  ];
  final average = rated.isEmpty
      ? 0.0
      : rated.map((r) => r.averageRating).reduce((a, b) => a + b) /
            rated.length;
  return joinMeta([
    formatRecipeCount(context, recipes.length),
    if (average > 0)
      context.tr(
        'recipe_lib_average',
        params: {'rating': formatRating(context, average)},
      ),
  ]);
}

/// The head of a creator page (R-06, Konzept 13 §8.1): avatar, name, the
/// numbers and the one action, "Folgen" (tinted) or "Folge ich" (glass);
/// on the person's own page "Profil bearbeiten" instead.
class CreatorHeader extends StatelessWidget {
  const CreatorHeader({
    super.key,
    required this.name,
    this.avatarUrl,
    this.meta,
    this.isSelf = false,
    this.following = false,
    this.onFollow,
    this.onUnfollow,
    this.onEditProfile,
  });

  final String name;
  final String? avatarUrl;

  /// "24 Rezepte · Ø 4,6".
  final String? meta;

  /// The signed-in person's own page.
  final bool isSelf;
  final bool following;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onEditProfile;

  /// Scroll offset after which the name moves into the toolbar.
  static double collapseAfter(BuildContext context) =>
      _kAvatar +
      _kNameTop +
      context.typography.lineHeightOf(AvoTextStyle.title2);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = meta;
    final Widget action;
    if (isSelf) {
      action = AppButton.secondary(
        key: const ValueKey('edit-profile'),
        label: context.tr('recipe_lib_edit_profile'),
        expand: true,
        onPressed: onEditProfile,
      );
    } else if (following) {
      action = AppButton.secondary(
        key: const ValueKey('following'),
        label: context.tr('recipe_lib_following_button'),
        icon: const AvoIcon(AvoIcons.check),
        expand: true,
        onPressed: onUnfollow,
      );
    } else {
      action = AppButton.primary(
        key: const ValueKey('follow'),
        label: context.tr('recipe_lib_follow'),
        icon: const AvoIcon(AvoIcons.plus),
        expand: true,
        onPressed: onFollow,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthorAvatar(name: name, avatarUrl: avatarUrl, size: _kAvatar),
          const SizedBox(height: _kNameTop),
          Semantics(
            header: true,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.title2),
            ),
          ),
          if (text != null) ...[
            const SizedBox(height: _kMetaTop),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
                tabular: true,
              ),
            ),
          ],
          const SizedBox(height: _kButtonTop),
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: AvoMotion.fadeReduced,
              child: action,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Rezepte" with the sort menu and the two-column grid of [RecipeCard]s
/// (one column from AX1), or the states of the page.
class CreatorRecipesSection extends StatelessWidget {
  const CreatorRecipesSection({
    super.key,
    required this.phase,
    required this.recipes,
    required this.creatorName,
    required this.onOpen,
    this.sort = CreatorSort.newest,
    this.onSort,
    this.allergensOf,
    this.offline = false,
    this.failed = false,
    this.onRetry,
  });

  final LibraryPhase phase;

  /// Already sorted by [sort].
  final List<Recipe> recipes;
  final String creatorName;
  final ValueChanged<Recipe> onOpen;
  final CreatorSort sort;
  final ValueChanged<CreatorSort>? onSort;

  /// Names of the person's allergens in a recipe (never hidden).
  final List<String> Function(Recipe recipe)? allergensOf;
  final bool offline;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      LibraryStatus(
        offline: offline,
        failed: failed,
        hasContent: recipes.isNotEmpty,
        onRetry: onRetry,
      ),
    ];
    if (recipes.isEmpty) {
      if (phase == LibraryPhase.loading) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: _kSectionTop),
            child: SkeletonSection(
              rows: 3,
              loadingLabel: context.tr('recipe_lib_loading'),
            ),
          ),
        );
      } else if (phase == LibraryPhase.ready && !offline && !failed) {
        children.add(
          EmptyState(
            title: context.tr('recipe_lib_creator_empty_title'),
            message: context.tr(
              'recipe_lib_creator_empty_text',
              params: {'name': creatorName},
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
    children
      ..add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            _kSectionTop,
            AvoSpacing.screen,
            _kGridTop,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AvoSpacing.s,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.tr('recipe_lib_creator_recipes'),
                  style: context.text(AvoTextStyle.title3),
                ),
              ),
              if (onSort != null && recipes.length > 1)
                _SortButton(sort: sort, onSort: onSort!),
            ],
          ),
        ),
      )
      ..add(
        LibraryRecipeGrid(
          recipes: recipes,
          onOpen: onOpen,
          allergensOf: allergensOf,
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// "Neu ⌄" in the tint colour: opens the sort menu (44 pt target).
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSort});

  final CreatorSort sort;
  final ValueChanged<CreatorSort> onSort;

  String _label(BuildContext context, CreatorSort s) => context.tr(
    s == CreatorSort.newest ? 'recipe_lib_sort_new' : 'recipe_lib_sort_popular',
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = _label(context, sort);
    return Builder(
      builder: (anchor) => Semantics(
        button: true,
        label: context.tr('recipe_lib_sort_voice', params: {'order': label}),
        excludeSemantics: true,
        onTap: () => _open(anchor),
        child: PressableScale(
          onPressed: () => _open(anchor),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.hitTarget,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: context.text(AvoTextStyle.body, color: colors.tint),
                  ),
                ),
                const SizedBox(width: AvoSpacing.xs),
                AvoIcon(
                  AvoIcons.chevronDown,
                  size: _kSortChevron,
                  color: colors.tint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext anchor) {
    showAvoMenu(
      anchor,
      items: [
        for (final s in CreatorSort.values)
          AvoMenuItem(
            label: _label(anchor, s),
            checked: s == sort,
            onSelected: () => onSort(s),
          ),
      ],
    );
  }
}

/// Recipes as D2-Rezepte grid tiles, two per row (one from AX1), each row
/// as tall as its tallest tile.
class LibraryRecipeGrid extends StatelessWidget {
  const LibraryRecipeGrid({
    super.key,
    required this.recipes,
    required this.onOpen,
    this.allergensOf,
  });

  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpen;
  final List<String> Function(Recipe recipe)? allergensOf;

  @override
  Widget build(BuildContext context) {
    final columns = context.isAccessibilityText ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              (constraints.maxWidth - _kColumnGap * (columns - 1)) / columns;
          final rows = <Widget>[];
          for (var i = 0; i < recipes.length; i += columns) {
            if (rows.isNotEmpty) rows.add(const SizedBox(height: _kRowGap));
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: _kColumnGap),
                    Expanded(
                      child: i + c < recipes.length
                          ? _tile(context, recipes[i + c], width)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Recipe recipe, double width) {
    final names = allergensOf?.call(recipe) ?? const <String>[];
    final meta = recipeCardMeta(context, recipe);
    return RecipeCard(
      key: ValueKey<String>('grid-${recipe.id}'),
      image: LibraryCardPhoto(url: recipe.imageUrl, width: width),
      title: recipe.name,
      meta: meta.isEmpty ? null : meta,
      badge: names.isEmpty ? null : LibraryAllergenBadge(names: names),
      semanticLabel: recipeCardVoice(context, recipe),
      onTap: () => onOpen(recipe),
    );
  }
}
