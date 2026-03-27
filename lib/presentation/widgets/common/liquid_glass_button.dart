import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// iOS 26 style Liquid Glass circular icon button - Flutter-based to avoid PlatformView crashes.
/// 
/// This widget creates a round, frosted glass button that mimics iOS 26's native
/// Liquid Glass design. It uses Flutter's BackdropFilter instead of PlatformViews
/// to avoid crashes with CALayer and NaN frame issues.
/// 
/// Example usage:
/// ```dart
/// LiquidGlassButton(
///   icon: Icons.close,
///   onPressed: () => Navigator.pop(context),
/// )
/// 
/// // Filled variant:
/// LiquidGlassButton(
///   icon: Icons.check,
///   onPressed: () => handleSubmit(),
///   isFilled: true,
/// )
/// ```
class LiquidGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isFilled;
  final double? size;
  
  const LiquidGlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.isFilled = false,
    this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? (isDark ? Colors.white : Colors.black);
    final buttonSize = size ?? 44.0;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isFilled 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (color ?? AppColors.lightAccent).withOpacity(0.9),
                      (color ?? AppColors.lightAccent),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.08),
                          ]
                        : [
                            Colors.white.withOpacity(0.7),
                            Colors.white.withOpacity(0.5),
                          ],
                  ),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.25) 
                    : Colors.white.withOpacity(0.8),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: buttonSize * 0.5,
              color: isFilled ? Colors.white : buttonColor,
            ),
          ),
        ),
      ),
    );
  }
}

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

/// A popup menu item for [LiquidGlassPopupMenuButton].
class LiquidGlassMenuItem<T> {
  final String label;
  final IconData icon;
  final T value;
  final bool isDestructive;
  
  const LiquidGlassMenuItem({
    required this.label,
    required this.icon,
    required this.value,
    this.isDestructive = false,
  });
}

/// iOS 26 style Liquid Glass popup menu button.
/// 
/// This creates a round glass button that shows a frosted glass dropdown menu
/// when tapped. The button appearance matches [LiquidGlassButton].
/// 
/// Example usage:
/// ```dart
/// LiquidGlassPopupMenuButton<int>(
///   icon: Icons.settings,
///   items: [
///     LiquidGlassMenuItem(label: 'Edit', icon: Icons.edit, value: 0),
///     LiquidGlassMenuItem(label: 'Delete', icon: Icons.delete, value: 1, isDestructive: true),
///   ],
///   onSelected: (value) => handleSelection(value),
/// )
/// ```
class LiquidGlassPopupMenuButton<T> extends StatelessWidget {
  final IconData icon;
  final List<LiquidGlassMenuItem<T>> items;
  final void Function(T value) onSelected;
  final double? size;
  
  const LiquidGlassPopupMenuButton({
    super.key,
    required this.icon,
    required this.items,
    required this.onSelected,
    this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDark ? Colors.white : Colors.black;
    final buttonSize = size ?? 44.0;
    
    return PopupMenuButton<T>(
      onSelected: onSelected,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.transparent,
      elevation: 0,
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
      itemBuilder: (context) => items.map((item) {
        return PopupMenuItem<T>(
          value: item.value,
          padding: EdgeInsets.zero,
          child: _LiquidGlassMenuItemWidget(
            label: item.label,
            icon: item.icon,
            isDestructive: item.isDestructive,
            isFirst: items.first == item,
            isLast: items.last == item,
          ),
        );
      }).toList(),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.08),
                      ]
                    : [
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.5),
                      ],
              ),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.25) 
                    : Colors.white.withOpacity(0.8),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: buttonSize * 0.5,
              color: buttonColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal widget for rendering menu items with liquid glass style.
class _LiquidGlassMenuItemWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final bool isFirst;
  final bool isLast;
  
  const _LiquidGlassMenuItemWidget({
    required this.label,
    required this.icon,
    required this.isDestructive,
    required this.isFirst,
    required this.isLast,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black);
    
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.white.withOpacity(0.7),
            border: !isLast ? Border(
              bottom: BorderSide(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.1),
                width: 0.5,
              ),
            ) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: textColor.withOpacity(0.8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
