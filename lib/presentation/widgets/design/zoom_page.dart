import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// Where a zoom page grows from (Konzept 18 §8.2, `springMorph`): the
/// element that was tapped, or the spot of the last tap, or nothing (the
/// page then grows from the middle of the screen).
abstract final class ZoomOrigin {
  static Rect? _pending;
  static DateTime? _pendingAt;

  static Offset? _lastTap;
  static DateTime? _lastTapAt;
  static bool _tracking = false;

  /// A tap older than this is not the one that opened the page.
  static const _maxAge = Duration(milliseconds: 500);

  /// An element bigger than this share of the screen is not an origin (a
  /// whole screen passed as context).
  static const _maxAreaShare = 0.5;

  /// Side of the square around the last tap when no element is known.
  static const double _tapSide = AvoSizes.hitTarget;

  /// Starts remembering where the last tap ended (`app.dart` calls it at
  /// start). Safe to call again.
  static void ensureTracking() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static Offset? _down;

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _down = event.position;
    if (event is PointerUpEvent) {
      final down = _down;
      // A swipe or scroll is no tap: it opens nothing from its end point.
      final tap = down != null && (event.position - down).distance < kTouchSlop;
      _lastTap = tap ? event.position : null;
      _lastTapAt = tap ? DateTime.now() : null;
    }
  }

  /// Remembers the element of [context] as the origin of the next zoom page.
  /// Without a usable element the spot of the last tap is used.
  static void capture(BuildContext context) {
    final rect = rectOf(context);
    _pending = rect ?? _tapRect();
    _pendingAt = DateTime.now();
  }

  /// The global rectangle of [context]'s element, or null when it has no
  /// size yet or covers most of the screen.
  static Rect? rectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final screen = MediaQuery.maybeSizeOf(context);
    if (screen == null || screen.isEmpty) return null;
    final size = box.size;
    if (size.isEmpty) return null;
    if (size.width * size.height >
        screen.width * screen.height * _maxAreaShare) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & size;
  }

  static Rect? _tapRect() {
    final at = _lastTapAt;
    final tap = _lastTap;
    if (at == null || tap == null) return null;
    if (DateTime.now().difference(at) > _maxAge) return null;
    return Rect.fromCenter(center: tap, width: _tapSide, height: _tapSide);
  }

  /// The origin for the page being built now; consumed once. Without a
  /// [capture] it is the spot of a tap that just ended (a plain
  /// `context.push` from a row), and null when there was none (deep link).
  static Rect? take() {
    final rect = _pending;
    final at = _pendingAt;
    _pending = null;
    _pendingAt = null;
    if (rect != null &&
        at != null &&
        DateTime.now().difference(at) <= _maxAge) {
      return rect;
    }
    final tap = _tapRect();
    _lastTap = null;
    _lastTapAt = null;
    return tap;
  }

  /// Forgets everything (tests).
  @visibleForTesting
  static void debugReset() {
    _pending = null;
    _pendingAt = null;
    _lastTap = null;
    _lastTapAt = null;
  }
}

/// A full-screen page that grows out of [origin] and shrinks back into it
/// (iOS zoom navigation, Konzept 18 §8.2). No sheet, nothing slides up.
///
/// - Without [origin] it grows from the middle, 0.96 → 1 with opacity.
/// - Swiping from the left edge follows the finger 1:1 and shrinks the
///   page towards its origin; releasing past 30 % or with a flick closes.
/// - Reduce Motion: a short cross-fade.
class ZoomPage<T> extends Page<T> {
  /// Creates the page.
  const ZoomPage({
    required this.child,
    this.origin,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The screen.
  final Widget child;

  /// Global rectangle the page grows from; null is the middle.
  final Rect? origin;

  @override
  Route<T> createRoute(BuildContext context) =>
      ZoomPageRoute<T>(page: this, origin: origin);
}

/// The route of [ZoomPage].
class ZoomPageRoute<T> extends PageRoute<T> {
  /// Creates the route.
  ZoomPageRoute({required ZoomPage<T> page, this.origin})
    : super(settings: page);

  /// Where the page grows from (fixed at the push).
  final Rect? origin;

  /// Seconds the spring needs to settle (`AvoMotion.morph`, 0.40 s, no
  /// overshoot: below 0.2 % of the way after this).
  static const _settle = Duration(milliseconds: 560);

  /// Share of the width past which a released swipe closes the page.
  static const double _closeShare = 0.3;

  /// Edge width that starts the back swipe.
  static const double _edge = 20; // D2

  /// Flick speed (points per second) that closes regardless of distance.
  static const double _flick = 500;

  ZoomPage<T> get _page => settings as ZoomPage<T>;

  bool _gesture = false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => _settle;

  @override
  Duration get reverseTransitionDuration => _settle;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = AvoMotion.reduced(context);
    if (reduced) {
      final width = MediaQuery.sizeOf(context).width;
      return Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(opacity: animation, child: child),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: _edge,
            child: _EdgeSwipe(
              width: width,
              onStart: _dragStart,
              onUpdate: _dragUpdate,
              onEnd: _dragEnd,
            ),
          ),
        ],
      );
    }
    return _ZoomTransition(
      animation: animation,
      curve: _gesture ? null : const _SpringCurve(),
      origin: origin,
      onDragStart: _dragStart,
      onDragUpdate: _dragUpdate,
      onDragEnd: _dragEnd,
      child: child,
    );
  }

  // ------------------------------------------------------------ back swipe

  void _dragStart() {
    // Only on a settled page: a drag during the push or pop would jump.
    if (!isCurrent || navigator == null || !controller!.isCompleted) return;
    _gesture = true;
    navigator!.didStartUserGesture();
    changedInternalState();
  }

  void _dragUpdate(double dx, double width) {
    if (!_gesture || width <= 0) return;
    if (!isCurrent) {
      // Popped by something else (purchase, redirect) under the finger.
      _finishGesture(navigator!);
      return;
    }
    controller!.value = (controller!.value - dx / width).clamp(0.0, 1.0);
  }

  void _dragEnd(double velocity) {
    if (!_gesture) return;
    if (!isCurrent) {
      _finishGesture(navigator!);
      return;
    }
    final c = controller!;
    final close =
        velocity > _flick || (velocity > -_flick && c.value < 1 - _closeShare);
    final nav = navigator!;
    if (close) {
      nav.pop();
      // The pop reverses from where the finger left the page.
    } else {
      final spring = SpringSimulation(AvoMotion.morph, c.value, 1, 0);
      c.animateWith(spring);
    }
    void done(AnimationStatus status) {
      if (status.isAnimating) return;
      c.removeStatusListener(done);
      _finishGesture(nav);
    }

    if (c.isAnimating) {
      c.addStatusListener(done);
    } else {
      _finishGesture(nav);
    }
  }

  void _finishGesture(NavigatorState nav) {
    if (!_gesture) return;
    _gesture = false;
    nav.didStopUserGesture();
    if (isActive) changedInternalState();
  }

  @override
  void dispose() {
    if (_gesture) navigator?.didStopUserGesture();
    super.dispose();
  }
}

