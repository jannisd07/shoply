import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';

/// How long the moment stays before it fades (Konzept 00 §12.35).
const Duration _kVisible = Duration(milliseconds: 1500);

/// Start scale of the pop-in (Konzept 00 §12.35: from 0.9).
const double _kStartScale = 0.9;

/// Figure size; smaller from AX1 on so the text keeps its room.
const double _kFigureSize = 120;
const double _kFigureSizeAccessibility = 72;

/// Widest card, so the moment stays a compact centre piece on large phones.
const double _kMaxCardWidth = 320;

/// Card shadow (D2 cards: 0 0 0 .5px rgba(0,0,0,.07), 0 6px 18px
/// rgba(0,0,0,.07)).
const double _kRingAlpha = 0.07; // D2
const double _kShadowAlpha = 0.07; // D2
const double _kShadowBlur = 18; // D2
const Offset _kShadowOffset = Offset(0, 6); // D2

/// Shows the success moment centred above everything (Konzept 00 §12.35):
/// the celebrating figure, [title] and an optional [subtitle] pop in from
/// 0.9 on the celebrate spring together with the success haptic, stay for
/// 1.5 s and fade; a tap anywhere closes it earlier. With Reduce Motion it
/// only fades in. VoiceOver announces the title (and subtitle).
///
/// Show it only after the screen that finished the task has closed ("Einkauf
/// gespeichert.", "{pro} ist aktiv."). The future completes when the moment
/// is gone. Needs an [Overlay] above [context] (every app route has one).
Future<void> showSuccessMoment(
  BuildContext context, {
  required String title,
  String? subtitle,
  AvoPose pose = AvoPose.celebrating,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SuccessMoment(
      title: title,
      subtitle: subtitle,
      pose: pose,
      onClosed: () {
        if (entry.mounted) {
          entry
            ..remove()
            ..dispose();
        }
        if (!done.isCompleted) done.complete();
      },
      onDisposed: () {
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _SuccessMoment extends StatefulWidget {
  const _SuccessMoment({
    required this.title,
    required this.subtitle,
    required this.pose,
    required this.onClosed,
    required this.onDisposed,
  });

  final String title;
  final String? subtitle;
  final AvoPose pose;
  final VoidCallback onClosed;
  final VoidCallback onDisposed;

  @override
  State<_SuccessMoment> createState() => _SuccessMomentState();
}

class _SuccessMomentState extends State<_SuccessMoment>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _opacity;
  Timer? _timer;
  bool _started = false;

  /// Read with the dependencies, so the timer never needs the context.
  bool _reduceMotion = false;
  bool _closing = false;

  String get _spoken {
    final sub = widget.subtitle;
    return sub == null ? widget.title : '${widget.title}, $sub';
  }

  @override
  void initState() {
    super.initState();
    _scale = AnimationController.unbounded(vsync: this, value: _kStartScale);
    _opacity = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    if (_started) return;
    _started = true;
    // Visual, haptic and announcement start in the same frame.
    if (_reduceMotion) {
      _scale.value = 1;
      _opacity.animateTo(
        1,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    } else {
      _scale.animateWith(
        SpringSimulation(AvoMotion.celebrate, _kStartScale, 1, 0),
      );
      _opacity.animateWith(SpringSimulation(AvoMotion.quick, 0, 1, 0));
    }
    unawaited(AvoHaptics.success());
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(
        view,
        _spoken,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
    _timer = Timer(_kVisible, _close);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    final TickerFuture fade;
    if (_reduceMotion) {
      fade = _opacity.animateTo(
        0,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    } else {
      fade = _opacity.animateWith(
        SpringSimulation(AvoMotion.quick, _opacity.value, 0, _opacity.velocity),
      );
    }
    fade.whenCompleteOrCancel(() {
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scale.dispose();
    _opacity.dispose();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final sub = widget.subtitle;
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxCardWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AvoRadii.group),
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
        child: Padding(
          padding: const EdgeInsets.all(AvoSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvoFigure(
                pose: widget.pose,
                size: ax ? _kFigureSizeAccessibility : _kFigureSize,
              ),
              const SizedBox(height: AvoSpacing.m),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: context.text(AvoTextStyle.title3),
              ),
              if (sub != null) ...[
                const SizedBox(height: AvoSpacing.xs),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: _spoken,
      onTap: _close,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _close,
          child: FadeTransition(
            opacity: _opacity,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AvoSpacing.xxxl),
                  child: ScaleTransition(scale: _scale, child: card),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
