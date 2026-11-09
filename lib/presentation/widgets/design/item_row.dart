import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

// D2 item rows (D2-Komponenten "Artikelzeilen", D2-Liste, X-Einkaufsmodus).
const double _minHeightRegular = 60; // D2 Komponenten (D2-Liste draws 64)
const double _minHeightLarge = 76; // D2 X-Einkaufsmodus `.it`
const double _paddingRegular = 8; // (60 - 44) / 2
const double _paddingLarge = 10; // D2 X-Einkaufsmodus `.it`
const double _gapRegular = AvoSpacing.m; // D2 gap 12
const double _gapLarge = 14; // D2 X-Einkaufsmodus gap 14
const double _hitLarge = 56; // CheckCircle large target (Konzept 00 §12.7)
const double _minHeightCompact = 56; // avo.md §15, D2 X-Avo
const double _paddingCompact = 6; // (56 - 44) / 2
const double _gapCompact = 10; // D2 X-Avo
const double _thumbCompact = 36; // D2 X-Avo
const double _thumbRadiusCompact = 9; // D2 X-Avo

/// Where the hairline of compact rows with an image starts (avo.md §15).
const double _separatorCompact = 88;
const double _doneThumbOpacity = 0.5; // D2 erledigt: image at .5

/// Space between the text and the trailing widget when it moved below.
const double _trailingRunGap = AvoSpacing.xs;

/// The text keeps at least this share of the width before the trailing
/// widget moves below it.
const double _minTextShare = 0.5;

/// Height a layout may exceed its constraints by before it counts as cut
/// (rounding of text metrics).
const double _overflowTolerance = 0.5;

/// Size of an [ItemRow].
enum ItemRowSize {
  /// Lists: 26 pt circle, 44 pt image, 17/22 name, at least 60 pt high.
  regular,

  /// Shopping mode (D2 X-Einkaufsmodus): 36 pt circle in a 56 pt target,
  /// 52 pt image, 20/25 semibold name, at least 76 pt high.
  large,

  /// Dense lists (Avo's result sections, D2 `X-Avo`): 22 pt circle in a 44 pt
  /// target, 36 pt image with radius 9, 17/22 name, at least 56 pt high,
  /// hairline from 88.
  compact,
}

class _RowMetrics {
  const _RowMetrics({
    required this.circle,
    required this.hit,
    required this.thumb,
    required this.thumbRadius,
    required this.gap,
    required this.minHeight,
    required this.padding,
    required this.title,
    required this.checkSize,
    this.titleWeight,
  });

  final double circle;
  final double hit;
  final double thumb;
  final double thumbRadius;
  final double gap;
  final double minHeight;
  final double padding;
  final AvoTextStyle title;
  final FontWeight? titleWeight;
  final CheckCircleSize checkSize;

  /// The leading area that checks the item off: row inset, circle, gap
  /// (Konzept 11 §1.4: "die vorderen 56 pt").
  double get zone => math.max(
    AvoSpacing.l + circle + gap,
    // The check target (44 pt around a 22 pt circle) must fit in the zone.
    AvoSpacing.l - (hit - circle) / 2 + hit,
  );

  /// Where the text starts with an image.
  double get textEdge => zone + thumb + gap;
}

const _regular = _RowMetrics(
  circle: AvoSizes.checkCircle,
  hit: AvoSizes.hitTarget,
  thumb: AvoSizes.thumbSmall,
  thumbRadius: AvoRadii.imageSmall,
  gap: _gapRegular,
  minHeight: _minHeightRegular,
  padding: _paddingRegular,
  title: AvoTextStyle.body,
  checkSize: CheckCircleSize.regular,
);

const _large = _RowMetrics(
  circle: AvoSizes.checkCircleLarge,
  hit: _hitLarge,
  thumb: AvoSizes.thumbMedium,
  thumbRadius: AvoRadii.imageMedium,
  gap: _gapLarge,
  minHeight: _minHeightLarge,
  padding: _paddingLarge,
  title: AvoTextStyle.title3,
  titleWeight: FontWeight.w600,
  checkSize: CheckCircleSize.large,
);

