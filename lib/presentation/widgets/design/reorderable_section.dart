import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

// A-C9 sortable rows (angebote.md S13): the look of InsetSection with a drag
// handle at the end of every row.
const double _handleGlyph = 18; // AvoIcons.line3Horizontal: 18 pt, stroke 2
const double _liftScale = 1.02; // the lifted row grows a little
const double _shadowAlpha = 0.18; // D2 `.glass` drop, a little softer
const double _shadowBlur = 14; // D2
const Offset _shadowOffset = Offset(0, 4); // D2

/// Sortable rows in the look of an [InsetSection] (radius 26, hairlines
/// between the rows, heading and footnote), each with a drag handle
/// ([AvoIcons.line3Horizontal]) in a 44 pt target at the end.
///
/// - Press and hold the handle: the row lifts (a little larger, a shadow, the
///   selection haptic), follows the finger and the rows it passes move aside
///   on the [AvoMotion.move] spring; every new slot ticks with the selection
///   haptic. Releasing settles the row into its slot and then calls
///   [onReorder]. Reduce Motion: no springs, the rows jump.
/// - VoiceOver: the handle is its own element ("Milch umsortieren", value
///   "Position 2 von 5") with the custom actions "Nach oben" and "Nach
///   unten"; after a move the new position is announced.
/// - Each child needs a unique [Key] so that its state follows the item when
///   [onReorder] reorders the list. Children bring their own padding and
///   minimum height (`ItemRow`, `NavRow`); the handle adds 44 pt at the end.
///
/// The list does not scroll itself; very long lists belong in a screen with
/// a different pattern (the lists here have a handful of rows).
class ReorderableInsetSection extends StatefulWidget {
  /// Creates a sortable group.
  const ReorderableInsetSection({
    super.key,
    required this.children,
    required this.labels,
    required this.onReorder,
    this.header,
    this.headerTrailing,
    this.footer,
    this.separatorIndent = AvoSpacing.l,
    this.plain = false,
  }) : assert(children.length == labels.length);

  /// The rows, first to last; each with a unique key.
  final List<Widget> children;

  /// What VoiceOver calls each row ("Lidl"), one per child.
  final List<String> labels;

  /// Called after a move with the row's old index and the index it has after
  /// the move: `list.insert(newIndex, list.removeAt(oldIndex))`. It is also
  /// called for the VoiceOver actions.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Heading above the group in normal spelling ([SectionCaps]).
  final String? header;

  /// Widget at the end of the heading.
  final Widget? headerTrailing;

  /// Footnote below the group.
  final String? footer;

  /// Start inset of the hairlines in points.
  final double separatorIndent;

  /// Edge to edge without rounding, as [InsetSection.plain].
  final bool plain;

  @override
  State<ReorderableInsetSection> createState() =>
      _ReorderableInsetSectionState();
}

