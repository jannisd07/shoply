import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// How long a toast stays (Konzept 00 §12.28).
const Duration _kVisible = Duration(seconds: 4);

/// How long it stays while VoiceOver is on (Konzept 00 §12.28, §14.11).
const Duration _kVisibleVoiceOver = Duration(seconds: 10);

/// Inner padding of the capsule at the start (D2 glass buttons: 14–18).
const double _kStartPadding = AvoSpacing.l;

/// Pressed opacity next to [AvoMotion.pressedScale] (Konzept 00 §12.20).
const double _kPressedOpacity = 0.9;

/// Glass shadow (D2 `.glass`: 0 0 0 .5px rgba(0,0,0,.05), 0 6px 20px
/// rgba(0,0,0,.10)).
const double _kRingAlpha = 0.05; // D2
const double _kShadowAlpha = 0.10; // D2
const double _kShadowBlur = 20; // D2
const Offset _kShadowOffset = Offset(0, 6); // D2

/// A pull further down than this (after momentum projection) dismisses.
const double _kDismissDistance = AvoSizes.hitTarget;

/// How far the toast rises while it appears: one tab bar height, so it reads
/// as coming out of the bottom layer.
const double _kEnterDistance = AvoSizes.tabBarHeight;

/// The undo toast (Konzept 00 §12.28): a glass capsule above the tab bar with
/// a sentence and an optional action ("Milch gelöscht · Widerrufen").
///
/// Shown for 4 s (10 s while VoiceOver is on, plus an announcement); a new
/// toast replaces the current one; a swipe down dismisses it; appearing and
/// leaving use springs (Reduce Motion: cross-fade). Use it with an action
/// for undo, and as a plain status only when the result is otherwise
/// invisible ("Liste geteilt"). No haptics.
///
/// With a target ([show]'s `targetLabel` and `onTarget`) a tap on the text
/// opens the result ("Auf Liste Wochenende" opens the list) while the action
/// stays "Widerrufen". While VoiceOver focus rests on the toast its timer is
/// paused (Konzept 13 E-16). `onDismissed` reports once when it is gone.
abstract final class AvoToast {
  /// Shows [message] in the nearest [AvoToastHost]. Without a host (tests,
  /// isolated screens) it falls back to the root [Overlay].
  ///
  /// [actionLabel] and [onAction] add the tinted action; tapping it runs
  /// [onAction] and hides the toast. [duration] overrides the 4 s / 10 s.
  ///
  /// [targetLabel] and [onTarget] make the text itself tappable: it runs
  /// [onTarget] and hides the toast. [targetLabel] ("Liste öffnen") is the
  /// VoiceOver action and hint of the text; both must be given.
  ///
  /// [onDismissed] runs exactly once when this toast is gone: its time ran
  /// out (also after a VoiceOver pause), it was swiped away, its action or
  /// target was used, a newer toast replaced it, or its host left the tree.
  /// It runs after [onAction] / [onTarget]. Use it to commit what the toast
  /// could still undo; when the host is disposed it runs during that
  /// teardown, so do not call `setState` on a widget that may be gone.
  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    String? targetLabel,
    VoidCallback? onTarget,
    VoidCallback? onDismissed,
  }) {
    final request = _ToastRequest(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      targetLabel: targetLabel,
      onTarget: onTarget,
      onDismissed: onDismissed,
    );
    final scope = context.getInheritedWidgetOfExactType<_AvoToastScope>();
    final layer = scope?.layerKey.currentState;
    if (layer != null) {
      layer.show(request);
      return;
    }
    _OverlayFallback.show(context, request);
  }
}

/// The global toast layer. Put it once in the app `builder`, around the
/// navigator, so toasts survive navigation and sit above every screen:
///
/// ```dart
/// builder: (context, child) => AvoToastHost(child: child!),
/// ```
///
/// The toast rests [ShellInsets.aboveTabBar] above the bottom edge, or above
/// the keyboard while it is open. Areas outside the toast stay touchable.
class AvoToastHost extends StatefulWidget {
  /// Creates the host around [child].
  const AvoToastHost({super.key, required this.child});

  /// The app (usually the navigator).
  final Widget child;

  @override
  State<AvoToastHost> createState() => _AvoToastHostState();
}