const _compact = _RowMetrics(
  circle: CheckCircle.smallDiameter,
  hit: AvoSizes.hitTarget,
  thumb: _thumbCompact,
  thumbRadius: _thumbRadiusCompact,
  gap: _gapCompact,
  minHeight: _minHeightCompact,
  padding: _paddingCompact,
  title: AvoTextStyle.body,
  checkSize: CheckCircleSize.small,
);

_RowMetrics _metricsOf(ItemRowSize size) => switch (size) {
  ItemRowSize.regular => _regular,
  ItemRowSize.large => _large,
  ItemRowSize.compact => _compact,
};

/// A D2 item row: check circle, image, name and quantity, an optional
/// trailing widget such as the offer pill (Konzept 00 §12.8).
///
/// - The leading area (row inset, circle, gap: 54 pt, 66 pt large) checks
///   the item off with the light haptic; the circle fills on its spring.
/// - The rest of the row runs [onTap] (open the item full screen) with an
///   iOS highlight; without [onTap] it checks the item off too (shopping
///   mode, K-36).
/// - Done: the name turns [AvoColors.secondaryLabel] and is struck through,
///   the image drops to half opacity.
/// - [checkState] shows pending sync, failed ("Nicht gespeichert" below the
///   name in [AvoColors.destructive]) or done by someone else (their
///   initial at the circle for 2 s).
/// - From AX1 the image is left out, [trailing] moves below the text and the
///   circle aligns with the first line (Konzept 11 §1.1). Narrower rows move
///   [trailing] below the text as soon as the text would get less than half
///   the width.
///
/// VoiceOver reads the row as one element ("Avocados, 3 St.", then the
/// trailing widget's label, value "erledigt"); double tap checks it off,
/// [openLabel] and [semanticActions] are custom actions.
///
/// The row draws no hairline: put rows in an `InsetSection` with
/// `separatorIndent: ItemRow.separatorIndentOf(context)`.
class ItemRow extends StatefulWidget {
  /// Creates an item row.
  const ItemRow({
    super.key,
    required this.title,
    this.subtitle,
    this.thumb,
    this.trailing,
    this.checked = false,
    this.onToggle,
    this.onTap,
    this.size = ItemRowSize.regular,
    this.checkState,
    this.checkedBy,
    this.statusLabel,
    this.openLabel,
    this.semanticActions = const {},
    this.trailingSemanticsLabel,
    this.trailingActions = const {},
    this.contextMenuItems = const [],
    this.swipeActions = const [],
    this.leadingSwipeActions = const [],
  });

  /// Hairline inset of regular rows with an image: the text edge, 110 pt
  /// from the row's leading edge (D2-Liste `.sep` left 110; D2-Komponenten
  /// measures the same edge as 94 from the content).
  static const double separatorIndent =
      AvoSpacing.l +
      AvoSizes.checkCircle +
      _gapRegular +
      AvoSizes.thumbSmall +
      _gapRegular;

  /// Hairline inset of shopping-mode rows with an image: the text edge,
  /// 132 pt (D2 X-Einkaufsmodus draws it at 126, 6 pt before its text).
  static const double separatorIndentLarge =
      AvoSpacing.l +
      AvoSizes.checkCircleLarge +
      _gapLarge +
      AvoSizes.thumbMedium +
      _gapLarge;

  /// Hairline inset of compact rows with an image: 88 pt (avo.md §15), a
  /// little before the text, which starts at 95 (the 44 pt check target
  /// needs 49 pt before the image).
  static const double separatorIndentCompact = _separatorCompact;

  /// The hairline inset of rows of [size] for `InsetSection.separatorIndent`:
  /// the text edge (compact rows: 88, before it), taking into account
  /// that the image is left out from AX1 on or when rows have no [thumb]
  /// ([withThumb] false).
  static double separatorIndentOf(
    BuildContext context, {
    ItemRowSize size = ItemRowSize.regular,
    bool withThumb = true,
  }) {
    final m = _metricsOf(size);
    if (!withThumb || context.isAccessibilityText) return m.zone;
    if (size == ItemRowSize.compact) return separatorIndentCompact;
    return m.textEdge;
  }