class _ReorderableInsetSectionState extends State<ReorderableInsetSection>
    with TickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();

  /// Where each row is displaced to make room, in points.
  List<AnimationController> _shift = const [];

  /// The lifted row's travel from its slot, and how far it is lifted (0..1).
  late final AnimationController _drag;
  late final AnimationController _lift;

  int? _dragIndex;
  int _target = 0;
  List<double> _extents = const [];
  List<double> _tops = const [];
  bool _settling = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _drag = AnimationController.unbounded(vsync: this);
    _lift = AnimationController.unbounded(vsync: this);
    _syncControllers();
  }

  void _syncControllers() {
    final n = widget.children.length;
    if (_shift.length == n) return;
    for (final c in _shift) {
      c.dispose();
    }
    _shift = [
      for (var i = 0; i < n; i++) AnimationController.unbounded(vsync: this),
    ];
  }

  @override
  void didUpdateWidget(ReorderableInsetSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _dragIndex = null;
      _settling = false;
      _drag.value = 0;
      _lift.value = 0;
      _syncControllers();
    }
  }

  @override
  void dispose() {
    for (final c in _shift) {
      c.dispose();
    }
    _drag.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _springTo(AnimationController c, double target, {double velocity = 0}) {
    if (!mounted) return;
    if (_reduceMotion) {
      c
        ..stop()
        ..value = target;
      return;
    }
    c.animateWith(
      SpringSimulation(
        AvoMotion.move,
        c.value,
        target,
        velocity,
        snapToEnd: true,
      ),
    );
  }

  // ------------------------------------------------------------------ drag

  void _measure() {
    final box = _stackKey.currentContext?.findRenderObject();
    final extents = box is _RenderRowStack ? box.extents : const <double>[];
    _extents = extents;
    var y = 0.0;
    _tops = [
      for (final h in extents)
        () {
          final top = y;
          y += h;
          return top;
        }(),
    ];
  }

  double get _total => _extents.fold(0.0, (a, b) => a + b);

  void _startDrag(int index) {
    if (_dragIndex != null || index >= widget.children.length) return;
    _measure();
    if (_extents.length != widget.children.length) return;
    setState(() {
      _dragIndex = index;
      _target = index;
    });
    _drag
      ..stop()
      ..value = 0;
    _springTo(_lift, 1);
    unawaited(AvoHaptics.selection());
  }

  /// Where the lifted row ends up when dropped at [target].
  double _offsetFor(int index, int target) {
    var sum = 0.0;
    if (target > index) {
      for (var j = index + 1; j <= target; j++) {
        sum += _extents[j];
      }
      return sum;
    }
    for (var j = target; j < index; j++) {
      sum += _extents[j];
    }
    return -sum;
  }

  void _moveDrag(double dy) {
    final index = _dragIndex;
    if (index == null || _settling) return;
    final minDy = -_tops[index];
    final maxDy = _total - _tops[index] - _extents[index];
    final clamped = dy.clamp(minDy, math.max(minDy, maxDy)).toDouble();
    _drag.value = clamped;
    final center = _tops[index] + _extents[index] / 2 + clamped;
    var target = 0;
    if (dy >= maxDy) {
      target = _extents.length - 1; // pulled to the bottom edge
    } else if (dy > minDy) {
      for (var j = 0; j < _extents.length; j++) {
        if (j == index) continue;
        if (_tops[j] + _extents[j] / 2 < center) target++;
      }
    }
    if (target == _target) return;
    _target = target;
    unawaited(AvoHaptics.selection());
    for (var j = 0; j < _shift.length; j++) {
      var to = 0.0;
      if (j != index) {
        if (target > index && j > index && j <= target) to = -_extents[index];
        if (target < index && j >= target && j < index) to = _extents[index];
      }
      _springTo(_shift[j], to);
    }
  }

  void _endDrag({required bool cancelled}) {
    final index = _dragIndex;
    if (index == null || _settling) return;
    final target = cancelled ? index : _target;
    _settling = true;
    if (cancelled) {
      for (final c in _shift) {
        _springTo(c, 0);
      }
    }
    _springTo(_lift, 0);
    final to = _offsetFor(index, target);
    void finish() {
      if (!mounted) return;
      if (target != index) {
        _announce(index, target);
        widget.onReorder(index, target);
      }
      for (final c in _shift) {
        c.value = 0;
      }
      _drag.value = 0;
      setState(() {
        _dragIndex = null;
        _settling = false;
      });
    }

    if (_reduceMotion || (_drag.value - to).abs() < 0.5) {
      _drag.value = to;
      finish();
      return;
    }
    unawaited(
      _drag
          .animateWith(
            SpringSimulation(
              AvoMotion.move,
              _drag.value,
              to,
              0,
              snapToEnd: true,
            ),
          )
          .then((_) => finish()),
    );
  }

  // ------------------------------------------------------------ VoiceOver

  void _moveBy(int index, int delta) {
    final target = index + delta;
    if (_dragIndex != null || target < 0 || target >= widget.children.length) {
      return;
    }
    unawaited(AvoHaptics.selection());
    _announce(index, target);
    widget.onReorder(index, target);
  }

  void _announce(int from, int to) {
    final text = context.tr(
      'common_reorder_moved',
      params: {
        'name': widget.labels[from],
        'position': '${to + 1}',
        'count': '${widget.children.length}',
      },
    );
    final direction = Directionality.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.maybeOf(context);
      if (view == null) return;
      unawaited(SemanticsService.sendAnnouncement(view, text, direction));
    });
  }

  // ----------------------------------------------------------------- build

  Widget _row(BuildContext context, int index) {
    final colors = context.colors;
    final count = widget.children.length;
    final child = widget.children[index];
    final last = index == count - 1;

    final handle = Semantics(
      container: true,
      label: context.tr(
        'common_reorder_handle',
        params: {'name': widget.labels[index]},
      ),
      value: context.tr(
        'common_reorder_position',
        params: {'position': '${index + 1}', 'count': '$count'},
      ),
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: context.tr('common_move_up')): () =>
              _moveBy(index, -1),
        if (index < count - 1)
          CustomSemanticsAction(label: context.tr('common_move_down')): () =>
              _moveBy(index, 1),
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onLongPressStart: (_) => _startDrag(index),
          onLongPressMoveUpdate: (d) => _moveDrag(d.offsetFromOrigin.dy),
          onLongPressEnd: (_) => _endDrag(cancelled: false),
          onLongPressCancel: () => _endDrag(cancelled: true),
          child: SizedBox.square(
            dimension: AvoSizes.hitTarget,
            child: Center(
              child: AvoIcon(
                AvoIcons.line3Horizontal,
                size: _handleGlyph,
                color: colors.secondaryLabel,
              ),
            ),
          ),
        ),
      ),
    );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: child),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xs),
          child: handle,
        ),
      ],
    );

    final withHairline = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (!last)
          Padding(
            padding: EdgeInsetsDirectional.only(start: widget.separatorIndent),
            child: SizedBox(
              height: AvoSizes.hairline,
              child: ColoredBox(color: colors.separator),
            ),
          ),
      ],
    );

    return KeyedSubtree(
      // Derived from the child's key, so the row's state follows the item.
      key: child.key == null ? ValueKey<int>(index) : ValueKey<Key>(child.key!),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shift[index], _drag, _lift]),
        child: withHairline,
        builder: (context, content) {
          // The same widgets whether lifted or not: the handle's gesture
          // must survive the lift (a changed structure would rebuild it and
          // end the long press).
          final lifted = index == _dragIndex;
          final t = lifted ? _lift.value.clamp(0.0, 1.0) : 0.0;
          return Transform.translate(
            offset: Offset(0, lifted ? _drag.value : _shift[index].value),
            child: Transform.scale(
              scale: _reduceMotion ? 1 : 1 + (_liftScale - 1) * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: lifted ? colors.surface : null,
                  boxShadow: !lifted
                      ? null
                      : [
                          BoxShadow(
                            color: colors.shadow.withValues(
                              alpha: _shadowAlpha * t,
                            ),
                            blurRadius: _shadowBlur,
                            offset: _shadowOffset,
                          ),
                        ],
                ),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    _syncControllers();
    final n = widget.children.length;
    return InsetSection(
      header: widget.header,
      headerTrailing: widget.headerTrailing,
      footer: widget.footer,
      plain: widget.plain,
      children: n == 0
          ? const []
          : [
              _RowStack(
                key: _stackKey,
                liftedIndex: _dragIndex,
                children: [for (var i = 0; i < n; i++) _row(context, i)],
              ),
            ],
    );
  }
}

