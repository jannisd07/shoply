import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Load-error state for the recipe list pages. Shows a localized message
/// only — the raw exception text is for logs, not for users.
class RecipeErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const RecipeErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.tr('error_loading_recipes')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text(context.tr('retry'))),
        ],
      ),
    );
  }
}

/// Empty state for the recipe list pages: big icon, title, optional
/// subtitle and action.
class RecipeEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const RecipeEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Back-arrow app bar with the bold 20pt title the recipe list pages share.
PreferredSizeWidget recipeListAppBar(
  BuildContext context, {
  required Widget title,
  VoidCallback? onBack,
  List<Widget>? actions,
}) {
  final background = AppColors.recipeBg(context);
  final textPrimary = AppColors.textPrimary(context);
  return AppBar(
    backgroundColor: background,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: DefaultTextStyle.merge(
      style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      child: title,
    ),
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
    ),
    actions: actions,
  );
}
