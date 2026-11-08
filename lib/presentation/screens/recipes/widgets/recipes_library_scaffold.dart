import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/dietary_preference.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/allergen_matcher.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// Space between the toolbar row and the large title (D2-Liste: 8).
const double _kTitleTop = AvoSpacing.s; // D2

/// Space between the large title and its meta line (D2-Liste: 6).
const double _kMetaTop = 6; // D2

/// A full swipe acts once the row moved this share of its width (as in the
/// list, Konzept 11 §1.1).
const double _kSwipeThreshold = 0.6;

/// Icon size in swipe backgrounds.
const double _kSwipeIcon = 20;

/// The frame of every library push screen (D2 style): a large title 34/41
/// under the floating glass back button, content scrolling beneath the
/// [ScrollEdgeFade], and the title moving into the toolbar once the large
/// title has scrolled away.
///
/// [header] replaces the large title (the creator page puts its profile
/// head there). [plain] uses the white background of D2-Rezepte instead of
/// the grouped grey. Pull to refresh runs [onRefresh].
class RecipesLibraryPage extends StatefulWidget {
  const RecipesLibraryPage({
    super.key,
    required this.title,
    this.subtitle,
    this.header,
    this.collapseAfter,
    required this.slivers,
    this.trailing = const [],
    this.onRefresh,
    this.plain = false,
  });

  /// Large title and inline title.
  final String title;

  /// Meta line under the large title ("12 Rezepte").
  final String? subtitle;

  /// Replaces the large title block.
  final Widget? header;

  /// Scroll offset after which the inline title shows; defaults to the
  /// large title's line height.
  final double? collapseAfter;

  /// The content below the title.
  final List<Widget> slivers;

  /// Toolbar items at the end (a tinted plus, a menu).
  final List<Widget> trailing;

  /// Pull to refresh.
  final Future<void> Function()? onRefresh;

  /// White background (grids) instead of the grouped grey (inset rows).
  final bool plain;

  @override
  State<RecipesLibraryPage> createState() => _RecipesLibraryPageState();
}

class _RecipesLibraryPageState extends State<RecipesLibraryPage> {
  final _scroll = ScrollController();
  final _inline = ValueNotifier<bool>(false);
  double _threshold = 41;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _inline.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > _threshold;
    if (_inline.value != show) _inline.value = show;
  }

  Future<void> _back() async {
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    final popped = await navigator.maybePop();
    // A deep link may have opened this page on its own: go to the tab.
    if (!popped && mounted) router?.go(RoutePaths.recipes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = widget.plain
        ? colors.backgroundPlain
        : colors.background;
    _threshold =
        widget.collapseAfter ??
        context.typography.lineHeightOf(AvoTextStyle.largeTitle);

    final refresh = widget.onRefresh;
    final subtitle = widget.subtitle;
    final head =
        widget.header ??
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  style: context.text(AvoTextStyle.largeTitle),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: _kMetaTop),
                Text(
                  subtitle,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ],
            ],
          ),
        );

    return ColoredBox(
      color: background,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (refresh != null)
                  CupertinoSliverRefreshControl(onRefresh: refresh),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top:
                        GlassToolbar.topOffset(context) +
                        AvoSizes.toolbarButton +
                        _kTitleTop,
                  ),
                  sliver: SliverToBoxAdapter(child: head),
                ),
                ...widget.slivers,
                SliverToBoxAdapter(
                  child: SizedBox(height: ShellInsets.bottom(context)),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade(color: background),
          ),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _inline,
              builder: (context, show, _) => GlassToolbar(
                leading: GlassIconButton(
                  icon: const AvoIcon(AvoIcons.chevronBack),
                  semanticLabel: context.tr('back'),
                  onPressed: _back,
                ),
                title: show ? widget.title : null,
                trailing: widget.trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one status line under the title: offline, or loading failed with
/// "Erneut versuchen". Renders nothing when neither applies.
class LibraryStatus extends StatelessWidget {
  const LibraryStatus({
    super.key,
    this.offline = false,
    this.failed = false,
    this.hasContent = true,
    this.onRetry,
  });

  final bool offline;

  /// The last load failed.
  final bool failed;

  /// Something (cached) is on screen.
  final bool hasContent;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!offline && !failed) return const SizedBox.shrink();
    final Widget row;
    if (offline) {
      row = StatusRow(
        kind: StatusKind.offline,
        text: context.tr(
          hasContent ? 'recipe_lib_offline' : 'recipe_lib_offline_empty',
        ),
      );
    } else {
      row = StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr('recipe_lib_load_failed'),
        actionLabel: onRetry == null ? null : context.tr('common_try_again'),
        onAction: onRetry,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AvoSpacing.m),
      child: row,
    );
  }
}

/// A recipe photo for a row: the [ItemThumb] frame with the photo decoded
/// at the size it is shown, the neutral square while there is none.
class LibraryRecipeThumb extends StatelessWidget {
  const LibraryRecipeThumb({super.key, required this.url, this.file});

  /// Network photo; empty shows the neutral square.
  final String url;

