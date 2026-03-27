import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/constants/list_background_gradients.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Animated list card widget with long-press scale animation
/// Supports various background types: image, gradient, color
class ListCardWithAnimation extends StatefulWidget {
  final String listId;
  final String name;
  final int itemCount;
  final String backgroundType;
  final String? backgroundValue;
  final String? backgroundImageUrl;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final GlobalKey? tutorialKey;

  const ListCardWithAnimation({
    super.key,
    required this.listId,
    required this.name,
    required this.itemCount,
    required this.backgroundType,
    this.backgroundValue,
    this.backgroundImageUrl,
    required this.updatedAt,
    required this.onTap,
    required this.onLongPress,
    this.tutorialKey,
  });

  @override
  State<ListCardWithAnimation> createState() => _ListCardWithAnimationState();
}

class _ListCardWithAnimationState extends State<ListCardWithAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    print('🟦 [ListCard] initState for ${widget.name} (${widget.listId})');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _controller.forward();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _controller.reverse();
    widget.onLongPress();
  }

  void _onLongPressCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: AppDimensions.spacingMedium),
        child: SizedBox(
          width: 140,
          height: 140 * 1.75,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: _onLongPressCancel,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: widget.tutorialKey,
                  decoration: _buildBackgroundDecoration(context),
                  width: double.infinity,
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.name,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getTextColor(context),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.itemCount} ${context.tr('items')}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getTextColor(context).withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build background decoration based on type
  BoxDecoration _buildBackgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Type: image
    if (widget.backgroundType == 'image' && widget.backgroundImageUrl != null) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(widget.backgroundImageUrl!),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            // Image failed to load, will show gradient fallback
            print('Failed to load background image: $exception');
          },
        ),
      );
    }

    // Type: gradient
    if (widget.backgroundType == 'gradient' && widget.backgroundValue != null) {
      return BoxDecoration(
        gradient: ListBackgroundGradients.getGradient(widget.backgroundValue),
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    // Type: color
    if (widget.backgroundType == 'color' && widget.backgroundValue != null) {
      Color bgColor;
      try {
        // Parse hex color
        final hex = widget.backgroundValue!.replaceFirst('#', '');
        bgColor = Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        // Fallback to default
        bgColor = isDark ? Colors.white : Colors.black;
      }

      return BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    // Default fallback (old behavior)
    return BoxDecoration(
      color: isDark ? Colors.white : Colors.black,
      borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Get text color based on background
  Color _getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // For images and gradients, always use white
    if (widget.backgroundType == 'image' || widget.backgroundType == 'gradient') {
      return Colors.white;
    }

    // For colors, determine based on brightness
    if (widget.backgroundType == 'color' && widget.backgroundValue != null) {
      try {
        final hex = widget.backgroundValue!.replaceFirst('#', '');
        final color = Color(int.parse('FF$hex', radix: 16));
        
        // Calculate luminance
        final luminance = color.computeLuminance();
        
        // Use white text for dark backgrounds, black for light backgrounds
        return luminance > 0.5 ? Colors.black : Colors.white;
      } catch (e) {
        return isDark ? Colors.black : Colors.white;
      }
    }

    // Default
    return isDark ? Colors.black : Colors.white;
  }
}
