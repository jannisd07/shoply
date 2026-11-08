import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

// D2-Artikel toolbar: glass back (or X-Essen close) left, title 17/22
// semibold centred, `.glass-tint` capsule "Fertig" right: 44 high, padding
// 0 18, radius 22, 17/22 semibold white. Content starts at 110 on a 47 pt
// status bar: toolbar 54 to 98, then 12.
const double _itemGap = 8; // D2 toolbar gap
const double _doneSide = 18; // D2
const double _doneVertical = 11; // D2 (44 - 22) / 2
const double _doneRadius = AvoSizes.toolbarButton / 2; // D2 22
const double _closeGlyph = 18; // D2 X-Essen
const double _headerBottom = AvoSpacing.m; // D2 110 - 98
const double _titleGap = AvoSpacing.s; // title under the buttons (AX)
const double _disabledOpacity = 0.4; // Konzept 00 §12.20

/// The leading glass button of a [FullScreenEditor].
enum EditorLeading {
  /// An X ("Schließen"): for editors opened as a cover from the bottom.
  close,

  /// A back chevron ("Zurück"): for editors pushed from the right.
  back,
}

/// The frame of every edit screen (Konzept 00 §12.23 replaced: editing is
/// full screen, never a sheet; D2-Artikel, X-Essen).
///
/// - Screen background, content scrolls under a floating glass toolbar with
///   the D2 scroll edge fade.
/// - Left a glass close (X) or back button, the title centred (17/22
///   semibold, a VoiceOver header naming the screen), right the tinted
///   capsule "Fertig" when [onDone] is set.
/// - The title stays on the toolbar row while it fits on one line between
///   the buttons; otherwise (large text, long titles) it wraps under them.
///   Nothing is cut, and nothing in the frame has a fixed height.
/// - The keyboard shrinks the scroll area, so the focused field stays
///   visible; [bottom] (a primary button, X-Essen "Eintragen") sits above it.
/// - With [dirty], close, back, Escape and the system back ask
///   "Änderungen verwerfen?" ([showAvoConfirm]) and the swipe back is off.
///   Without changes they close at once.
///
/// The editor never closes itself on "Fertig": [onDone] saves and pops, for
/// example `Navigator.of(context).pop(result)`. Open it with
/// [pushFullScreenEditor].
class FullScreenEditor extends StatefulWidget {
  /// Creates an edit screen with [child] (or [slivers]) as its content.
  const FullScreenEditor({
    super.key,
    required this.title,
    this.child,
    this.slivers,
    this.leading = EditorLeading.close,
    this.leadingLabel,
    this.onDone,
    this.doneLabel,
    this.doneEnabled = true,
    this.working = false,
    this.workingLabel,
    this.dirty = false,
    this.bottom,
  }) : assert(
         (child == null) != (slivers == null),
         'Pass either child or slivers.',
       );

  /// The screen title, for example "Artikel" or "Mittagessen eintragen".
  final String title;

  /// The content, laid out at full width under the toolbar. Bring your own
  /// 16 pt side margins (inset groups have them).
  final Widget? child;

  /// The content as slivers, for long lists. Use either this or [child].
  final List<Widget>? slivers;

  /// Close (X) or back chevron; [EditorLeading.close] by default.
  final EditorLeading leading;

  /// VoiceOver label of the leading button; defaults to "Schließen" or
  /// "Zurück". Pass "Zurück zu Wocheneinkauf" where D2 shows it.
  final String? leadingLabel;

  /// Shows the tinted "Fertig" capsule and is called when it is tapped.
  final VoidCallback? onDone;

  /// Label of the done capsule; defaults to "Fertig".
  final String? doneLabel;

  /// False dims "Fertig" (40 %) and ignores taps, for example while a
  /// required field is empty.
  final bool doneEnabled;

  /// Saving: an activity indicator replaces the label (same width), taps on
  /// "Fertig" are blocked.
  final bool working;

  /// VoiceOver value of "Fertig" while [working], for example "Wird
  /// gespeichert". Announced through a live region.
  final String? workingLabel;