  /// The item name; wraps, never cut.
  final String title;

  /// Second line, 15/20 [AvoColors.secondaryLabel] with tabular figures:
  /// quantity and note ("2 L", "500 g · für Lasagne", "gerade von Lena").
  final String? subtitle;

  /// The image, laid out at 44 pt (52 pt large, 36 pt compact) and clipped
  /// to radius 10 (12, 9: give compact rows `ItemThumb(radius: 9)`): an [ItemThumb] or Teil B's `ArticleImage`. Decorative for
  /// VoiceOver.
  final Widget? thumb;

  /// At the end, centred on the text (Teil B's offer pill). Below the text
  /// when the row is narrow; from AX1 under the name, beside the quantity
  /// (it wraps below when there is no room). A widget of zero size takes no
  /// space. A tap on it reaches the slot, not [onTap]. Its semantics label
  /// joins the row's, unless [trailingSemanticsLabel] is set.
  final Widget? trailing;

  /// Whether the item is done.
  final bool checked;

  /// Called with the new checked state; null disables checking off.
  final ValueChanged<bool>? onToggle;

  /// Opens the item (full-screen editor). Null: tapping the row checks it
  /// off as well.
  final VoidCallback? onTap;

  /// [ItemRowSize.regular], [ItemRowSize.large] (shopping mode) or
  /// [ItemRowSize.compact].
  final ItemRowSize size;

  /// Sync and ownership state of the circle; defaults from [checked].
  final CheckState? checkState;

  /// Who checked it, for [CheckState.doneByOther] (their initial at the
  /// circle).
  final String? checkedBy;

  /// Status for VoiceOver ("von Lena"); with [CheckState.failed] also the
  /// visible text under the name (default "Nicht gespeichert").
  final String? statusLabel;

  /// VoiceOver name of a custom action that runs [onTap] ("Bearbeiten"),
  /// needed because double tap checks the item off.
  final String? openLabel;

  /// More VoiceOver custom actions by label (the swipe and menu actions:
  /// "Menge ändern", "Verschieben", "Löschen").
  final Map<String, VoidCallback> semanticActions;

  /// What the [trailing] slot says to VoiceOver ("Angebot 1,29 € bei Lidl").
  /// It joins the row's label after the quantity ("Milch, 2 Liter, Angebot
  /// 1,29 € bei Lidl") and the slot's own semantics are hidden, so the slot
  /// cannot be a second stop. Give the slot's actions through
  /// [trailingActions] then, or VoiceOver cannot reach them. Null: the
  /// slot's own semantics stay.
  final String? trailingSemanticsLabel;

  /// The slot's own actions by label ("Angebot ansehen"), offered as custom
  /// actions of the row, since the slot itself is not a VoiceOver stop when
  /// [trailingSemanticsLabel] is set.
  final Map<String, VoidCallback> trailingActions;

  /// Entries of the menu a long press on the row opens (at the finger,
  /// [showAvoMenu]); in every size. Enabled [AvoMenuItem]s are also custom
  /// actions of the row.
  final List<AvoMenuEntry> contextMenuItems;

  /// Actions revealed by swiping towards the end edge ([SwipeActions]); the
  /// first one also runs on a full swipe. Also VoiceOver custom actions.
  final List<SwipeAction> swipeActions;

  /// Actions revealed by swiping towards the start edge.
  final List<SwipeAction> leadingSwipeActions;

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = highlighted (iOS cell press). Created eagerly so that
  /// dispose is never its first access.
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  void _press() {
    _highlight
      ..stop()
      ..value = 1;
  }

