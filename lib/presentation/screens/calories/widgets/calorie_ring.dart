import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_colors.dart';

/// D2 ring sizes: 112 on the Home card, 120 in the diary; stroke 12.
const double kCalorieRingHome = 112; // D2
const double kCalorieRingDiary = 120; // D2
const double _stroke = 12; // D2

/// The calorie ring (D2 `D2-FuerDich` §6): eaten ÷ goal in the ring colour
/// on the neutral track, round cap, starting at the top. Full when over the
/// goal, never red (§3.3).
///
/// Value changes follow the digits spring from where the arc is, so quick
/// changes never jump; Reduce Motion sets the new value at once. Hidden from
/// VoiceOver: the text beside it says the same number (§3.10).
class CalorieRing extends StatefulWidget {
  const CalorieRing({
    super.key,
    required this.progress,
    this.size = kCalorieRingDiary,
    this.center,
  });

  /// Eaten ÷ goal, 0…1 (clamped).
  final double progress;

  /// Outer diameter.
  final double size;

  /// Optional content in the middle (Home card: "640" / "kcal übrig").
  final Widget? center;

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );

  double get _target => widget.progress.clamp(0.0, 1.0);

  @override
  void didUpdateWidget(CalorieRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress == widget.progress) return;
    if (context.reduceMotion) {
      _value
        ..stop()
        ..value = _target;
      return;
    }
    _value.animateWith(SpringSimulation(
      AvoMotion.digits,
      _value.value,
      _target,
      _value.velocity,
      snapToEnd: true,
    ));
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _value,
                  track: context.colors.fill,
                  fill: CalorieColors.of(context).ring,
                ),
              ),
            ),
            if (center != null)
              Padding(
                padding: const EdgeInsets.all(_stroke + AvoSpacing.xs),
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
    required this.track,
    required this.fill,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
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
      old.progress != progress || old.track != track || old.fill != fill;
}
