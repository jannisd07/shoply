import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/routes/route_paths.dart';

/// Space between the toolbar row and the large title (D2-Liste: 8).
const double _kTitleTop = AvoSpacing.s; // D2

/// Space between the toolbar and the content of a page with an inline title.
const double _kInlineTop = AvoSpacing.l; // D2

/// Where a page's content has to stay clear of at the bottom.
enum OffersPageBottom {
  /// Pushed inside a tab: the floating tab bar.
  tabBar,

  /// Full screen above the tab bar: the home indicator.
  safeArea,
}

/// The frame of the offer screens (D2): content scrolling under a
/// [ScrollEdgeFade] and the floating glass toolbar with a back (or close)
/// button.
///
/// With [largeTitle] the page opens with a large title 34/41 that wraps and
/// never ends in an ellipsis; once it scrolled away the toolbar shows it
/// inline. Without, the inline title is always there (third levels,
/// editors). [onRefresh] adds pull to refresh at the top. [onBack] replaces
/// going back (S11 asks before it drops a change); without it the page
/// pops, or goes to the list overview when it was opened on its own (a
/// deep link).
class OffersPage extends StatefulWidget {
  const OffersPage({
    super.key,
    required this.title,
    required this.children,
    this.largeTitle = true,
    this.close = false,
    this.trailing = const [],
    this.onRefresh,
    this.onBack,
    this.bottom = OffersPageBottom.tabBar,
  });

  /// Large and inline title.
  final String title;

  /// The content below the title, top to bottom.
  final List<Widget> children;

  final bool largeTitle;

  /// An xmark "Schließen" instead of the chevron "Zurück" (picking,
  /// editing).
  final bool close;

  /// Toolbar items at the end ("Fertig").
  final List<Widget> trailing;

  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;
  final OffersPageBottom bottom;

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
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
    final onBack = widget.onBack;
    if (onBack != null) return onBack();
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    final popped = await navigator.maybePop();
    if (!popped && mounted) router?.go(RoutePaths.lists);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    _threshold = context.typography.lineHeightOf(AvoTextStyle.largeTitle);
    final top = GlassToolbar.topOffset(context) + AvoSizes.toolbarButton;
    final bottom = widget.bottom == OffersPageBottom.tabBar
        ? ShellInsets.bottom(context)
        : MediaQuery.paddingOf(context).bottom + AvoSpacing.section;
    final refresh = widget.onRefresh;

    return ColoredBox(
      color: colors.background,
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
                    top: top + (widget.largeTitle ? _kTitleTop : _kInlineTop),
                  ),
                  sliver: SliverToBoxAdapter(
                    child: widget.largeTitle
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AvoSpacing.screen,
                            ),
                            child: Semantics(
                              header: true,
                              child: Text(
                                widget.title,
                                style: context.text(AvoTextStyle.largeTitle),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // Built at once: these pages are short, and every part
                // keeps its size while the page scrolls.
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottom)),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade(color: colors.background),
          ),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _inline,
              builder: (context, show, _) => GlassToolbar(
                leading: GlassIconButton(
                  icon: AvoIcon(
                    widget.close ? AvoIcons.xmark : AvoIcons.chevronBack,
                  ),
                  semanticLabel: context.tr(
                    widget.close ? 'common_close' : 'back',
                  ),
                  onPressed: () => unawaited(_back()),
                ),
                title: !widget.largeTitle || show ? widget.title : null,
                trailing: widget.trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width sentence under a large title or at the top of a page (S9,
/// S11, S15): 16 pt from the screen edges, [style] in `label`.
class OffersLead extends StatelessWidget {
  const OffersLead(
    this.text, {
    super.key,
    this.style = AvoTextStyle.callout,
    this.top = AvoSpacing.s,
  });

  final String text;
  final AvoTextStyle style;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(AvoSpacing.screen, top, AvoSpacing.screen, 0),
    child: Text(text, style: context.text(style)),
  );
}

/// A footnote line under a group (13/18 `secondaryLabel`): 6 pt below it,
/// 32 pt from the screen edges, 16 pt from AX1 on where groups run edge to
/// edge (D2 X-Angebote `.ft`).
class OffersFootnote extends StatelessWidget {
  const OffersFootnote(this.text, {super.key, this.top = 6, this.side}); // D2

  final String text;
  final double top;

  /// Distance from the edges; defaults to the screen footnote's (32, 16
  /// from AX1 on). Inside a frame that keeps the margin itself: 16.
  final double? side;

  @override
  Widget build(BuildContext context) {
    final side =
        this.side ??
        (context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.xxxl);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, top, side, 0),
      child: Text(
        text,
        style: context.text(
          AvoTextStyle.footnote,
          color: context.colors.secondaryLabel,
        ),
      ),
    );
  }
}