  void _release() {
    if (!mounted) return;
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
        snapToEnd: true,
      ),
    );
  }

  CheckState get _state =>
      widget.checkState ?? (widget.checked ? CheckState.done : CheckState.open);

  void _toggle() {
    final onToggle = widget.onToggle;
    if (onToggle == null) return;
    onToggle(!widget.checked);
    unawaited(AvoHaptics.light());
  }

  String _label() => [
    widget.title.trim(),
    if (widget.subtitle?.trim().isNotEmpty ?? false) widget.subtitle!.trim(),
    if (widget.trailingSemanticsLabel?.trim().isNotEmpty ?? false)
      widget.trailingSemanticsLabel!.trim(),
  ].join(', ');

  void _openMenu(Offset globalPosition) {
    if (widget.contextMenuItems.isEmpty) return;
    unawaited(
      showAvoMenu(
        context,
        items: widget.contextMenuItems,
        anchorRect: Rect.fromCenter(
          center: globalPosition,
          width: 1,
          height: 1,
        ),
      ),
    );
  }

  String _value(BuildContext context) {
    final failed = _state == CheckState.failed;
    final status =
        widget.statusLabel ?? (failed ? context.tr('common_not_saved') : null);
    return [
      if (widget.checked && !failed) context.tr('common_checked_state'),
      ?status,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = _metricsOf(widget.size);
    final ax = context.isAccessibilityText;
    final state = _state;
    final failed = state == CheckState.failed;
    final done = widget.checked && !failed;
    final canToggle = widget.onToggle != null;
    final opens = widget.onTap != null;
    final VoidCallback? bodyAction = opens
        ? widget.onTap
        : (canToggle ? _toggle : null);
    final VoidCallback? zoneAction = canToggle ? _toggle : widget.onTap;

    // ---- text
    var titleStyle = context.text(
      m.title,
      weight: m.titleWeight,
      color: done ? colors.secondaryLabel : colors.label,
    );
    if (done) {
      titleStyle = titleStyle.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationColor: colors.secondaryLabel,
      );
    }
    final subtitle = widget.subtitle;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    final slot = widget.trailingSemanticsLabel == null
        ? widget.trailing
        : (widget.trailing == null
              ? null
              : ExcludeSemantics(child: widget.trailing));
    // From AX1 the slot sits under the name, beside the quantity, and wraps
    // below it when there is no room.
    final slotUnderName = ax && slot != null;
    final subtitleText = hasSubtitle
        ? ExcludeSemantics(
            child: Text(
              subtitle,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
                tabular: true,
              ),
            ),
          )
        : null;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Text(widget.title, style: titleStyle)),
        if (slotUnderName)
          Padding(
            padding: const EdgeInsets.only(top: _trailingRunGap),
            child: Wrap(
              spacing: m.gap,
              runSpacing: _trailingRunGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [?subtitleText, slot],
            ),
          )
        else
          ?subtitleText,
        if (failed)
          ExcludeSemantics(
            child: Text(
              widget.statusLabel ?? context.tr('common_not_saved'),
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.destructive,
              ),
            ),
          ),
      ],
    );

    // ---- image
    final thumb = widget.thumb;
    final showThumb = thumb != null && !ax;
    Widget? thumbBox;
    if (showThumb) {
      thumbBox = ExcludeSemantics(
        child: Opacity(
          opacity: done ? _doneThumbOpacity : 1,
          child: SizedBox.square(
            dimension: m.thumb,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(m.thumbRadius),
              child: thumb,
            ),
          ),
        ),
      );
    }

    // ---- body: image, text and trailing, after the check zone
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: m.minHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          m.zone,
          m.padding,
          AvoSpacing.l,
          m.padding,
        ),
        child: Row(
          crossAxisAlignment: ax
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (thumbBox != null) ...[thumbBox, SizedBox(width: m.gap)],
            Expanded(
              child: AdaptiveTrailing(
                gap: m.gap,
                stacked: ax,
                trailing: slotUnderName ? null : slot,
                child: text,
              ),
            ),
          ],
        ),
      ),
    );

    // ---- check zone: full height, circle centred (top-aligned from AX1)
    final firstLine = context.typography.lineHeightOf(m.title);
    final circleTop = math.max(0.0, m.padding + (firstLine - m.hit) / 2);
    final circle = ExcludeSemantics(
      child: CheckCircle(
        checked: widget.checked,
        itemName: widget.title,
        onChanged: canToggle ? (v) => widget.onToggle!(v) : null,
        size: m.checkSize,
        state: widget.checkState,
        byName: widget.checkedBy,
        statusLabel: widget.statusLabel,
      ),
    );
    final zone = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: zoneAction,
      onLongPressStart: widget.contextMenuItems.isEmpty
          ? null
          : (details) => _openMenu(details.globalPosition),
      child: Align(
        alignment: ax
            ? AlignmentDirectional.topStart
            : AlignmentDirectional.centerStart,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            // Puts the visible circle at the row inset, like D2's
            // `margin: 0 -9px` around the 44 pt button.
            start: AvoSpacing.l - (m.hit - m.circle) / 2,
            top: ax ? circleTop : 0,
          ),
          child: circle,
        ),
      ),
    );

    final row = Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: opens ? (_) => _press() : null,
          onTapUp: opens ? (_) => _release() : null,
          onTapCancel: opens ? _release : null,
          onTap: bodyAction,
          onLongPressStart: widget.contextMenuItems.isEmpty
              ? null
              : (details) => _openMenu(details.globalPosition),
          child: body,
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: m.zone,
          child: zone,
        ),
      ],
    );

    final fill = colors.fillStrong;
    final highlighted = AnimatedBuilder(
      animation: _highlight,
      child: row,
      builder: (context, child) {
        final t = _highlight.value.clamp(0.0, 1.0);
        if (t == 0) return child!;
        return ColoredBox(
          color: fill.withValues(alpha: fill.a * t),
          child: child,
        );
      },
    );

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (opens && canToggle && widget.openLabel != null)
        CustomSemanticsAction(label: widget.openLabel!): widget.onTap!,
      for (final entry in widget.semanticActions.entries)
        CustomSemanticsAction(label: entry.key): entry.value,
      for (final entry in widget.trailingActions.entries)
        CustomSemanticsAction(label: entry.key): entry.value,
      for (final entry in widget.contextMenuItems)
        if (entry is AvoMenuItem && entry.enabled)
          CustomSemanticsAction(label: entry.label): entry.onSelected,
      ...SwipeActions.semanticActionsOf(widget.swipeActions),
      ...SwipeActions.semanticActionsOf(widget.leadingSwipeActions),
    };

    return RepaintBoundary(
      child: Semantics(
        container: true,
        button: bodyAction != null,
        checked: widget.checked,
        enabled: canToggle || opens,
        label: _label(),
        value: _value(context),
        onTap: canToggle ? _toggle : widget.onTap,
        customSemanticsActions: actions.isEmpty ? null : actions,
        child: SwipeActions(
          trailingActions: widget.swipeActions,
          leadingActions: widget.leadingSwipeActions,
          exposeSemantics: false,
          child: highlighted,
        ),
      ),
    );
  }
}