class _AvoToastHostState extends State<AvoToastHost> {
  final GlobalKey<_ToastLayerState> _layerKey = GlobalKey<_ToastLayerState>();

  @override
  Widget build(BuildContext context) {
    return _AvoToastScope(
      layerKey: _layerKey,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(child: _ToastLayer(key: _layerKey)),
        ],
      ),
    );
  }
}

class _AvoToastScope extends InheritedWidget {
  const _AvoToastScope({required this.layerKey, required super.child});

  final GlobalKey<_ToastLayerState> layerKey;

  @override
  bool updateShouldNotify(_AvoToastScope old) => old.layerKey != layerKey;
}

class _ToastRequest {
  _ToastRequest({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.duration,
    this.targetLabel,
    this.onTarget,
    this.onDismissed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? duration;
  final String? targetLabel;
  final VoidCallback? onTarget;
  final VoidCallback? onDismissed;

  bool _dismissed = false;

  /// Runs [onDismissed] the first time only.
  void notifyDismissed() {
    if (_dismissed) return;
    _dismissed = true;
    onDismissed?.call();
  }

  bool get hasAction => actionLabel != null && onAction != null;
  bool get hasTarget => targetLabel != null && onTarget != null;
}

/// Without an [AvoToastHost]: one overlay entry at a time in the root
/// overlay, removed again once its toast is gone.
abstract final class _OverlayFallback {
  static OverlayEntry? _entry;
  static GlobalKey<_ToastLayerState>? _key;

  static void show(BuildContext context, _ToastRequest request) {
    final entry = _entry;
    final layer = _key?.currentState;
    if (entry != null && entry.mounted && layer != null && layer.mounted) {
      layer.show(request);
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      debugPrint('⚠️ [AvoToast] no AvoToastHost and no Overlay: not shown');
      request.notifyDismissed();
      return;
    }
    final key = GlobalKey<_ToastLayerState>();
    late final OverlayEntry created;
    created = OverlayEntry(
      builder: (_) => _ToastLayer(
        key: key,
        initial: request,
        onEmpty: () {
          if (created.mounted) {
            created
              ..remove()
              ..dispose();
          }
          if (identical(_entry, created)) {
            _entry = null;
            _key = null;
          }
        },
      ),
    );
    _entry = created;
    _key = key;
    overlay.insert(created);
  }
}

/// Holds the current toast, its timer and its motion.
class _ToastLayer extends StatefulWidget {
  const _ToastLayer({super.key, this.initial, this.onEmpty});

  /// Shown right after the first frame (overlay fallback).
  final _ToastRequest? initial;

  /// Called when the last toast has left (overlay fallback).
  final VoidCallback? onEmpty;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with TickerProviderStateMixin {
  /// 0 = gone, 1 = resting in place.
  late final AnimationController _shown;

  /// Downward offset in points while (and after) the toast is dragged.
  late final AnimationController _drag;

  _ToastRequest? _current;
  int _serial = 0;

  /// Read in build, so timers and gestures never need the context.
  bool _reduceMotion = false;

  Timer? _timer;
  bool _hiding = false;
  double _rawDrag = 0;

  /// How many parts of the toast hold VoiceOver focus right now; the timer
  /// runs only at zero.
  int _focusHolders = 0;

  @override
  void initState() {
    super.initState();
    // Created eagerly: dispose must never be the first access.
    _shown = AnimationController.unbounded(vsync: this);
    _drag = AnimationController.unbounded(vsync: this);
    final initial = widget.initial;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) show(initial);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shown.dispose();
    _drag.dispose();
    final current = _current;
    _current = null;
    current?.notifyDismissed();
    super.dispose();
  }

  bool get _voiceOver =>
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

  /// Shows [request], replacing whatever is visible.
  void show(_ToastRequest request) {
    _reduceMotion = context.reduceMotion;
    _timer?.cancel();
    final replaced = _current;
    _hiding = false;
    _focusHolders = 0;
    setState(() {
      _current = request;
      _serial++;
    });
    _rawDrag = 0;
    _drag
      ..stop()
      ..value = 0;
    _animate(_shown, 1, AvoMotion.standard);
    _startTimer();
    if (replaced != null && !identical(replaced, request)) {
      replaced.notifyDismissed();
    }
    if (_voiceOver) {
      final view = View.maybeOf(context);
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          request.hasAction
              ? '${request.message}, ${request.actionLabel}'
              : request.message,
          Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final current = _current;
    if (current == null || _focusHolders > 0) return;
    final duration =
        current.duration ?? (_voiceOver ? _kVisibleVoiceOver : _kVisible);
    _timer = Timer(duration, _hide);
  }

  void _hide() {
    if (_current == null || _hiding) return;
    _timer?.cancel();
    _hiding = true;
    final leaving = _current;
    _animate(_shown, 0, AvoMotion.standard).whenCompleteOrCancel(() {
      if (!mounted || !_hiding || !identical(_current, leaving)) return;
      setState(() {
        _current = null;
        _hiding = false;
      });
      _rawDrag = 0;
      _drag.value = 0;
      leaving?.notifyDismissed();
      widget.onEmpty?.call();
    });
  }

  /// Springs [controller] to [target] from its current value and velocity;
  /// with Reduce Motion a short cross-fade instead.
  TickerFuture _animate(
    AnimationController controller,
    double target,
    SpringDescription spring,
  ) {
    if (_reduceMotion) {
      return controller.animateTo(
        target,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    }
    return controller.animateWith(
      SpringSimulation(spring, controller.value, target, controller.velocity),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (_hiding) return;
    _timer?.cancel();
    _drag.stop();
    _rawDrag = _drag.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_hiding) return;
    _rawDrag += details.delta.dy;
    // Down follows the finger 1:1; up resists like a rubber band.
    _drag.value = _rawDrag >= 0
        ? _rawDrag
        : -AvoMotion.rubberBand(-_rawDrag, _kEnterDistance);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_hiding) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final projected = _drag.value + AvoMotion.project(velocity);
    if (projected > _kDismissDistance) {
      if (!_reduceMotion) {
        final away = ShellInsets.aboveTabBar(context) + _kEnterDistance * 2;
        _drag.animateWith(
          SpringSimulation(
            AvoMotion.standard,
            _drag.value,
            math.max(away, _drag.value),
            velocity,
          ),
        );
      }
      _hide();
    } else {
      _rawDrag = 0;
      _drag.animateWith(
        SpringSimulation(AvoMotion.fling, _drag.value, 0, velocity),
      );
      _startTimer();
    }
  }

  void _onAction() {
    _current?.onAction?.call();
    _hide();
  }

  void _onTarget() {
    _current?.onTarget?.call();
    _hide();
  }

  /// VoiceOver focus reached a part of the toast: the time stops (E-16).
  void _onFocusGained() {
    _focusHolders++;
    _timer?.cancel();
  }

  /// VoiceOver focus left a part of the toast: the time runs again.
  void _onFocusLost() {
    if (_focusHolders > 0) _focusHolders--;
    if (_focusHolders == 0 && !_hiding) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = math.max(
      ShellInsets.aboveTabBar(context),
      keyboard + AvoSpacing.m,
    );
    final reduce = _reduceMotion = context.reduceMotion;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        0,
        AvoSpacing.screen,
        bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shown, _drag]),
          builder: (context, child) {
            final shown = _shown.value;
            final rise = reduce ? 0.0 : (1 - shown) * _kEnterDistance;
            return Opacity(
              opacity: shown.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, rise + _drag.value),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: _ToastCapsule(
              key: ValueKey<int>(_serial),
              request: current,
              onAction: _onAction,
              onTarget: _onTarget,
              onDismiss: _hide,
              onFocusGained: _onFocusGained,
              onFocusLost: _onFocusLost,
            ),
          ),
        ),
      ),
    );
  }
}

