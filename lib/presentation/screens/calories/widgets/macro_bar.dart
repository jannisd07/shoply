import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// A labeled progress bar for one macro (protein/carbs/fat): "112 / 150 g".
class MacroBar extends StatelessWidget {
  final String label;
  final double valueG;
  final int? targetG;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.valueG,
    required this.targetG,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final target = targetG ?? 0;
    final progress = target <= 0 ? 0.0 : (valueG / target).clamp(0.0, 1.0);
    final textSecondary = AppColors.textSecondary(context);
    final textPrimary = AppColors.textPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
            Text(
              target > 0
                  ? '${valueG.round()} / $target g'
                  : '${valueG.round()} g',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border(context),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