/// The frame of an item image: rounded corners and a neutral [AvoColors.fill]
/// square while there is no picture, while it loads and when it fails
/// (Konzept 00 §13: no spinner, the loaded photo fades in).
///
/// It fills the box it is given (an [ItemRow] gives 44 or 52 pt), otherwise
/// [size]. The radius follows the D2 scale for that side: 10 up to 44 pt, 12
/// up to 52 pt, 20 above. Decorative for VoiceOver unless [semanticLabel]
/// is set.
class ItemThumb extends StatelessWidget {
  /// Creates an item image frame.
  const ItemThumb({
    super.key,
    this.image,
    this.placeholder,
    this.size = AvoSizes.thumbSmall,
    this.radius,
    this.semanticLabel,
  });

  /// The picture, drawn with [BoxFit.cover]. Null shows the neutral square.
  final ImageProvider? image;

  /// Optional glyph centred on the neutral square (a category symbol).
  final Widget? placeholder;

  /// Side in points when the parent does not give a size.
  final double size;

  /// Corner radius; defaults to [radiusFor] the laid-out side.
  final double? radius;

  /// VoiceOver text; null hides the image from VoiceOver.
  final String? semanticLabel;

  /// The D2 radius for an image of [side] points.
  static double radiusFor(double side) {
    if (side <= AvoSizes.thumbSmall) return AvoRadii.imageSmall;
    if (side <= AvoSizes.thumbMedium) return AvoRadii.imageMedium;
    return AvoRadii.imageLarge;
  }

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.fill;
    Widget neutral() => ColoredBox(
      color: fill,
      child: placeholder == null ? null : Center(child: placeholder),
    );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? constraints.biggest.shortestSide
            : size;
        final picture = image;
        final Widget inner = picture == null
            ? neutral()
            : Image(
                image: picture,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => neutral(),
                frameBuilder: (context, child, frame, sync) {
                  if (sync) return child;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      neutral(),
                      AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: AvoMotion.fadeReduced,
                        curve: Curves.easeInOut,
                        child: child,
                      ),
                    ],
                  );
                },
              );
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius ?? radiusFor(side)),
          child: SizedBox.square(dimension: side, child: inner),
        );
      },
    );

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: content);
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(child: content),
    );
  }
}

