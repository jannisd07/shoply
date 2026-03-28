import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Success confirmation alert
/// iOS 26+: Liquid Glass frosted blur design
/// Older iOS: Native CupertinoAlertDialog
class SuccessAlert {
  static bool get _isIOS26OrLater {
    if (!Platform.isIOS) return false;
    final version = Platform.operatingSystemVersion; // e.g. "Version 26.0 ..."
    final match = RegExp(r'Version (\d+)').firstMatch(version);
    if (match != null) {
      final major = int.tryParse(match.group(1)!) ?? 0;
      return major >= 26;
    }
    return false;
  }

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

    final btn = buttonText ?? context.tr('great');

    if (_isIOS26OrLater) {
      // ── iOS 26+ Liquid Glass ──
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (ctx, anim, _, __) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: _LiquidGlassAlert(
                title: title,
                subtitle: subtitle,
                buttonText: btn,
                icon: icon,
                iconColor: iconColor,
                onConfirm: onConfirm,
              ),
            ),
          );
        },
      );
    } else {
      // ── Pre-iOS 26: Native Apple CupertinoAlertDialog ──
      await showCupertinoDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => CupertinoAlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor ?? AppColors.success),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title),
              ),
            ],
          ),
          content: subtitle != null ? Text(subtitle) : null,
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                onConfirm?.call();
                Navigator.of(ctx).pop();
              },
              child: Text(btn),
            ),
          ],
        ),
      );
    }
  }

  /// Single item added
  static Future<void> showItemAdded(
    BuildContext context, {
    required String listName,
  }) {
    return show(
      context,
      title: context.tr('item_added_success'),
      subtitle: context.tr('added_to', params: {'listName': listName}),
    );
  }

  /// Multiple items added
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
    );
  }
}

// ─────────────────────────────────────────────
// iOS 26 Liquid Glass Alert
// ─────────────────────────────────────────────

class _LiquidGlassAlert extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String buttonText;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onConfirm;

  const _LiquidGlassAlert({
    required this.title,
    this.subtitle,
    required this.buttonText,
    required this.icon,
    this.iconColor,
    this.onConfirm,
  });

  @override
  State<_LiquidGlassAlert> createState() => _LiquidGlassAlertState();
}

class _LiquidGlassAlertState extends State<_LiquidGlassAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    // Start icon animation immediately – no delay
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentGreen = widget.iconColor ?? AppColors.success;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  // Liquid glass: heavily translucent
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 26),

                    // Animated icon
                    AnimatedBuilder(
                      animation: _iconCtrl,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _iconScale.value,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentGreen.withValues(alpha: isDark ? 0.25 : 0.15),
                              border: Border.all(
                                color: accentGreen.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 30,
                              color: accentGreen,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),

                    // Subtitle
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF8E8E93),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Divider – glass-style
                    Container(
                      height: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                    ),

                    // Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onConfirm?.call();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
      ),
    );
  }
}
