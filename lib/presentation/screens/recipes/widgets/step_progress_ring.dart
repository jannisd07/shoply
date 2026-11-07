import 'package:flutter/material.dart';

/// Determinate "x/n" progress ring for the recipe editor and cooking mode
/// headers. Replaces a permanently spinning activity indicator that made
/// both screens look stuck loading.
class StepProgressRing extends StatelessWidget {
  /// Zero-based index of the current step.
  final int currentStep;
  final int totalSteps;
  final Color color;
  final Color trackColor;
  final Color textColor;

  const StepProgressRing({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.color,
    required this.trackColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps <= 0 ? 0.0 : (currentStep + 1) / totalSteps;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                color: color,
                backgroundColor: trackColor,
              ),
            ),
          ),
          Text(
            '${currentStep + 1}/$totalSteps',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
