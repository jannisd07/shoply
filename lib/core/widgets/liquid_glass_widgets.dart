import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// iOS 26 Liquid Glass Design System
/// Translucent, frosted glass effects with subtle borders and depth

/// Liquid Glass Button - iOS 26 style translucent button
class LiquidGlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? sfSymbol;
  final bool isLoading;
  final bool isPrimary;
  final bool isDestructive;
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.sfSymbol,
    this.isLoading = false,
    this.isPrimary = true,
    this.isDestructive = false,
    this.width,
    this.height = 50,
    this.borderRadius = 14,
    this.padding,
  });

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Colors based on state
    Color bgColor;
    Color textColor;
    Color borderColor;
    
    if (widget.isDestructive) {
      bgColor = isDark 
          ? AppColors.error.withValues(alpha: 0.25)
          : AppColors.error.withValues(alpha: 0.15);
      textColor = AppColors.error;
      borderColor = AppColors.error.withValues(alpha: 0.3);
    } else if (widget.isPrimary) {
      bgColor = isDark 
          ? AppColors.accentDark.withValues(alpha: 0.3)
          : AppColors.accent.withValues(alpha: 0.2);
      textColor = isDark ? AppColors.accentDark : AppColors.accent;
      borderColor = (isDark ? AppColors.accentDark : AppColors.accent).withValues(alpha: 0.4);
    } else {
      bgColor = isDark 
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      textColor = AppColors.textPrimary(context);
      borderColor = isDark 
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1);
    }

    // Pressed state adjustments
    if (_isPressed) {
      bgColor = bgColor.withValues(alpha: (bgColor.a * 1.5).clamp(0, 1));
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : () {
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius - 1),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.borderRadius - 1),
              ),
              child: Center(
                child: widget.isLoading
                    ? CupertinoActivityIndicator(radius: 10, color: textColor)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 20, color: textColor),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Icon Button
class LiquidGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;
  final bool isSelected;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconColor,
    this.isSelected = false,
  });

  @override
  State<LiquidGlassIconButton> createState() => _LiquidGlassIconButtonState();
}

class _LiquidGlassIconButtonState extends State<LiquidGlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = widget.isSelected
        ? (isDark ? AppColors.accentDark.withValues(alpha: 0.3) : AppColors.accent.withValues(alpha: 0.2))
        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06));
    
    final borderColor = widget.isSelected
        ? (isDark ? AppColors.accentDark : AppColors.accent).withValues(alpha: 0.4)
        : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1));
    
    final iconColor = widget.iconColor ?? 
        (widget.isSelected 
            ? (isDark ? AppColors.accentDark : AppColors.accent)
            : AppColors.textPrimary(context));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size / 3),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 3 - 1),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _isPressed 
                    ? bgColor.withValues(alpha: (bgColor.a * 1.5).clamp(0, 1))
                    : bgColor,
                borderRadius: BorderRadius.circular(widget.size / 3 - 1),
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.5,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Card Container
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isSelected;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark 
        ? Colors.white.withValues(alpha: isSelected ? 0.12 : 0.08)
        : Colors.white.withValues(alpha: isSelected ? 0.9 : 0.75);
    
    final borderColor = isSelected
        ? (isDark ? AppColors.accentDark : AppColors.accent).withValues(alpha: 0.5)
        : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(borderRadius - 1),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Dropdown Menu
class LiquidGlassDropdown<T> extends StatefulWidget {
  final T? value;
  final List<LiquidGlassDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final double borderRadius;

  const LiquidGlassDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.hint,
    this.borderRadius = 12,
  });

  @override
  State<LiquidGlassDropdown<T>> createState() => _LiquidGlassDropdownState<T>();
}

class _LiquidGlassDropdownState<T> extends State<LiquidGlassDropdown<T>> {
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    HapticFeedback.lightImpact();
    final overlay = Overlay.of(context);
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: _buildDropdownMenu(),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  Widget _buildDropdownMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.items.map((item) {
                final isSelected = item.value == widget.value;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onChanged?.call(item.value);
                    _closeDropdown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? AppColors.accentDark : AppColors.accent).withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected 
                                ? (isDark ? AppColors.accentDark : AppColors.accent)
                                : AppColors.textPrimary(context),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected 
                                  ? (isDark ? AppColors.accentDark : AppColors.accent)
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: isDark ? AppColors.accentDark : AppColors.accent,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItem = widget.items.cast<LiquidGlassDropdownItem<T>?>().firstWhere(
      (item) => item?.value == widget.value,
      orElse: () => null,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        key: _buttonKey,
        onTap: _toggleDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isOpen
                  ? (isDark ? AppColors.accentDark : AppColors.accent).withValues(alpha: 0.5)
                  : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1)),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius - 1),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                child: Row(
                  children: [
                    if (selectedItem?.icon != null) ...[
                      Icon(
                        selectedItem!.icon,
                        size: 20,
                        color: isDark ? AppColors.accentDark : AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        selectedItem?.label ?? widget.hint ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: selectedItem != null 
                              ? AppColors.textPrimary(context)
                              : AppColors.textTertiary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const LiquidGlassDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Liquid Glass Chip/Tag
class LiquidGlassChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final Color? selectedColor;

  const LiquidGlassChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onDelete,
    this.isSelected = false,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = selectedColor ?? (isDark ? AppColors.accentDark : AppColors.accent);
    
    final bgColor = isSelected
        ? accentColor.withValues(alpha: 0.25)
        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06));
    
    final borderColor = isSelected
        ? accentColor.withValues(alpha: 0.5)
        : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? accentColor : AppColors.textPrimary(context),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? accentColor : AppColors.textPrimary(context),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onDelete?.call();
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isSelected ? accentColor : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Input Field
class LiquidGlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;
  final bool autofocus;
  final FocusNode? focusNode;

  const LiquidGlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.maxLines = 1,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            onSubmitted: onSubmitted,
            maxLines: maxLines,
            autofocus: autofocus,
            focusNode: focusNode,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
              ),
              prefixIcon: prefixIcon != null 
                  ? Icon(prefixIcon, color: AppColors.textSecondary(context), size: 22)
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: prefixIcon != null ? 8 : 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
