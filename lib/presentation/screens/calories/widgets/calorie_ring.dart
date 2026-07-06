import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// A simple ring showing calories consumed vs. target, with the remaining
/// (or over-budget) amount as the headline number. No chart package is
/// available in this project, so this is a small hand-rolled CustomPainter
/// rather than pulling in a new dependency for one widget.
class CalorieRing extends StatelessWidget {
  final int consumed;
  final int target;
  final double size;
  final String leftLabel;
  final String overLabel;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    required this.leftLabel,
    required this.overLabel,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final isOver = remaining < 0;
    final accent = AppColors.accentColor(context);
    final trackColor = AppColors.border(context);
    final ringColor = isOver ? const Color(0xFFE0764A) : accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress: progress, trackColor: trackColor, ringColor: ringColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${remaining.abs()}',
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Text(
                isOver ? overLabel : leftLabel,
                style: TextStyle(
                  fontSize: size * 0.075,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color ringColor;

  _RingPainter({required this.progress, required this.trackColor, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
}
