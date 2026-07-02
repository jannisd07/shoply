import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Collapsible sliver header in paper style: date kicker line and a
/// serif time-based greeting, avatar on the right.
class GreetingHeader extends SliverPersistentHeaderDelegate {
  final String displayName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  GreetingHeader({
    required this.displayName,
    this.avatarUrl,
    required this.onAvatarTap,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 130;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final opacity = 1.0 - t;
    final scale = 1.0 - (t * 0.1);
    final translateY = t * -20.0;

    return Container(
      color: Colors.transparent,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppDimensions.spacingLarge,
                left: AppDimensions.screenHorizontalPadding,
                right: AppDimensions.screenHorizontalPadding,
                bottom: AppDimensions.spacingSmall,
              ),
              child: _GreetingContent(
                displayName: displayName,
                avatarUrl: avatarUrl,
                onAvatarTap: onAvatarTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant GreetingHeader oldDelegate) {
    return oldDelegate.displayName != displayName ||
        oldDelegate.avatarUrl != avatarUrl;
  }
}

class _GreetingContent extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  const _GreetingContent({
    required this.displayName,
    this.avatarUrl,
    required this.onAvatarTap,
  });

  String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'greeting_morning';
    if (hour < 18) return 'greeting_day';
    return 'greeting_evening';
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final dateLine = DateFormat('EEEE, d. MMMM', locale).format(DateTime.now());
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateLine,
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${context.tr(_greetingKey())},\n$displayName.',
                style: PaperTextStyles.serif(
                  27,
                  color: textPrimary,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: PaperColors.cream,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    (displayName.isNotEmpty ? displayName[0] : 'U')
                        .toUpperCase(),
                    style: PaperTextStyles.serif(
                      15,
                      color: PaperColors.creamInk,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
