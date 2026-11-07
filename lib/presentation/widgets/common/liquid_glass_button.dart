import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// iOS 26 style Liquid Glass filled button for forms and bottom sheets.
/// 
/// This creates a rectangular button with rounded corners and frosted glass effect.
/// Typically used for primary actions in bottom sheets or forms.
/// 
/// Example usage:
/// ```dart
/// LiquidGlassFilledButton(
///   label: 'Save',
///   onPressed: () => handleSave(),
/// )
/// 
/// // Destructive action:
/// LiquidGlassFilledButton(
///   label: 'Delete',
///   onPressed: () => handleDelete(),
///   isDestructive: true,
/// )
/// ```
class LiquidGlassFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDestructive;
  
  const LiquidGlassFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final buttonColor = isDestructive ? Colors.red : (color ?? AppColors.lightAccent);
    
    return GestureDetector(
      onTap: isDisabled ? null : () {
        HapticFeedback.lightImpact();
        onPressed!();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDisabled ? 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    buttonColor.withOpacity(0.9),
                    buttonColor,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 0.5,
                ),
                boxShadow: isDisabled ? null : [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    letterSpacing: -0.4,
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

/// iOS 26 style Liquid Glass outlined button.
/// 
/// This creates a transparent button with a subtle border, typically used for
/// secondary actions alongside a filled primary button.
/// 
/// Example usage:
/// ```dart
/// Row(
///   children: [
///     Expanded(
///       child: LiquidGlassOutlinedButton(
///         label: 'Cancel',
///         onPressed: () => Navigator.pop(context),
///       ),
///     ),
///     SizedBox(width: 12),
///     Expanded(
///       child: LiquidGlassFilledButton(
///         label: 'Save',
///         onPressed: () => handleSave(),
///       ),
///     ),
///   ],
/// )
/// ```
class LiquidGlassOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  
  const LiquidGlassOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.05),
              border: Border.all(
                color: isDestructive 
                    ? Colors.red.withOpacity(0.5) 
                    : (isDark ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.15)),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