  /// There are unsaved changes: closing asks first.
  final bool dirty;

  /// A widget pinned under the content and above the keyboard, for example
  /// `AppButton.primary(size: AppButtonSize.large, expand: true)`.
  final Widget? bottom;

  @override
  State<FullScreenEditor> createState() => _FullScreenEditorState();
}

class _FullScreenEditorState extends State<FullScreenEditor> {
  bool _asking = false;

  Future<void> _attemptClose() async {
    if (_asking) return;
    final navigator = Navigator.of(context);
    if (widget.dirty) {
      _asking = true;
      final discard = await showAvoConfirm(
        context,
        title: context.tr('common_discard_changes_title'),
        confirmLabel: context.tr('common_discard'),
        cancelLabel: context.tr('common_keep_editing'),
      );
      _asking = false;
      if (!discard || !mounted) return;
    }
    // `pop` ignores the PopScope below, which only vetoes `maybePop`.
    if (navigator.canPop()) navigator.pop();
  }

  Widget _header(BuildContext context, {required bool twin}) {
    final colors = context.colors;
    final title = widget.title;
    final onDone = widget.onDone;
    final titleStyle = context.text(AvoTextStyle.headline);

    final Widget leading;
    if (twin) {
      leading = const SizedBox.square(dimension: AvoSizes.toolbarButton);
    } else {
      final close = widget.leading == EditorLeading.close;
      leading = GlassIconButton(
        icon: close
            ? const AvoIcon(AvoIcons.xmark, size: _closeGlyph)
            : const AvoIcon(AvoIcons.chevronBack),
        semanticLabel:
            widget.leadingLabel ?? context.tr(close ? 'common_close' : 'back'),
        onPressed: _attemptClose,
      );
    }

    final titleText = twin
        ? _TwinText(title, style: titleStyle, textAlign: TextAlign.center)
        : Semantics(
            header: true,
            namesRoute: true,
            child: Text(title, style: titleStyle, textAlign: TextAlign.center),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        GlassToolbar.topOffset(context),
        AvoSpacing.screen,
        _headerBottom,
      ),
      child: _HeaderLayout(
        leading: leading,
        title: titleText,
        trailing: onDone == null
            ? null
            : _DoneCapsule(
                label: widget.doneLabel ?? context.tr('done'),
                onDone: onDone,
                enabled: widget.doneEnabled,
                working: widget.working,
                workingLabel: widget.workingLabel,
                twin: twin,
                foreground: colors.onTint,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = widget.child;
    final hasBottom = widget.bottom != null;

    // An invisible twin of the toolbar as the first sliver: it has exactly
    // the toolbar's height in the same layout pass, so the content starts
    // under it at any text size without measuring after the frame.
    final scroll = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(opacity: 0, child: _header(context, twin: true)),
            ),
          ),
        ),
        if (child != null)
          SliverToBoxAdapter(child: child)
        else
          ...widget.slivers!,
        SliverToBoxAdapter(child: _ScrollEndGap(safeArea: !hasBottom)),
      ],
    );

    return PopScope<Object?>(
      canPop: !widget.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptClose();
      },
      child: ColoredBox(
        color: colors.background,
        child: _KeyboardInset(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // VoiceOver reads the toolbar first, then the content
                    // (both start at the top edge, so geometry cannot decide).
                    Positioned.fill(
                      child: Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(1),
                        child: scroll,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Semantics(
                        container: true,
                        explicitChildNodes: true,
                        sortKey: const OrdinalSortKey(0),
                        child: Stack(
                          children: [
                            const Positioned.fill(child: ScrollEdgeFade()),
                            _header(context, twin: false),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasBottom) _BottomBar(child: widget.bottom!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [builder] (usually a [FullScreenEditor]) full screen on the root
/// navigator, above the tab bar.
///
/// [cover] (default) slides it up from the bottom and closes it downwards
/// (editors with an X); false pushes it from the right with the iOS swipe
/// back (editors with a back chevron). Reduce Motion: a short cross-fade.
Future<T?> pushFullScreenEditor<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool cover = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final PageRoute<T> route = context.reduceMotion
      ? _FadeEditorRoute<T>(builder: builder, fullscreenDialog: cover)
      : CupertinoPageRoute<T>(builder: builder, fullscreenDialog: cover);
  return navigator.push<T>(route);
}

class _FadeEditorRoute<T> extends PageRoute<T> {
  _FadeEditorRoute({required this.builder, super.fullscreenDialog});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AvoMotion.fadeReduced;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    child: child,
  );
}

/// Shrinks its child by the keyboard height. Only this widget depends on the
/// keyboard inset, so the editor is not rebuilt per keyboard frame.
class _KeyboardInset extends StatelessWidget {
  const _KeyboardInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: child,
      ),
    );
  }
}

/// Space after the content: the home indicator (unless the bottom bar takes
/// it) plus a section gap.
class _ScrollEndGap extends StatelessWidget {
  const _ScrollEndGap({required this.safeArea});

  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final safe = safeArea ? MediaQuery.paddingOf(context).bottom : 0.0;
    return SizedBox(height: safe + AvoSpacing.section);
  }
}

