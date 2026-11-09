import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// iOS swipe action metrics (D2 draws none; Konzept 00 §12.20, Apple lists).
const double _cellWidth = 80; // iOS trailing action width
const double _cellWidthAx = 120; // iOS: wider from AX1 so labels keep size
const double _iconSize = 22; // iOS SF Symbol in a swipe action

/// A swipe past this share of the row width (or a flick that would carry it
/// there) runs the first action.
const double _fullSwipeShare = 0.6;

/// A drag faster than this (points per second) settles with the springy
/// [AvoMotion.fling]; a slow one with [AvoMotion.standard].
const double _flingVelocity = 500;

/// Pixels the row has to be pulled before the reveal is built at all.
const double _revealEpsilon = 0.01;

/// Where an offset counts as open or closed.
const double _openEpsilon = 0.5;

/// One action behind a swiped row.
@immutable
class SwipeAction {
  /// Creates an action.
  const SwipeAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  /// The visible text and the VoiceOver custom action name ("Löschen").
  final String label;

  /// Runs when the surface is tapped, the row is swiped fully (first action
  /// only) or VoiceOver triggers the custom action.
  final VoidCallback onPressed;

  /// Glyph above the label; left out from AX1 on.
  final AvoIconData? icon;

  /// Draws the surface in `destructiveFill` (white text) instead of the
  /// tint. Put the destructive action first.
  final bool destructive;
}

/// Swipe a row sideways to show action surfaces (A-V17, A-K12): the iOS
/// `swipeActions` of a list row.
///
/// - Swiping towards the start reveals [trailingActions] at the end edge,
///   swiping towards the end reveals [leadingActions] at the start edge. The
///   first action of a list is the outermost one. Up to full width the
///   surfaces share the revealed space; beyond that the first one stretches.
/// - Releasing past the open position settles open on the
///   [AvoMotion.standard] spring (slight overshoot after a flick,
///   [AvoMotion.fling]); a drag past [_fullSwipeShare] of the width, or a
///   flick that would carry it there, runs the first action ([fullSwipe]).
///   Crossing that threshold plays the light haptic once, in both directions.
/// - An open row closes on a tap; its content takes no taps meanwhile. Reduce
///   Motion: the row jumps instead of springing.
/// - Every action is also a VoiceOver custom action, added to the enclosing
///   semantics node ([exposeSemantics]); a row that builds its own node (the
///   rows of this design system) sets it false and adds
///   [SwipeActions.semanticActionsOf] to its own actions.
///
/// A side without actions rubber-bands a little instead of opening. The row
/// fills the width it is given.
class SwipeActions extends StatefulWidget {
  /// Creates a swipeable row.
  const SwipeActions({
    super.key,
    required this.child,
    this.trailingActions = const [],
    this.leadingActions = const [],
    this.fullSwipe = true,
    this.enabled = true,
    this.exposeSemantics = true,
    this.borderRadius = BorderRadius.zero,
  });

  /// The row.
  final Widget child;

  /// Actions at the end edge (swipe towards the start). First = outermost.
  final List<SwipeAction> trailingActions;

  /// Actions at the start edge (swipe towards the end). First = outermost.
  final List<SwipeAction> leadingActions;

  /// A full swipe runs the first action of that side.
  final bool fullSwipe;

  /// False turns the whole thing off and returns [child] unchanged.
  final bool enabled;

  /// Adds the actions as custom actions to the enclosing semantics node.
  final bool exposeSemantics;

  /// Rounds the action surfaces (the card radius of a card row).
  final BorderRadiusGeometry borderRadius;

  /// The VoiceOver custom actions for [actions], later entries after earlier.
  static Map<CustomSemanticsAction, VoidCallback> semanticActionsOf(
    Iterable<SwipeAction> actions,
  ) => {
    for (final a in actions) CustomSemanticsAction(label: a.label): a.onPressed,
  };

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  /// The row's offset towards the start in points; positive reveals the
  /// trailing actions, negative the leading ones.
  late final AnimationController _offset;

  /// The finger's travel before rubber banding.
  double _raw = 0;
  double _width = 0;
  bool _armed = false;
  int _settleToken = 0;

  /// Read in build: gesture callbacks may fire while the tree is torn down.
  bool _reduceMotion = false;
  bool _rtl = false;
  double _cell = _cellWidth;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  List<SwipeAction> _side(double direction) =>
      direction >= 0 ? widget.trailingActions : widget.leadingActions;

  bool get _isOpen => _offset.value.abs() > _openEpsilon;

  void _settle(double target, {double velocity = 0, VoidCallback? then}) {
    final token = ++_settleToken;
    if (!mounted) return;
    if (_reduceMotion) {
      _offset
        ..stop()
        ..value = target;
      then?.call();
      return;
    }
    final spring = velocity.abs() > _flingVelocity
        ? AvoMotion.fling
        : AvoMotion.standard;
    unawaited(
      _offset
          .animateWith(
            SpringSimulation(
              spring,
              _offset.value,
              target,
              velocity,
              snapToEnd: true,
            ),
          )
          .then((_) {
            if (mounted && token == _settleToken) then?.call();
          }),
    );
  }