/// Stacks its children vertically at the full width and paints the lifted
/// one last, so it passes over the others while they move aside.
class _RowStack extends MultiChildRenderObjectWidget {
  const _RowStack({super.key, required super.children, this.liftedIndex});

  final int? liftedIndex;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowStack(liftedIndex: liftedIndex);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderRowStack).liftedIndex = liftedIndex;
  }
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRowStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderRowStack({int? liftedIndex}) : _liftedIndex = liftedIndex;

  int? _liftedIndex;
  set liftedIndex(int? value) {
    if (value == _liftedIndex) return;
    _liftedIndex = value;
    markNeedsPaint();
  }

  /// The laid-out height of every row (hairline included), in order.
  List<double> get extents {
    final out = <double>[];
    var child = firstChild;
    while (child != null) {
      out.add(child.size.height);
      child = childAfter(child);
    }
    return out;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  double _width(BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = _width(constraints);
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      height += child
          .getDryLayout(BoxConstraints.tightFor(width: width))
          .height;
      child = childAfter(child);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final width = _width(constraints);
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      (child.parentData! as _RowParentData).offset = Offset(0, y);
      y += child.size.height;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0.0,
    (m, c) => math.max(m, c.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _children.fold(
    0.0,
    (m, c) => math.max(m, c.getMaxIntrinsicWidth(height)),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _children.fold(0.0, (s, c) => s + c.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _children.fold(0.0, (s, c) => s + c.getMaxIntrinsicHeight(width));

  Iterable<RenderBox> get _children sync* {
    var child = firstChild;
    while (child != null) {
      yield child;
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? lifted;
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _RowParentData;
      if (index == _liftedIndex) {
        lifted = child;
      } else {
        context.paintChild(child, data.offset + offset);
      }
      child = data.nextSibling;
      index++;
    }
    if (lifted != null) {
      context.paintChild(
        lifted,
        (lifted.parentData! as _RowParentData).offset + offset,
      );
    }
  }
}
