import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

// Top of the recipe detail (Konzept 13 §12.1 Nr. 1 to 3): the photo up to
// the status bar, the glass toolbar over it, title, meta line and author.

/// Photo aspect: 4:3, from AX3 on 16:10 so the title starts on screen 1.
const double _photoAspect = 4 / 3;
const double _photoAspectLarge = 16 / 10;

/// Dark fade at the top edge of the photo behind the glass buttons
/// (Konzept 13 §12.1 Nr. 2: black 30 %).
const double _scrimAlpha = 0.3;

/// Glyph of the text-only header when there is no photo.
const double _typoGlyph = 40;

/// Avatar in the author line (Konzept 13 §12.1 Nr. 3).
const double _avatarSize = 28;

/// Height of the photo for [width] at the current text size.
double recipePhotoHeight(BuildContext context, double width) {
  final large =
      context.typography.category.index >= ContentSizeCategory.ax3.index;
  return width / (large ? _photoAspectLarge : _photoAspect);
}

/// The photo edge to edge under the status bar. Pulling down past the top
/// stretches it from its bottom edge ([overscroll] points, rubber band of
/// the scroll view). Without a photo, or when it fails to load, a calm
/// header with the title and the recipe glyph takes its place.
class RecipeDetailPhoto extends StatelessWidget {
  const RecipeDetailPhoto({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.overscroll,
  });

  final String imageUrl;
  final String title;

