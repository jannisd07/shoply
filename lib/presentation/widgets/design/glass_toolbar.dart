import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';

const double _topGap = 7; // D2: toolbar top 54 under a 47 pt status bar
const double _itemGap = 8; // D2: gap between toolbar items

/// Below this width beside the buttons the title moves to its own line
/// under them (large text sizes on narrow screens).
const double _minTitleWidth = 80;
const double _fadeSolidStop = 0.3; // D2: linear-gradient(bg 30 %, transparent)

/// The top row of the floating layer (D2 toolbar): [leading] at the start,
/// [trailing] at the end, an optional [title] centred on the screen.
///
/// At least 44 pt high and 16 pt in from the screen edges; the row grows
/// with its contents (large text sizes), it never clips them. The title is
/// 17/22 semibold on one line with an ellipsis and is a VoiceOver header.
/// The bar has no background: put [GlassIconButton]s, a [GlassButtonGroup]
/// or a floating [AppButton] in it, and a [ScrollEdgeFade] behind it.
///
/// It does not apply the status bar inset itself. Position it at
/// [GlassToolbar.topOffset], for example in a `Positioned(top:
/// GlassToolbar.topOffset(context), left: 0, right: 0)`.
class GlassToolbar extends StatelessWidget {
  /// Creates a toolbar row.
  const GlassToolbar({
    super.key,
    this.leading,
    this.title,
    this.trailing = const [],
  });

  /// Usually a back or close [GlassIconButton].
  final Widget? leading;

  /// Inline title ("Artikel"). Centred on the screen when there is room,
  /// otherwise centred between [leading] and [trailing].
  final String? title;

  /// Items at the end, 8 pt apart, for example a [GlassButtonGroup] and a
  /// tinted [GlassIconButton], or a floating primary [AppButton] ("Fertig").
  /// The last one may shrink (its label wraps) when space runs out.
  final List<Widget> trailing;

  /// Distance of the toolbar's top edge from the top of the screen: the
  /// status bar inset plus 7 pt (D2: 54 pt on a 47 pt status bar).
  static double topOffset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _topGap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: _ToolbarLayout(
        leading: leading,
        middle: title == null
            ? null
            : Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text(AvoTextStyle.headline),
                ),
              ),
        trailing: trailing.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < trailing.length; i++) ...[
                    if (i > 0) const SizedBox(width: _itemGap),
                    if (i == trailing.length - 1)
                      Flexible(child: trailing[i])
                    else
                      trailing[i],
                  ],
                ],
              ),
      ),
    );
  }
}

/// The D2 scroll edge: a fade from the screen background (solid for the
/// first 30 %) to transparent, under the top toolbar, so content scrolling
/// beneath stays out of the way of the glass buttons.
///
/// Fills the available width; place it at the top of the screen's stack,
/// below the [GlassToolbar]. Lets every touch through and is hidden from
/// VoiceOver.
class ScrollEdgeFade extends StatelessWidget {
  /// Creates the top scroll edge fade.
  const ScrollEdgeFade({
    super.key,
    this.height = AvoSizes.scrollEdge,
    this.color,
  });

  /// Height of the fade; [AvoSizes.scrollEdge] (110 pt, D2) by default.
  final double height;

