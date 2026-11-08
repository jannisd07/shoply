import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// A thin progress bar in a calorie colour on the neutral track (water: 4 pt
/// with radius 2, D2). Fills the width it gets; follows value changes on
/// the digits spring from where it is (Reduce Motion: jumps). Decorative for
/// VoiceOver: the text next to it carries the number.
class CalorieBar extends StatefulWidget {
  const CalorieBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 4, // D2 water bar
  });

  /// Filled share, 0…1 (clamped).
  final double fraction;
  final Color color;
  final double height;

  @override
  State<CalorieBar> createState() => _CalorieBarState();
}

class _CalorieBarState extends State<CalorieBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _value = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );

  double get _target => widget.fraction.clamp(0.0, 1.0);

  @override
  void didUpdateWidget(CalorieBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction == widget.fraction) return;
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
    final radius = Radius.circular(widget.height / 2);
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(
            value: _value,
            track: context.colors.fill,
            fill: widget.color,
            radius: radius,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.value,
    required this.track,
    required this.fill,
    required this.radius,
  }) : super(repaint: value);

  final Animation<double> value;
  final Color track;
  final Color fill;
  final Radius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(bounds, Paint()..color = track);
    final v = value.value.clamp(0.0, 1.0);
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
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.track != track ||
      old.fill != fill ||
      old.radius != radius;
}