  /// How far the list is pulled down past its top, in points.
  final ValueListenable<double> overscroll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = recipePhotoHeight(context, width);
        final typo = _TypoHeader(title: title);
        final Widget picture = imageUrl.isEmpty
            ? typo
            : Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth:
                        (width * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    placeholder: (_, _) => ColoredBox(color: colors.fill),
                    errorWidget: (_, _, _) => typo,
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height:
                          GlassToolbar.topOffset(context) +
                          AvoSizes.toolbarButton +
                          AvoSpacing.xxl,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.shadow.withValues(alpha: _scrimAlpha),
                              colors.shadow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
        return ExcludeSemantics(
          child: SizedBox(
            height: height,
            width: width,
            child: ValueListenableBuilder<double>(
              valueListenable: overscroll,
              child: picture,
              builder: (context, over, child) {
                if (over <= 0) return child!;
                return Transform.scale(
                  scale: (height + over) / height,
                  alignment: Alignment.bottomCenter,
                  child: child,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TypoHeader extends StatelessWidget {
  const _TypoHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.fill,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.xxl,
            AvoSizes.toolbarButton,
            AvoSpacing.xxl,
            AvoSpacing.l,
          ),
          // The title below repeats the name, so here it gets only the
          // lines that fit; at very large sizes the glyph stands alone.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final line = context.typography.lineHeightOf(AvoTextStyle.title2);
              final room = constraints.maxHeight - _typoGlyph - AvoSpacing.s;
              final lines = (room / line).floor().clamp(0, 3);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvoIcon(
                      AvoIcons.forkKnife,
                      size: _typoGlyph,
                      color: colors.secondaryLabel,
                    ),
                    if (lines > 0) ...[
                      const SizedBox(height: AvoSpacing.s),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                        style: context.text(
                          AvoTextStyle.title2,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The floating toolbar: back on the left; on the right "Merken" (or
/// "Bearbeiten" for an own recipe), "Teilen" and "Mehr" in one glass
/// capsule. [title] appears inline once the photo has scrolled away.
class RecipeDetailToolbar extends StatelessWidget {
  const RecipeDetailToolbar({
    super.key,
    required this.onBack,
    this.title,
    this.saved,
    this.onSave,
    this.onEdit,
    this.onShare,
    this.onMore,
    this.shareKey,
    this.moreKey,
  });

  final VoidCallback onBack;
  final String? title;

  /// Whether the recipe is saved; null hides "Merken" (own recipe, or the
  /// recipe is not there).
  final bool? saved;
  final VoidCallback? onSave;

  /// Own recipe: the text capsule "Bearbeiten" instead of "Merken".
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onMore;
  final GlobalKey? shareKey;
  final GlobalKey? moreKey;

  @override
  Widget build(BuildContext context) {
    final isSaved = saved;
    final edit = onEdit;
    final share = onShare;
    final more = onMore;
    return GlassToolbar(
      leading: GlassIconButton(
        icon: const AvoIcon(AvoIcons.chevronBack),
        semanticLabel: context.tr('back'),
        onPressed: onBack,
      ),
      title: title,
      trailing: [
        if (edit != null)
          AppButton.secondary(
            label: context.tr('recipe_detail_edit'),
            floating: true,
            onPressed: edit,
          ),
        if (isSaved != null || share != null || more != null)
          GlassButtonGroup(
            items: [
              if (isSaved != null && edit == null)
                GlassGroupItem(
                  icon: AvoIcon(AvoIcons.bookmark, filled: isSaved),
                  semanticLabel: context.tr(
                    isSaved ? 'recipe_detail_unsave' : 'recipe_detail_save',
                  ),
                  onPressed: onSave,
                ),
              if (share != null)
                GlassGroupItem(
                  icon: KeyedSubtree(
                    key: shareKey,
                    child: const AvoIcon(AvoIcons.share),
                  ),
                  semanticLabel: context.tr('recipe_detail_share'),
                  onPressed: share,
                ),
              if (more != null)
                GlassGroupItem(
                  icon: KeyedSubtree(
                    key: moreKey,
                    child: const AvoIcon(AvoIcons.more),
                  ),
                  semanticLabel: context.tr('common_more'),
                  onPressed: more,
                ),
            ],
          ),
      ],
    );
  }
}

/// Title (title1, wraps), meta line ("35 Min · ★ 4,7 (128) · vegetarisch")
/// and the author line ("von Mara Köhler ›", 44 pt, opens the creator page)
/// or the source of an imported recipe ("aus Wikibooks Kochbuch").
class RecipeDetailTitle extends StatelessWidget {
  const RecipeDetailTitle({
    super.key,
    required this.title,
    required this.metaParts,
    this.metaSemantics,
    this.authorName,
    this.authorAvatarUrl,
    this.onAuthor,
    this.sourceLine,
  });

  final String title;

  /// Pieces of the meta line, joined with " · " (one per line from AX1 on).
  final List<String> metaParts;

  /// The meta line for VoiceOver ("35 Minuten, bewertet mit 4,7 …").
  final String? metaSemantics;

  /// The creator; null for imported recipes.
  final String? authorName;
  final String? authorAvatarUrl;
  final VoidCallback? onAuthor;

  /// "aus Wikibooks Kochbuch" instead of the author.
  final String? sourceLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final author = authorName;
    final source = sourceLine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.xl,
        AvoSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text(AvoTextStyle.title1)),
          ),
          if (metaParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.s),
              child: Semantics(
                label: metaSemantics,
                excludeSemantics: metaSemantics != null,
                child: Text(
                  metaParts.join(ax ? '\n' : ' · '),
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ),
            ),
          if (author != null && author.trim().isNotEmpty)
            _AuthorLine(
              name: author,
              avatarUrl: authorAvatarUrl,
              onTap: onAuthor,
            )
          else if (source != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(source, style: context.text(AvoTextStyle.subhead)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.name, this.avatarUrl, this.onTap});

  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.tr('recipe_detail_by', params: {'name': name.trim()});
    final tap = onTap;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Row(
        children: [
          AuthorAvatar(
            name: name,
            avatarUrl: avatarUrl,
            size: _avatarSize,
            backgroundColor: colors.tintSoft,
            initialStyle: context.text(
              AvoTextStyle.caption2,
              color: colors.tint,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AvoSpacing.s),
          Flexible(
            child: Text(label, style: context.text(AvoTextStyle.subhead)),
          ),
          if (tap != null) ...[
            const SizedBox(width: AvoSpacing.xs),
            AvoIcon(
              AvoIcons.chevronRight,
              size: context.typography.sizeOf(AvoTextStyle.footnote),
              color: colors.secondaryLabel,
            ),
          ],
        ],
      ),
    );
    if (tap == null) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(child: row),
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: tap,
      child: PressableScale(onPressed: tap, child: row),
    );
  }
}