/// A critically damped spring (`AvoMotion.morph`) as a curve over the
/// route's duration, so push and pop look like the springs elsewhere.
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    final seconds =
        ZoomPageRoute._settle.inMicroseconds / Duration.microsecondsPerSecond;
    final x = SpringSimulation(AvoMotion.morph, 0, 1, 0).x(t * seconds);
    return x.clamp(0.0, 1.0);
  }
}

class _ZoomTransition extends StatefulWidget {
  const _ZoomTransition({
    required this.animation,
    required this.curve,
    required this.origin,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  final Animation<double> animation;

  /// Null while the finger drives the page (1:1, no easing).
  final Curve? curve;
  final Rect? origin;
  final VoidCallback onDragStart;
  final void Function(double dx, double width) onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final Widget child;

  @override
  State<_ZoomTransition> createState() => _ZoomTransitionState();
}

class _ZoomTransitionState extends State<_ZoomTransition> {
  /// Corner radius of the page while it is small (a card in D2).
  static const double _smallRadius = AvoRadii.card;

  /// The running close started from the settled page (not from a push that
  /// was interrupted half-way).
  bool _closeFromFull = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_ZoomTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      old.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _closeFromFull = widget.animation.value >= 1;
    }
  }

  double _value(Animation<double> a) {
    final curve = widget.curve;
    if (curve == null) return a.value;
    // Opening runs the spring forwards, closing from the settled page runs
    // it backwards from 1, so both start fast and settle softly. A push
    // interrupted by a close keeps the forward curve, so nothing jumps.
    return a.status == AnimationStatus.reverse && _closeFromFull
        ? curve.flipped.transform(a.value)
        : curve.transform(a.value);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final t = _value(widget.animation);
        final Widget page;
        if (t >= 1) {
          page = child!;
        } else {
          page = _frame(t, size, child!);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            page,
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: ZoomPageRoute._edge,
              child: _EdgeSwipe(
                width: size.width,
                onStart: widget.onDragStart,
                onUpdate: widget.onDragUpdate,
                onEnd: widget.onDragEnd,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _frame(double t, Size size, Widget child) {
    final full = Offset.zero & size;
    final origin = widget.origin;
    // Content appears in the first half; the frame keeps growing after.
    final opacity = (t / 0.5).clamp(0.0, 1.0);
    if (origin == null) {
      final scale = 0.96 + 0.04 * t;
      return Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      );
    }
    final rect = Rect.lerp(origin, full, t)!;
    final scale = math.max(rect.width / size.width, 0.01);
    final radius = _smallRadius * (1 - t);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: Opacity(opacity: opacity, child: child),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The strip at the left edge that starts the back swipe.
class _EdgeSwipe extends StatelessWidget {
  const _EdgeSwipe({
    required this.width,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final double width;
  final VoidCallback onStart;
  final void Function(double dx, double width) onUpdate;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    double sign(double v) => rtl ? -v : v;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => onStart(),
      onHorizontalDragUpdate: (d) => onUpdate(sign(d.delta.dx), width),
      onHorizontalDragEnd: (d) => onEnd(sign(d.velocity.pixelsPerSecond.dx)),
      onHorizontalDragCancel: () => onEnd(0),
    );
  }
}