/// The pinned bottom action: 16 pt margins, ends at the home indicator
/// (D2 X-Essen) or 16 pt above the keyboard.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.s,
        AvoSpacing.screen,
        math.max(safe, AvoSpacing.l),
      ),
      child: child,
    );
  }
}

/// The text the way [Text] would lay it out (text scaler, Bold Text), but as
/// a [RichText], so the invisible toolbar twin does not show up as a second
/// copy of the title for finders.
class _TwinText extends StatelessWidget {
  const _TwinText(this.data, {required this.style, this.textAlign});

  final String data;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final effective = MediaQuery.boldTextOf(context)
        ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
    return RichText(
      text: TextSpan(text: data, style: effective),
      textAlign: textAlign ?? TextAlign.start,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
  }
}

/// The tinted "Fertig" capsule (D2-Artikel): 17/22 semibold white, at least
/// 44 × 44, padding 0 18; grows and wraps with large text.
class _DoneCapsule extends StatelessWidget {
  const _DoneCapsule({
    required this.label,
    required this.onDone,
    required this.enabled,
    required this.working,
    required this.workingLabel,
    required this.twin,
    required this.foreground,
  });

  final String label;
  final VoidCallback onDone;
  final bool enabled;
  final bool working;
  final String? workingLabel;
  final bool twin;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final style = context.text(
      AvoTextStyle.body,
      color: foreground,
      weight: FontWeight.w600,
    );
    Widget text = twin
        ? _TwinText(label, style: style, textAlign: TextAlign.center)
        : Text(label, style: style, textAlign: TextAlign.center);
    if (working && !twin) {
      // The invisible label keeps the width.
      text = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: text),
          Positioned.fill(
            child: Center(child: CupertinoActivityIndicator(color: foreground)),
          ),
        ],
      );
    }

    final face = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AvoSizes.toolbarButton,
        minWidth: AvoSizes.hitTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _doneSide,
          vertical: _doneVertical,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: text),
      ),
    );
    if (twin) return face;

    Widget box = GlassSurface(
      shape: GlassShape.rounded,
      radius: _doneRadius,
      tinted: true,
      child: face,
    );
    if (!enabled) box = Opacity(opacity: _disabledOpacity, child: box);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      value: working ? workingLabel : null,
      liveRegion: working ? true : null,
      onTap: enabled && !working ? onDone : null,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: enabled ? onDone : null,
        enabled: !working,
        child: box,
      ),
    );
  }
}

enum _HeaderSlot { leading, title, trailing }