/// Lays out [child] and a [trailing] widget side by side, [trailing] at the
/// end and vertically centred on [child], as long as [child] keeps at least
/// half the width. Otherwise, and always when [stacked], [trailing] moves
/// below [child] at the start.
///
/// A [trailing] of zero size (a Teil B slot that renders nothing) takes no
/// space and adds no gap. Used by [ItemRow] and the list rows; takes the
/// full width it is given.
class AdaptiveTrailing extends MultiChildRenderObjectWidget {
  /// Creates the layout.
  AdaptiveTrailing({
    super.key,
    required Widget child,
    Widget? trailing,
    this.gap = AvoSpacing.m,
    this.runGap = _trailingRunGap,
    this.stacked = false,
  }) : super(children: [child, ?trailing]);

  /// Horizontal space between [child] and the trailing widget.
  final double gap;

  /// Vertical space when the trailing widget sits below [child].
  final double runGap;

  /// Always put the trailing widget below (accessibility text sizes).
  final bool stacked;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAdaptiveTrailing(
        gap: gap,
        runGap: runGap,
        stacked: stacked,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderAdaptiveTrailing)
      ..gap = gap
      ..runGap = runGap
      ..stacked = stacked
      ..textDirection = Directionality.of(context);
  }
}

class _AdaptiveParentData extends ContainerBoxParentData<RenderBox> {}

typedef _Placement = ({Size size, Offset child, Offset trailing});

class _RenderAdaptiveTrailing extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _AdaptiveParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _AdaptiveParentData> {
  _RenderAdaptiveTrailing({
    required double gap,
    required double runGap,
    required bool stacked,
    required TextDirection textDirection,
  }) : _gap = gap,
       _runGap = runGap,
       _stacked = stacked,
       _textDirection = textDirection;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _runGap;
  set runGap(double value) {
    if (value == _runGap) return;
    _runGap = value;
    markNeedsLayout();
  }

