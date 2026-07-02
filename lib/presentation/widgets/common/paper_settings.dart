import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';

/// Shared Paper-style building blocks for the settings subpages.

/// App bar with a serif title and a round paper back button.
class PaperSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const PaperSettingsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      leadingWidth: 58,
      leading: Center(
        child: PaperCircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      title: Text(
        title,
        style: PaperTextStyles.serif(
          20,
          color: AppColors.textPrimary(context),
        ),
      ),
      actions: actions,
    );
  }
}

/// Small circular icon button on a cream (light) / dark gray (dark) disc.
class PaperCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const PaperCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary(context)),
      ),
    );
  }
}

/// Terracotta pill save action for the app bar.
class PaperSaveButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const PaperSaveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: GestureDetector(
          onTap: loading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentColor(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: loading
                ? const CupertinoActivityIndicator(
                    radius: 8,
                    color: PaperColors.paper,
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: PaperColors.paper,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Uppercase letter-spaced section kicker.
class PaperSectionHeader extends StatelessWidget {
  final String title;

  const PaperSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Surface card decoration for input fields (paper surface + hairline).
BoxDecoration paperFieldDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppColors.surface(context),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border(context)),
  );
}