/// Leading and trailing on one row with the title centred between them
/// when it fits on one line with equal room on both sides; otherwise the
/// title wraps on its own row under them. Height follows the children
/// (minimum 44 pt).
class _HeaderLayout
    extends SlottedMultiChildRenderObjectWidget<_HeaderSlot, RenderBox> {
  const _HeaderLayout({
    required this.leading,
    required this.title,
    this.trailing,
  });

  final Widget leading;
  final Widget title;
  final Widget? trailing;

  @override
  Iterable<_HeaderSlot> get slots => _HeaderSlot.values;

  @override
  Widget? childForSlot(_HeaderSlot slot) => switch (slot) {
    _HeaderSlot.leading => leading,
    _HeaderSlot.title => title,
    _HeaderSlot.trailing => trailing,
  };

  @override
  _RenderHeaderLayout createRenderObject(BuildContext context) =>
      _RenderHeaderLayout(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeaderLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _HeaderGeometry {
  const _HeaderGeometry(this.size, this.offsets);

  final Size size;
  final Map<RenderBox, Offset> offsets;
}

class _RenderHeaderLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_HeaderSlot, RenderBox> {
  _RenderHeaderLayout({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_HeaderSlot.leading);
  RenderBox? get _title => childForSlot(_HeaderSlot.title);
  RenderBox? get _trailing => childForSlot(_HeaderSlot.trailing);

  // Reading order for paint, hit testing and VoiceOver, like a navigation
  // bar: leading, title, trailing.
  @override
  Iterable<RenderBox> get children => [
    if (_leading != null) _leading!,
    if (_title != null) _title!,
    if (_trailing != null) _trailing!,
  ];

  _HeaderGeometry _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final leading = _leading;
    final title = _title;
    final trailing = _trailing;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    const loose = BoxConstraints();

    final leadingSize = leading == null
        ? Size.zero
        : layoutChild(leading, loose.copyWith(maxWidth: width / 2));
    final leadingSpace = leading == null ? 0.0 : leadingSize.width + _itemGap;
    final trailingSize = trailing == null
        ? Size.zero
        : layoutChild(
            trailing,
            loose.copyWith(maxWidth: math.max(0.0, width - leadingSpace)),
          );

    var rowHeight = math.max(
      AvoSizes.toolbarButton,
      math.max(leadingSize.height, trailingSize.height),
    );

    // Equal room on both sides keeps the title centred on the screen.
    final side = math.max(leadingSize.width, trailingSize.width) + _itemGap;
    final inlineWidth = width - 2 * side;
    final inline =
        title != null &&
        inlineWidth > 0 &&
        title.getMaxIntrinsicWidth(double.infinity) <= inlineWidth + 0.5;

    var height = rowHeight;
    var titleSize = Size.zero;
    var titleY = 0.0;
    if (title != null) {
      if (inline) {
        titleSize = layoutChild(title, loose.copyWith(maxWidth: inlineWidth));
        rowHeight = math.max(rowHeight, titleSize.height);
        height = rowHeight;
        titleY = (rowHeight - titleSize.height) / 2;
      } else {
        titleSize = layoutChild(title, loose.copyWith(maxWidth: width));
        titleY = rowHeight + _titleGap;
        height = titleY + titleSize.height;
      }
    }
    final size = constraints.constrain(Size(width, height));

    double x(double ltr, Size child) => _textDirection == TextDirection.ltr
        ? ltr
        : size.width - ltr - child.width;
    double y(Size child) => (rowHeight - child.height) / 2;

    return _HeaderGeometry(size, {
      if (leading != null) leading: Offset(x(0, leadingSize), y(leadingSize)),
      if (title != null)
        title: Offset(x((size.width - titleSize.width) / 2, titleSize), titleY),
      if (trailing != null)
        trailing: Offset(
          x(size.width - trailingSize.width, trailingSize),
          y(trailingSize),
        ),
    });
  }

  @override
  void performLayout() {
    final geometry = _compute(constraints, ChildLayoutHelper.layoutChild);
    size = geometry.size;
    geometry.offsets.forEach((child, offset) {
      (child.parentData! as BoxParentData).offset = offset;
    });
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double computeMinIntrinsicWidth(double height) =>
      children.fold(0.0, (sum, c) => sum + c.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      children.fold(0.0, (sum, c) => sum + c.getMaxIntrinsicWidth(height)) +
      _itemGap * math.max(0, children.length - 1);

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints.tightFor(width: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, parentData.offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children.toList().reversed) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
