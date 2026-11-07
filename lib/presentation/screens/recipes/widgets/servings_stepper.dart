import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact "−  n  +" servings stepper, shared by the recipe detail's
/// servings dialog and the add-to-list sheet.
class ServingsStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// Size of the value text; the dialog uses a larger number.
  final double valueFontSize;

  const ServingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.valueFontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: CupertinoIcons.minus,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        Container(
          constraints: BoxConstraints(minWidth: valueFontSize * 2),
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w600),
          ),
        ),
        _StepperButton(
          icon: CupertinoIcons.plus,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? CupertinoColors.systemBlue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3,
        ),
      ),
    );
  }
}