  bool _stacked;
  set stacked(bool value) {
    if (value == _stacked) return;
    _stacked = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AdaptiveParentData) {
      child.parentData = _AdaptiveParentData();
    }
  }

  RenderBox? get _main => firstChild;
  RenderBox? get _trailing =>
      firstChild == null ? null : childAfter(firstChild!);

  bool _sideBySide(double width, double trailingWidth) =>
      !_stacked && width - trailingWidth - _gap >= width * _minTextShare;

  /// The natural size (before [constraints] clamp it) and the offsets.
  _Placement _place(BoxConstraints constraints, ChildLayouter layoutChild) {
    final main = _main;
    if (main == null) {
      return (
        size: constraints.smallest,
        child: Offset.zero,
        trailing: Offset.zero,
      );
    }
    final maxWidth = constraints.maxWidth;
    final bounded = maxWidth.isFinite;
    final rtl = _textDirection == TextDirection.rtl;
    final trailing = _trailing;
    final trailingSize = trailing == null
        ? Size.zero
        : layoutChild(trailing, BoxConstraints(maxWidth: maxWidth));
    final hasTrailing = !trailingSize.isEmpty;

    if (!hasTrailing) {
      final s = layoutChild(main, BoxConstraints(maxWidth: maxWidth));
      final width = math.max(
        bounded ? maxWidth : s.width,
        constraints.minWidth,
      );
      return (
        size: Size(width, s.height),
        child: Offset(rtl ? width - s.width : 0, 0),
        trailing: Offset.zero,
      );
    }

    if (!bounded || _sideBySide(maxWidth, trailingSize.width)) {
      final mainMax = bounded
          ? maxWidth - trailingSize.width - _gap
          : double.infinity;
      final s = layoutChild(main, BoxConstraints(maxWidth: mainMax));
      final width = math.max(
        bounded ? maxWidth : s.width + _gap + trailingSize.width,
        constraints.minWidth,
      );
      final height = math.max(
        math.max(s.height, trailingSize.height),
        constraints.minHeight,
      );
      return (
        size: Size(width, height),
        child: Offset(rtl ? width - s.width : 0, (height - s.height) / 2),
        trailing: Offset(
          rtl ? 0 : width - trailingSize.width,
          (height - trailingSize.height) / 2,
        ),
      );
    }

    final s = layoutChild(main, BoxConstraints(maxWidth: maxWidth));
    return (
      size: Size(maxWidth, s.height + _runGap + trailingSize.height),
      child: Offset(rtl ? maxWidth - s.width : 0, 0),
      trailing: Offset(
        rtl ? maxWidth - trailingSize.width : 0,
        s.height + _runGap,
      ),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints
      .constrain(_place(constraints, ChildLayoutHelper.dryLayoutChild).size);

  @override
  void performLayout() {
    final placement = _place(constraints, ChildLayoutHelper.layoutChild);
    size = constraints.constrain(placement.size);
    assert(() {
      // Text cannot shrink: a parent with too little height would cut it
      // without a Flex overflow error, so report it like one.
      final over = placement.size.height - size.height;
      if (over > _overflowTolerance) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'AdaptiveTrailing needs ${over.toStringAsFixed(1)} pt more '
              'height than its parent allows; its text would be cut. Put it '
              'in a scroll view or give it room to grow.',
            ),
            library: 'shoply design',
          ),
        );
      }
      return true;
    }());
    final main = _main;
    if (main != null) {
      (main.parentData! as _AdaptiveParentData).offset = placement.child;
    }
    final trailing = _trailing;
    if (trailing != null) {
      (trailing.parentData! as _AdaptiveParentData).offset = placement.trailing;
    }
  }

  double _trailingWidth() =>
      _trailing?.getMaxIntrinsicWidth(double.infinity) ?? 0;

  @override
  double computeMinIntrinsicWidth(double height) {
    final main = _main?.getMinIntrinsicWidth(height) ?? 0;
    final trailing = _trailing?.getMinIntrinsicWidth(height) ?? 0;
    return math.max(main, trailing);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final main = _main?.getMaxIntrinsicWidth(height) ?? 0;
    final trailing = _trailingWidth();
    return trailing == 0 ? main : main + _gap + trailing;
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox box, double width) height,
  ) {
    final main = _main;
    if (main == null) return 0;
    final trailing = _trailing;
    final tw = _trailingWidth();
    final th = trailing == null || tw == 0 ? 0.0 : height(trailing, tw);
    if (th == 0) return height(main, width);
    if (!width.isFinite || _sideBySide(width, tw)) {
      final mainWidth = width.isFinite ? width - tw - _gap : width;
      return math.max(height(main, mainWidth), th);
    }
    return height(main, width) + _runGap + height(trailing!, width);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (box, w) => box.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (box, w) => box.getMaxIntrinsicHeight(w));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