  /// The screen background it fades from. Defaults to
  /// [AvoColors.background]; pass [AvoColors.backgroundPlain] on plain
  /// screens (D2 Rezepte).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.background;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [base, base.withValues(alpha: 0)],
                stops: const [_fadeSolidStop, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ToolbarSlot { leading, middle, trailing }

/// Lays out leading, middle and trailing like a navigation bar, but with a
/// height that follows the children (minimum 44 pt) instead of a fixed one.
class _ToolbarLayout
    extends SlottedMultiChildRenderObjectWidget<_ToolbarSlot, RenderBox> {
  const _ToolbarLayout({this.leading, this.middle, this.trailing});

  final Widget? leading;
  final Widget? middle;
  final Widget? trailing;

  @override
  Iterable<_ToolbarSlot> get slots => _ToolbarSlot.values;

  @override
  Widget? childForSlot(_ToolbarSlot slot) => switch (slot) {
    _ToolbarSlot.leading => leading,
    _ToolbarSlot.middle => middle,
    _ToolbarSlot.trailing => trailing,
  };

  @override
  _RenderToolbarLayout createRenderObject(BuildContext context) =>
      _RenderToolbarLayout(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderToolbarLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _ToolbarGeometry {
  const _ToolbarGeometry(this.size, this.offsets);

  final Size size;
  final Map<RenderBox, Offset> offsets;
}

class _RenderToolbarLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<_ToolbarSlot, RenderBox> {
  _RenderToolbarLayout({required TextDirection textDirection})
    : _textDirection = textDirection;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => childForSlot(_ToolbarSlot.leading);
  RenderBox? get _middle => childForSlot(_ToolbarSlot.middle);
  RenderBox? get _trailing => childForSlot(_ToolbarSlot.trailing);

  // Reading order for paint, hit testing and VoiceOver.
  @override
  Iterable<RenderBox> get children => [
    if (_leading != null) _leading!,
    if (_middle != null) _middle!,
    if (_trailing != null) _trailing!,
  ];

  _ToolbarGeometry _compute(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final leading = _leading;
    final middle = _middle;
    final trailing = _trailing;
    final maxWidth = constraints.maxWidth;
    final bounded = maxWidth.isFinite;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);

    // Leading gets at most half the row when something trails it.
    final leadingMax = !bounded
        ? double.infinity
        : trailing != null
        ? math.max(0.0, (maxWidth - _itemGap) / 2)
        : maxWidth;
    final leadingSize = leading == null
        ? Size.zero
        : layoutChild(leading, loose.copyWith(maxWidth: leadingMax));
    final leadingSpace = leading == null ? 0.0 : leadingSize.width + _itemGap;

    final trailingSize = trailing == null
        ? Size.zero
        : layoutChild(
            trailing,
            loose.copyWith(
              maxWidth: bounded
                  ? math.max(0.0, maxWidth - leadingSpace)
                  : double.infinity,
            ),
          );
    final trailingSpace = trailing == null
        ? 0.0
        : trailingSize.width + _itemGap;

    final besideWidth = bounded
        ? math.max(0.0, maxWidth - leadingSpace - trailingSpace)
        : double.infinity;
    // Too little room beside the buttons: the title gets its own line.
    final titleBelow =
        middle != null && bounded && besideWidth < _minTitleWidth;
    final middleSize = middle == null
        ? Size.zero
        : layoutChild(
            middle,
            loose.copyWith(maxWidth: titleBelow ? maxWidth : besideWidth),
          );

    final contentWidth = leadingSpace + middleSize.width + trailingSpace;
    final width = bounded ? maxWidth : contentWidth;
    final rowHeight = [
      AvoSizes.toolbarButton,
      leadingSize.height,
      if (!titleBelow) middleSize.height,
      trailingSize.height,
    ].reduce(math.max);
    final height = titleBelow
        ? rowHeight + _itemGap + middleSize.height
        : rowHeight;
    final size = constraints.constrain(Size(width, height));

    // Middle: centred on the row, pushed aside by leading/trailing if needed.
    var middleX = (size.width - middleSize.width) / 2;
    if (!titleBelow) {
      final minX = leadingSpace;
      final maxX = size.width - trailingSpace - middleSize.width;
      if (middleX > maxX) middleX = maxX;
      if (middleX < minX) middleX = minX;
    }

    double y(Size child) => (rowHeight - child.height) / 2;
    double x(double ltr, Size child) => _textDirection == TextDirection.ltr
        ? ltr
        : size.width - ltr - child.width;

    return _ToolbarGeometry(size, {
      if (leading != null) leading: Offset(x(0, leadingSize), y(leadingSize)),
      if (middle != null)
        middle: Offset(
          x(middleX, middleSize),
          titleBelow ? rowHeight + _itemGap : y(middleSize),
        ),
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
      _sumWidths((child) => child.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sumWidths((child) => child.getMaxIntrinsicWidth(height));

  double _sumWidths(double Function(RenderBox child) width) {
    final all = children.toList();
    if (all.isEmpty) return 0;
    return all.map(width).reduce((a, b) => a + b) + _itemGap * (all.length - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => width.isFinite
      ? _compute(
          BoxConstraints(maxWidth: width),
          ChildLayoutHelper.dryLayoutChild,
        ).size.height
      : _maxHeight((child) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  double _maxHeight(double Function(RenderBox child) height) =>
      children.map(height).fold(AvoSizes.toolbarButton, math.max);

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