  void _close() => _settle(0);

  void _run(SwipeAction action) {
    _close();
    action.onPressed();
  }

  void _start(DragStartDetails details) {
    _settleToken++;
    _offset.stop();
    _raw = _offset.value;
    final box = context.findRenderObject();
    _width = box is RenderBox && box.hasSize ? box.size.width : 0;
    _armed = _isArmed(_offset.value);
  }

  bool _isArmed(double value) =>
      widget.fullSwipe &&
      _width > 0 &&
      value.abs() >= _fullSwipeShare * _width &&
      _side(value).isNotEmpty;

  double _clampOffset(double raw) {
    final hasActions = _side(raw).isNotEmpty;
    final limit = _width <= 0 ? 0.0 : _width;
    final magnitude = raw.abs();
    if (hasActions) return raw.sign * math.min(magnitude, limit);
    return raw.sign * AvoMotion.rubberBand(magnitude, math.max(limit, 1));
  }

  void _update(DragUpdateDetails details) {
    final dx = details.primaryDelta ?? 0;
    // Towards the start (left in LTR) reveals the trailing actions.
    _raw += _rtl ? dx : -dx;
    final next = _clampOffset(_raw);
    _offset.value = next;
    final armed = _isArmed(next);
    if (armed != _armed) {
      _armed = armed;
      unawaited(AvoHaptics.light());
    }
  }

  void _end(DragEndDetails details) {
    final raw = details.primaryVelocity ?? 0;
    final velocity = _rtl ? raw : -raw; // positive = towards trailing
    final projected = _offset.value + AvoMotion.project(velocity);
    final actions = _side(projected);
    if (actions.isEmpty) {
      _settle(0, velocity: velocity);
      return;
    }
    final total = actions.length * _cell;
    final magnitude = projected.abs();
    final direction = projected.sign;
    if (widget.fullSwipe &&
        _width > 0 &&
        magnitude >= _fullSwipeShare * _width) {
      final first = actions.first;
      _settle(
        direction * _width,
        velocity: velocity,
        then: () {
          first.onPressed();
          _close();
        },
      );
    } else if (magnitude > total / 2) {
      _settle(direction * total, velocity: velocity);
    } else {
      _settle(0, velocity: velocity);
    }
  }

  Widget _reveal(BuildContext context, double offset) {
    final colors = context.colors;
    final trailingSide = offset > 0;
    final actions = trailingSide
        ? widget.trailingActions
        : widget.leadingActions;
    final count = actions.length;
    final magnitude = offset.abs();
    final spread = magnitude <= count * _cell;
    // Visual order from the start edge: the outermost action is the first.
    final ordered = trailingSide ? actions.reversed.toList() : actions;
    final children = <Widget>[
      for (final action in ordered)
        if (spread || identical(action, actions.first))
          Expanded(
            child: _ActionCell(
              action: action,
              width: _cell,
              colors: colors,
              onTap: () => _run(action),
            ),
          )
        else
          SizedBox(
            width: _cell,
            child: _ActionCell(
              action: action,
              width: _cell,
              colors: colors,
              onTap: () => _run(action),
            ),
          ),
    ];
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: trailingSide ? null : 0,
      end: trailingSide ? 0 : null,
      width: magnitude,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActions =
        widget.trailingActions.isNotEmpty || widget.leadingActions.isNotEmpty;
    if (!widget.enabled || !hasActions) return widget.child;
    _reduceMotion = context.reduceMotion;
    _rtl = Directionality.of(context) == TextDirection.rtl;
    _cell = context.isAccessibilityText ? _cellWidthAx : _cellWidth;

    final swipe = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _start,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _offset,
          child: widget.child,
          builder: (context, child) {
            final value = _offset.value;
            final open = _isOpen;
            final shift = _rtl ? value : -value;
            return Stack(
              children: [
                if (value.abs() > _revealEpsilon)
                  _reveal(context, value)
                else
                  const SizedBox.shrink(),
                Transform.translate(
                  offset: Offset(shift, 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: open ? _close : null,
                    child: AbsorbPointer(absorbing: open, child: child),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (!widget.exposeSemantics) return swipe;
    return Semantics(
      customSemanticsActions: SwipeActions.semanticActionsOf([
        ...widget.trailingActions,
        ...widget.leadingActions,
      ]),
      child: swipe,
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.action,
    required this.width,
    required this.colors,
    required this.onTap,
  });

  final SwipeAction action;
  final double width;
  final AvoColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glyph = action.icon;
    final showIcon = glyph != null && !context.isAccessibilityText;
    final style = context.text(
      AvoTextStyle.caption1,
      weight: FontWeight.w600,
      color: colors.onTint,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: ColoredBox(
        color: action.destructive ? colors.destructiveFill : colors.tintFill,
        child: ClipRect(
          child: OverflowBox(
            minWidth: width,
            maxWidth: width,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(AvoSpacing.xs),
              // The surface is only as high as its row: scale the content
              // down instead of cutting it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcon) ...[
                      AvoIcon(glyph, size: _iconSize, color: colors.onTint),
                      const SizedBox(height: AvoSpacing.xxs),
                    ],
                    Text(
                      action.label,
                      style: style,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
