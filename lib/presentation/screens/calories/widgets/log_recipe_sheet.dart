import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Logs a recipe's nutrition (per serving) to the food diary — how many
/// servings, which meal — connecting the recipe system to Feature 6.
Future<void> showLogRecipeSheet(
  BuildContext context, {
  required String recipeId,
  required String recipeName,
  required NutritionInfo nutritionPerServing,
}) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _LogRecipeSheet(
      recipeId: recipeId,
      recipeName: recipeName,
      nutritionPerServing: nutritionPerServing,
    ),
  );
}

class _LogRecipeSheet extends ConsumerStatefulWidget {
  final String recipeId;
  final String recipeName;
  final NutritionInfo nutritionPerServing;

  const _LogRecipeSheet({
    required this.recipeId,
    required this.recipeName,
    required this.nutritionPerServing,
  });

  @override
  ConsumerState<_LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends ConsumerState<_LogRecipeSheet> {
  double _servings = 1;
  MealType _meal = MealType.dinner;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final n = widget.nutritionPerServing;
    final calories = ((n.calories ?? 0) * _servings).round();
    final proteinG = n.proteinG == null ? null : n.proteinG! * _servings;
    final carbsG = n.carbsG == null ? null : n.carbsG! * _servings;
    final fatG = n.fatG == null ? null : n.fatG! * _servings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('log_recipe_title'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 4),
          Text(widget.recipeName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: textSecondary)),
          const SizedBox(height: 18),
          Text(context.tr('log_recipe_meal'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MealType.values.map((m) {
              return AppChip(
                label: context.tr('meal_${m.dbValue}'),
                isSelected: _meal == m,
                onTap: () => setState(() => _meal = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('log_recipe_servings'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
              Row(
                children: [
                  IconButton(
                    onPressed: _servings > 0.5
                        ? () => setState(() => _servings = (_servings - 0.5).clamp(0.5, 20))
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(_servings.toStringAsFixed(_servings % 1 == 0 ? 0 : 1),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                  IconButton(
                    onPressed: () => setState(() => _servings = (_servings + 0.5).clamp(0.5, 20)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$calories kcal', style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 16),
          AppButton(
            text: context.tr('log_recipe_save'),
            isLoading: _saving,
            onPressed: () async {
              final authUser = ref.read(authUserProvider).valueOrNull;
              if (authUser == null || _saving) return;
              setState(() => _saving = true);
              HapticFeedback.mediumImpact();
              await ref.read(foodLogServiceProvider).addEntry(FoodLogEntry(
                    id: '',
                    userId: authUser.id,
                    loggedDate: DateTime.now(),
                    mealType: _meal,
                    source: FoodLogSource.recipe,
                    sourceRecipeId: widget.recipeId,
                    foodName: widget.recipeName,
                    quantity: _servings,
                    unit: 'serving',
                    calories: calories,
                    proteinG: proteinG,
                    carbsG: carbsG,
                    fatG: fatG,
                    createdAt: DateTime.now(),
                  ));
              invalidateNutritionLog(ref);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('log_recipe_success', params: {'name': widget.recipeName}))),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
