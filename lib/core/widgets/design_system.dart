import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// Consistent design system widgets for the app
/// Use these widgets throughout the app for a unified look

// ============================================
// STANDARDIZED BORDER RADIUS
// ============================================

/// Standard border radius values for consistency
class AppRadius {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  
  // Commonly used BorderRadius
  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get extraLarge => BorderRadius.circular(xl);
  static BorderRadius get pill => BorderRadius.circular(100);
  
  // Card radius - use for all cards
  static BorderRadius get card => BorderRadius.circular(lg);
  
  // Button radius - use for all buttons
  static BorderRadius get button => BorderRadius.circular(md);
  
  // Input radius - use for all inputs
  static BorderRadius get input => BorderRadius.circular(md);
  
  // Bottom sheet radius
  static BorderRadius get bottomSheet => const BorderRadius.vertical(
    top: Radius.circular(24),
  );
  
  // Dialog radius
  static BorderRadius get dialog => BorderRadius.circular(xl);
}

// ============================================
// MODERN CARD WIDGET
// ============================================

/// A modern, consistent card widget
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool hasBorder;
  final double? borderRadius;
  
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.hasBorder = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = backgroundColor ?? AppColors.surface(context);
    final borderColor = AppColors.border(context);
    
    Widget card = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.lg),
        border: hasBorder ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.lg),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    
    return card;
  }
}

// ============================================
// MODERN BUTTON WIDGET
// ============================================

/// A modern, consistent primary button
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final ButtonSize size;
  
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.size = ButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.accentColor(context);
    final fgColor = textColor ?? Colors.white;
    
    final height = switch (size) {
      ButtonSize.small => 40.0,
      ButtonSize.medium => 52.0,
      ButtonSize.large => 56.0,
    };
    
    final fontSize = switch (size) {
      ButtonSize.small => 14.0,
      ButtonSize.medium => 16.0,
      ButtonSize.large => 17.0,
    };
    
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? CupertinoActivityIndicator(radius: 10, color: fgColor)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum ButtonSize { small, medium, large }

/// A modern outline button
class AppOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  
  const AppOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.border(context);
    final fg = textColor ?? AppColors.textPrimary(context);
    
    return SizedBox(
      width: width ?? double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.button,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MODERN INPUT FIELD
// ============================================

/// A modern, consistent text input field
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final bool enabled;
  
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = AppColors.inputFill(context);
    final textColor = AppColors.textPrimary(context);
    final hintColor = AppColors.textTertiary(context);
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        hintStyle: TextStyle(color: hintColor),
        labelStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: fillColor,
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: hintColor, size: 22)
            : null,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide(
            color: AppColors.accentColor(context),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),
    );
  }
}

// ============================================
// SECTION HEADER
// ============================================

/// A consistent section header with optional action
class AppSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;
  
  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionText,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    final secondaryColor = AppColors.textSecondary(context);
    
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.accentColor(context)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// LIST TILE
// ============================================

/// A consistent list tile widget
class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconBackgroundColor;
  
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    final secondaryColor = AppColors.textSecondary(context);
    final iconBg = iconBackgroundColor ?? AppColors.surface(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: AppRadius.small,
                ),
                child: Icon(
                  leadingIcon,
                  color: AppColors.accentColor(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ============================================
// BOTTOM SHEET
// ============================================

/// Helper to show a consistent bottom sheet
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double? maxHeight,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: maxHeight != null
        ? BoxConstraints(maxHeight: maxHeight)
        : null,
    builder: (context) {
      final bgColor = AppColors.surface(context);
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.bottomSheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: builder(context)),
          ],
        ),
      );
    },
  );
}

// ============================================
// CHIP / TAG
// ============================================

/// A consistent chip/tag widget
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool isSelected;
  
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppColors.accentColor(context)
        : (backgroundColor ?? AppColors.surface(context));
    final fgColor = isSelected
        ? Colors.white
        : (textColor ?? AppColors.textPrimary(context));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.pill,
          border: isSelected ? null : Border.all(
            color: AppColors.border(context),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// EMPTY STATE
// ============================================

/// A consistent empty state widget with Avo mascot option
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Widget? customIllustration;
  
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.customIllustration,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    final secondaryColor = AppColors.textSecondary(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIllustration != null)
              customIllustration!
            else if (icon != null)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: secondaryColor,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 15,
                  color: secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: buttonText!,
                onPressed: onButtonPressed,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
