import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/nutrition_info.dart';

/// Widget to display nutrition information for a recipe
class NutritionInfoWidget extends StatelessWidget {
  final NutritionInfo nutrition;
  final int servings;
  final bool expanded;

  const NutritionInfoWidget({
    super.key,
    required this.nutrition,
    this.servings = 1,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!nutrition.hasData) {
      return const SizedBox.shrink();
    }

    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final cardColor = AppColors.recipeSurface(context);
    final borderColor = AppColors.recipeBorderColor(context);

    // Adjust for servings if needed
    final adjustedNutrition = servings > 1 
        ? nutrition.adjustForServings(1, servings) 
        : nutrition;

    if (expanded) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded, 
                    size: 20, color: const Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                Text(
                  context.tr('nutrition_info'),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (servings > 1)
                  Text(
                    '${context.tr('for')} $servings ${context.tr('servings')}',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Calories (highlight)
            if (adjustedNutrition.calories != null)
              _buildCalorieRow(context, adjustedNutrition.calories!),
            const SizedBox(height: 12),
            // Macros
            Row(
              children: [
                if (adjustedNutrition.proteinG != null)
                  Expanded(child: _buildMacroChip(
                    context, 
                    context.tr('protein'), 
                    '${adjustedNutrition.proteinG!.toStringAsFixed(0)}g',
                    const Color(0xFF5AC8FA),
                  )),
                if (adjustedNutrition.carbsG != null)
                  Expanded(child: _buildMacroChip(
                    context, 
                    context.tr('carbs'), 
                    '${adjustedNutrition.carbsG!.toStringAsFixed(0)}g',
                    AppColors.recipeStarGold,
                  )),
                if (adjustedNutrition.fatG != null)
                  Expanded(child: _buildMacroChip(
                    context, 
                    context.tr('fat'), 
                    '${adjustedNutrition.fatG!.toStringAsFixed(0)}g',
                    AppColors.recipeStep,
                  )),
              ],
            ),
            // Additional info
            if (adjustedNutrition.fiberG != null || 
                adjustedNutrition.sugarG != null || 
                adjustedNutrition.sodiumMg != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (adjustedNutrition.fiberG != null)
                    _buildSmallInfo(context, context.tr('fiber'), 
                        '${adjustedNutrition.fiberG!.toStringAsFixed(0)}g'),
                  if (adjustedNutrition.sugarG != null)
                    _buildSmallInfo(context, context.tr('sugar'), 
                        '${adjustedNutrition.sugarG!.toStringAsFixed(0)}g'),
                  if (adjustedNutrition.sodiumMg != null)
                    _buildSmallInfo(context, context.tr('sodium'), 
                        '${adjustedNutrition.sodiumMg}mg'),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Compact view
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, 
              size: 16, color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 4),
          Text(
            '${adjustedNutrition.calories ?? '-'} kcal',
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (adjustedNutrition.proteinG != null) ...[
            const SizedBox(width: 8),
            Text(
              '${adjustedNutrition.proteinG!.toStringAsFixed(0)}g P',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieRow(BuildContext context, int calories) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.local_fire_department_rounded, 
                color: Color(0xFFFF6B6B), size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$calories',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              context.tr('calories'),
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroChip(BuildContext context, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(BuildContext context, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
