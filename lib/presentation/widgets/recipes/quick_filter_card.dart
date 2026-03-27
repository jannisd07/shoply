import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe_filter.dart';

class QuickFilterCard extends StatelessWidget {
  final QuickFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  const QuickFilterCard({
    super.key,
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  /// Get translated label for the filter
  String _getTranslatedLabel(BuildContext context) {
    // Use filter ID as translation key with 'filter_' prefix
    return context.tr('filter_${filter.id}');
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final surfaceColor = AppColors.recipeSurface(context);
    final borderColor = AppColors.recipeBorderColor(context);
    final translatedLabel = _getTranslatedLabel(context);

    return Semantics(
      button: true,
      selected: isActive,
      label: '$translatedLabel filter',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.recipeAccentColor(context) : surfaceColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Show check icon when active
              if (isActive) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                translatedLabel,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? Colors.white : textPrimary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
