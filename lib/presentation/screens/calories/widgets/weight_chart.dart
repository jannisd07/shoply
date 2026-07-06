import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/weight_log_entry.dart';

/// A small hand-rolled line chart for weight-over-time — no chart package
/// is available in this project (see CalorieRing for the same rationale).
class WeightChart extends StatelessWidget {
  final List<WeightLogEntry> entries;
  final double? targetWeightKg;
  final double height;

  const WeightChart({super.key, required this.entries, this.targetWeightKg, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            entries.isEmpty ? '—' : '${entries.first.weightKg.toStringAsFixed(1)} kg',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WeightChartPainter(
          entries: entries,
          targetWeightKg: targetWeightKg,
          lineColor: AppColors.accentColor(context),
          targetColor: AppColors.textTertiary(context),
          labelColor: AppColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightLogEntry> entries;
  final double? targetWeightKg;
  final Color lineColor;
  final Color targetColor;
  final Color labelColor;

  _WeightChartPainter({
    required this.entries,
    required this.targetWeightKg,
    required this.lineColor,
    required this.targetColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final weights = entries.map((e) => e.weightKg).toList();
    var minW = weights.reduce((a, b) => a < b ? a : b);
    var maxW = weights.reduce((a, b) => a > b ? a : b);
    if (targetWeightKg != null) {
      minW = minW < targetWeightKg! ? minW : targetWeightKg!;
      maxW = maxW > targetWeightKg! ? maxW : targetWeightKg!;
    }
    final range = (maxW - minW).abs() < 0.5 ? 1.0 : (maxW - minW);
    final padTop = 12.0, padBottom = 20.0;
    final chartHeight = size.height - padTop - padBottom;

    double yFor(double weight) => padTop + chartHeight - ((weight - minW) / range) * chartHeight;
    double xFor(int index) =>
        entries.length == 1 ? 0 : (index / (entries.length - 1)) * size.width;

    if (targetWeightKg != null) {
      final ty = yFor(targetWeightKg!);
      final dashPaint = Paint()
        ..color = targetColor
        ..strokeWidth = 1;
      const dashWidth = 4.0, dashGap = 4.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, ty), Offset(x + dashWidth, ty), dashPaint);
        x += dashWidth + dashGap;
      }
    }

    final path = Path();
    for (var i = 0; i < entries.length; i++) {
      final point = Offset(xFor(i), yFor(entries[i].weightKg));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < entries.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(entries[i].weightKg)), i == entries.length - 1 ? 4 : 2.5, dotPaint);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${entries.last.weightKg.toStringAsFixed(1)} kg',
        style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lastPoint = Offset(xFor(entries.length - 1), yFor(entries.last.weightKg));
    final labelX = (lastPoint.dx - textPainter.width).clamp(0.0, size.width - textPainter.width);
    textPainter.paint(canvas, Offset(labelX, (lastPoint.dy - textPainter.height - 6).clamp(0.0, size.height)));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => oldDelegate.entries != entries;
}
