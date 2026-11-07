import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';

/// Surface card with hairline border shared by the home nudge cards.
class NudgeCardShell extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final VoidCallback? onTap;

  const NudgeCardShell({
    super.key,
    required this.padding,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        8,
        AppDimensions.screenHorizontalPadding,
        0,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border(context)),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Small close "×" used to dismiss a nudge card.
class NudgeDismissButton extends StatelessWidget {
  final Future<void> Function() onDismiss;
  final double padding;

  const NudgeDismissButton({
    super.key,
    required this.onDismiss,
    this.padding = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onDismiss();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// One-line nudge: tinted icon circle, title, subtitle and a dismiss "×".
class NudgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Future<void> Function() onDismiss;

  const NudgeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    return NudgeCardShell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          NudgeDismissButton(onDismiss: onDismiss),
        ],
      ),
    );
  }
}