  /// Local photo (drafts), used instead of [url].
  final ImageProvider? file;

  @override
  Widget build(BuildContext context) {
    final px = (AvoSizes.thumbSmall * MediaQuery.devicePixelRatioOf(context))
        .round();
    ImageProvider? image;
    final local = file;
    if (local != null) {
      image = ResizeImage(local, width: px, allowUpscaling: false);
    } else if (url.isNotEmpty) {
      image = ResizeImage(
        CachedNetworkImageProvider(url),
        width: px,
        allowUpscaling: false,
      );
    }
    return ItemThumb(
      image: image,
      placeholder: AvoIcon(
        AvoIcons.forkKnife,
        size: _kSwipeIcon,
        color: context.colors.secondaryLabel,
      ),
    );
  }
}

/// A recipe photo filling a [RecipeCard] box, decoded at its width.
class LibraryCardPhoto extends StatelessWidget {
  const LibraryCardPhoto({super.key, required this.url, required this.width});

  final String url;

  /// Laid-out width in points (half the screen in a two-column grid).
  final double width;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.expand();
    final px = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return Image(
      image: ResizeImage(
        CachedNetworkImageProvider(url),
        width: px,
        allowUpscaling: false,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }
}

/// Swipe to the start to act on a row (Konzept 13 §7.3, §9.3, §10.3,
/// §11.3): a neutral grey "Entfernen" for things that only leave this list,
/// red for deleting. A full swipe past 60 % acts; with [confirm] the row
/// waits for the answer of the confirmation dialog first.
class LibrarySwipe extends StatelessWidget {
  const LibrarySwipe({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.onSwiped,
    required this.child,
    this.destructive = false,
    this.confirm,
    this.enabled = true,
  });

  /// Stable id of the row.
  final String id;
  final String label;
  final AvoIconData icon;
  final VoidCallback onSwiped;
  final Widget child;

  /// Red background (final actions) instead of neutral grey.
  final bool destructive;

  /// Asked before the row leaves; false snaps it back.
  final Future<bool> Function()? confirm;

  /// False shows the row without the swipe (offline deletes).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!enabled) return ColoredBox(color: colors.surface, child: child);
    final fill = destructive
        ? colors.destructive
        : Color.alphaBlend(colors.fillStrong, colors.surface);
    final ink = destructive ? colors.onTint : colors.label;
    final ask = confirm;
    return Dismissible(
      key: ValueKey<String>('library-swipe-$id'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _kSwipeThreshold},
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          unawaited(AvoHaptics.light());
        }
      },
      confirmDismiss: ask == null ? null : (_) => ask(),
      onDismissed: (_) => onSwiped(),
      background: ColoredBox(
        color: fill,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvoIcon(icon, size: _kSwipeIcon, color: ink),
                if (!context.isAccessibilityText) ...[
                  const SizedBox(width: AvoSpacing.s),
                  Text(
                    label,
                    maxLines: 1,
                    style: context.text(
                      AvoTextStyle.subhead,
                      weight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      child: ColoredBox(color: colors.surface, child: child),
    );
  }
}

/// Long press opens [items] as a pull-down menu from the row (the context
/// menu of Konzept 13 §9.3, §10.3). VoiceOver gets the same entries as
/// custom actions on the row itself.
class LibraryPressMenu extends StatelessWidget {
  const LibraryPressMenu({
    super.key,
    required this.items,
    required this.child,
    this.semanticLabel,
  });

  final List<AvoMenuEntry> Function() items;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onLongPress: () =>
          showAvoMenu(context, items: items(), semanticLabel: semanticLabel),
      child: child,
    );
  }
}

// --------------------------------------------------------------- allergens

/// Names of the person's allergies found in [recipe] (Konzept 13 §2.3:
/// shown on every card, never hidden). Matches the ingredient names with
/// word boundaries and compounds; empty without allergies.
List<String> libraryAllergenNames(
  BuildContext context,
  Recipe recipe,
  List<String> allergies,
) {
  if (allergies.isEmpty || recipe.ingredients.isEmpty) return const [];
  final matches = AllergenMatcher(
    allergies,
  ).matchesAll(recipe.ingredients.map((i) => i.name));
  return [
    for (final m in matches)
      if (m.type case final AllergyType type)
        context.tr('recipe_lib_allergen_${type.name}')
      else
        m.allergy.trim(),
  ];
}

/// "Enthält Erdnüsse" with the warning symbol, in label colour (never
/// shortened). Renders nothing without [names].
class LibraryAllergenBadge extends StatelessWidget {
  const LibraryAllergenBadge({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final text = context.tr(
      'recipe_lib_contains',
      params: {'names': names.join(', ')},
    );
    final style = context.text(AvoTextStyle.footnote);
    final size = context.typography.sizeOf(AvoTextStyle.footnote);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: context.typography.lineHeightOf(AvoTextStyle.footnote),
              child: Center(
                widthFactor: 1,
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: size,
                  color: colors.destructive,
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.xs),
            Flexible(child: Text(text, style: style)),
          ],
        ),
      ),
    );
  }
}