/// The visible capsule: opaque glass fallback (the content layer may not use
/// a backdrop blur), hairline edge and the D2 glass shadow.
class _ToastCapsule extends StatelessWidget {
  const _ToastCapsule({
    super.key,
    required this.request,
    required this.onAction,
    required this.onTarget,
    required this.onDismiss,
    required this.onFocusGained,
    required this.onFocusLost,
  });

  final _ToastRequest request;
  final VoidCallback onAction;
  final VoidCallback onTarget;
  final VoidCallback onDismiss;
  final VoidCallback onFocusGained;
  final VoidCallback onFocusLost;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final targetLabel = request.targetLabel;
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m),
      child: Text(
        request.message,
        style: context.text(AvoTextStyle.subhead, weight: FontWeight.w600),
      ),
    );
    final Widget message = request.hasTarget && targetLabel != null
        ? _ToastTarget(
            message: request.message,
            targetLabel: targetLabel,
            onTap: onTarget,
            onFocusGained: onFocusGained,
            onFocusLost: onFocusLost,
            child: text,
          )
        : Semantics(
            container: true,
            onDidGainAccessibilityFocus: onFocusGained,
            onDidLoseAccessibilityFocus: onFocusLost,
            child: text,
          );
    final label = request.actionLabel;
    final action = request.hasAction && label != null
        ? _ToastAction(
            label: label,
            onTap: onAction,
            onFocusGained: onFocusGained,
            onFocusLost: onFocusLost,
          )
        : null;

    final Widget content;
    if (action == null) {
      content = message;
    } else if (ax) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [message, action],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: message),
          const SizedBox(width: AvoSpacing.xs),
          action,
        ],
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      onDismiss: onDismiss,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.glassFallback,
          borderRadius: BorderRadius.circular(AvoRadii.group),
          border: Border.all(
            color: colors.glassBorder,
            width: AvoSizes.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: _kRingAlpha),
              spreadRadius: AvoSizes.hairline,
            ),
            BoxShadow(
              color: colors.shadow.withValues(alpha: _kShadowAlpha),
              offset: _kShadowOffset,
              blurRadius: _kShadowBlur,
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: _kStartPadding,
              end: action == null ? _kStartPadding : AvoSpacing.xs,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The text of a toast with a target: tapping it opens the result. Dims a
/// little while touched; VoiceOver gets a button with the target's label as
/// its custom action.
class _ToastTarget extends StatefulWidget {
  const _ToastTarget({
    required this.message,
    required this.targetLabel,
    required this.onTap,
    required this.onFocusGained,
    required this.onFocusLost,
    required this.child,
  });

  final String message;
  final String targetLabel;
  final VoidCallback onTap;
  final VoidCallback onFocusGained;
  final VoidCallback onFocusLost;
  final Widget child;

  @override
  State<_ToastTarget> createState() => _ToastTargetState();
}

class _ToastTargetState extends State<_ToastTarget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: widget.message,
      hint: widget.targetLabel,
      onTap: widget.onTap,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.targetLabel): widget.onTap,
      },
      onDidGainAccessibilityFocus: widget.onFocusGained,
      onDidLoseAccessibilityFocus: widget.onFocusLost,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: Opacity(
          opacity: _pressed ? _kPressedOpacity : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tinted text action with a 44 pt target that dims and shrinks on touch.
class _ToastAction extends StatefulWidget {
  const _ToastAction({
    required this.label,
    required this.onTap,
    required this.onFocusGained,
    required this.onFocusLost,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onFocusGained;
  final VoidCallback onFocusLost;

  @override
  State<_ToastAction> createState() => _ToastActionState();
}

class _ToastActionState extends State<_ToastAction>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully pressed. Created eagerly: dispose must never be
  /// the first access (a lazy controller would look up TickerMode there).
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController.unbounded(vsync: this);
  }

  /// Read in build: [_to] also runs from onTapCancel while the tree is being
  /// torn down, when the context may no longer be used.
  bool _reduceMotion = false;

  void _to(double target) {
    if (!mounted) return;
    if (_reduceMotion) {
      _press
        ..stop()
        ..value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(AvoMotion.quick, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion = context.reduceMotion;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      onDidGainAccessibilityFocus: widget.onFocusGained,
      onDidLoseAccessibilityFocus: widget.onFocusLost,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => _to(1),
          onTapUp: (_) => _to(0),
          onTapCancel: () => _to(0),
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AvoSizes.hitTarget,
              minWidth: AvoSizes.hitTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.m),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) {
                    final t = _press.value.clamp(0.0, 1.0);
                    final scale = reduce
                        ? 1.0
                        : 1 - (1 - AvoMotion.pressedScale) * t;
                    return Opacity(
                      opacity: 1 - (1 - _kPressedOpacity) * t,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: Text(
                    widget.label,
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: context.colors.tint,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
