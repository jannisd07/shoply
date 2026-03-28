import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// iOS-style success confirmation alert with Liquid Glass design
/// On iOS 26+: frosted glass blur effect with translucent background
/// On older iOS: clean Apple-style alert
class SuccessAlert {
  /// Show a success confirmation dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? buttonText,
    int? itemCount,
    IconData icon = Icons.check_circle_rounded,
    Color? iconColor,
    VoidCallback? onConfirm,
  }) async {
    HapticFeedback.heavyImpact();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim, secondAnim) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: _SuccessAlertContent(
              title: title,
              subtitle: subtitle,
              buttonText: buttonText ?? context.tr('great'),
              itemCount: itemCount,
              icon: icon,
              iconColor: iconColor,
              onConfirm: onConfirm,
            ),
          ),
        );
      },
    );
  }

  /// Convenience method for single item added
  static Future<void> showItemAdded(
    BuildContext context, {
    required String listName,
  }) {
    return show(
      context,
      title: context.tr('item_added_success'),
      subtitle: context.tr('added_to', params: {'listName': listName}),
      icon: Icons.check_circle_rounded,
    );
  }

  /// Convenience method for multiple items added
  static Future<void> showItemsAdded(
    BuildContext context, {
    required int count,
    required String listName,
  }) {
    return show(
      context,
      title: context.tr('items_added_success', params: {'count': count.toString()}),
      subtitle: context.tr('added_to', params: {'listName': listName}),
      itemCount: count,
      icon: Icons.check_circle_rounded,
    );
  }
}

class _SuccessAlertContent extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String buttonText;
  final int? itemCount;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onConfirm;

  const _SuccessAlertContent({
    required this.title,
    this.subtitle,
    required this.buttonText,
    this.itemCount,
    required this.icon,
    this.iconColor,
    this.onConfirm,
  });

  @override
  State<_SuccessAlertContent> createState() => _SuccessAlertContentState();
}

class _SuccessAlertContentState extends State<_SuccessAlertContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScale;
  late Animation<double> _iconBounce;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _iconBounce = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _iconController.forward();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = widget.iconColor ?? AppColors.success;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 28),

                  // Animated icon
                  AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _iconScale.value,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: green.withValues(alpha: isDark ? 0.2 : 0.12),
                          ),
                          child: Center(
                            child: Transform.scale(
                              scale: 0.8 + (_iconBounce.value * 0.2),
                              child: Icon(
                                widget.icon,
                                size: 36,
                                color: green,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),

                  // Subtitle
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : const Color(0xFF8E8E93),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Divider
                  Container(
                    height: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                  ),

                  // Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onConfirm?.call();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.transparent,
                      child: Text(
                        widget.buttonText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.accentDark : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
