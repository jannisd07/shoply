import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Intl, NumberFormat;
import 'package:shoply/core/design/design.dart';

// D2 progress line (D2-Komponenten, Listenkarte): 4 high, radius 2, track
// separator, value tint.
const double _lineHeight = 4; // D2
const double _lineRadius = 2; // D2

// Ring stroke when none is given: about a tenth of the diameter, so the
// Konzept sizes 24 / 44 / 120 / 160 get 3 / 4 / 11 / 12 pt.
const double _ringStrokeFactor = 0.09;
const double _ringStrokeMin = 3;
const double _ringStrokeMax = 12;

/// Spring-driven value shared by [ProgressLine] and [ProgressRing]: starts
/// at the first value, then follows changes on [AvoMotion.digits] from the
/// current position and speed; jumps under Reduce Motion.
mixin _SpringValue<W extends StatefulWidget>
    on State<W>, SingleTickerProviderStateMixin<W> {
  late final AnimationController progress;

  double get targetValue;

  @override
  void initState() {
    super.initState();
    progress = AnimationController.unbounded(vsync: this, value: targetValue);
  }

  void follow() {
    final target = targetValue;
    if (progress.value == target && !progress.isAnimating) return;
    if (context.reduceMotion) {
      progress.value = target;
      return;
    }
    progress.animateWith(
      SpringSimulation(
        AvoMotion.digits,
        progress.value,
        target,
        progress.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }
}

/// "67 %" in the app locale, for VoiceOver.
String _percent(BuildContext context, double value) {
  final tag = Localizations.maybeLocaleOf(context)?.toString() ?? 'en';
  final locale = Intl.verifiedLocale(
    tag,
    NumberFormat.localeExists,
    onFailure: (_) => 'en',
  );
  return NumberFormat.percentPattern(locale).format(value);
}

/// A thin D2 progress bar (list cards, list header, shopping mode).
///
/// Fills the available width; value changes follow the digits spring.
/// VoiceOver reads [semanticLabel] and [semanticValue] (default: the
/// percentage) like a progress indicator.
class ProgressLine extends StatefulWidget {
  /// Creates a progress line.
  const ProgressLine({
    super.key,
    required this.value,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress from 0 to 1; values outside are clamped.
  final double value;

  /// What progresses ("Fortschritt").
  final String? semanticLabel;

  /// Spoken value, for example "8 von 12"; defaults to the percentage.
  final String? semanticValue;

  @override
  State<ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<ProgressLine>
    with SingleTickerProviderStateMixin, _SpringValue<ProgressLine> {
  @override
  double get targetValue => widget.value.clamp(0.0, 1.0);

  @override
  void didUpdateWidget(ProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) follow();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.semanticValue ?? _percent(context, targetValue),
      child: SizedBox(
        height: _lineHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            progress: progress,
            track: colors.separator,
            fill: colors.tint,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.progress,
    required this.track,
    required this.fill,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(_lineRadius);
    final bounds = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(bounds, Paint()..color = track);
    final v = progress.value.clamp(0.0, 1.0);
    if (v <= 0) return;
    canvas
      ..save()
      ..clipRRect(bounds)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * v, size.height),
          radius,
        ),
        Paint()..color = fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// A circular progress ring (calories, goals; Konzept 00 §12.14, sizes
/// 24 / 44 / 120 / 160).
///
/// The arc starts at the top and runs clockwise in the accent colour, or in
/// the warning red when [over] is set (more than 100 %). Value changes
/// follow the digits spring. [center] sits inside the ring and is scaled
/// down rather than clipped when large text does not fit; choose a larger
/// [size] for big numbers.
class ProgressRing extends StatefulWidget {
  /// Creates a progress ring.
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.strokeWidth,
    this.center,
    this.over = false,
    this.semanticLabel,
    this.semanticValue,
  });

  /// Progress from 0 to 1; the arc is full from 1 on.
  final double value;

  /// Outer diameter in points.
  final double size;

  /// Ring thickness; defaults to about a tenth of [size] (3–12 pt).
  final double? strokeWidth;

  /// Content in the middle, for example the remaining kcal.
  final Widget? center;

  /// The goal is exceeded: the arc turns red. Pair it with a text such as
  /// "120 kcal drüber" so colour is not the only signal.
  final bool over;

  /// What progresses, for VoiceOver.
  final String? semanticLabel;

  /// Spoken value; defaults to the percentage (may exceed 100 %).
  final String? semanticValue;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin, _SpringValue<ProgressRing> {
  @override
  double get targetValue => math.max(0.0, widget.value);

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) follow();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stroke =
        widget.strokeWidth ??
        (widget.size * _ringStrokeFactor).clamp(_ringStrokeMin, _ringStrokeMax);
    final center = widget.center;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.semanticValue ?? _percent(context, targetValue),
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _RingPainter(
                progress: progress,
                stroke: stroke,
                track: colors.separator,
                fill: widget.over ? colors.red : colors.tint,
              ),
            ),
            if (center != null)
              Padding(
                padding: EdgeInsets.all(stroke + AvoSpacing.xs),
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: center),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.fill,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double stroke;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, paint);
    final v = progress.value.clamp(0.0, 1.0);
    if (v <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      paint
        ..color = fill
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.track != track ||
      old.fill != fill;
}
