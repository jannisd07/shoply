import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/nutrition_info.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Logs [recipe] (nutrition per serving) to the food diary on its own
/// full-screen route, pushed like any screen (contract 3.3). Does nothing for
/// a recipe without nutrition values.
Future<void> openLogRecipe(BuildContext context, Recipe recipe) async {
  final nutrition = recipe.nutrition;
  if (nutrition == null || !nutrition.hasData) {
    debugPrint('⚠️ [CALORIES] Recipe ${recipe.id} has no nutrition to log');
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LogRecipeScreen(recipe: recipe, nutrition: nutrition),
    ),
  );
}

/// Meal and servings for one diary entry of a recipe.
class LogRecipeScreen extends ConsumerStatefulWidget {
  const LogRecipeScreen({
    super.key,
    required this.recipe,
    required this.nutrition,
  });

  final Recipe recipe;

  /// Per serving; [recipe.nutrition] with values.
  final NutritionInfo nutrition;

  @override
  ConsumerState<LogRecipeScreen> createState() => _LogRecipeScreenState();
}

class _LogRecipeScreenState extends ConsumerState<LogRecipeScreen> {
  static const double _step = 0.5;
  static const double _maxServings = 20;

  double _servings = 1;
  MealType _meal = MealType.dinner;
  bool _saving = false;

  int get _calories => ((widget.nutrition.calories ?? 0) * _servings).round();

  double? _scaled(double? perServing) =>
      perServing == null ? null : perServing * _servings;

  void _changeServings(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _servings = (_servings + delta).clamp(_step, _maxServings);
    });
  }

  Future<void> _save() async {
    final authUser = ref.read(authUserProvider).valueOrNull;
    if (authUser == null || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    try {
      await ref
          .read(foodLogServiceProvider)
          .addEntry(
            FoodLogEntry(
              id: '',
              userId: authUser.id,
              loggedDate: now,
              mealType: _meal,
              source: FoodLogSource.recipe,
              sourceRecipeId: widget.recipe.id,
              foodName: widget.recipe.name,
              quantity: _servings,
              unit: 'serving',
              calories: _calories,
              proteinG: _scaled(widget.nutrition.proteinG),
              carbsG: _scaled(widget.nutrition.carbsG),
              fatG: _scaled(widget.nutrition.fatG),
              createdAt: now,
            ),
          );
    } catch (e) {
      debugPrint('❌ [CALORIES] Failed to log recipe: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('generic_error'))));
      return;
    }
    invalidateNutritionLog(ref);

    String? milestone;
    try {
      milestone = await MascotNotificationService.instance
          .weeklyHighProteinMealMessage();
    } catch (_) {}
    if (!mounted) return;

    final message =
        milestone ??
        context.tr('log_recipe_success', params: {'name': widget.recipe.name});
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final servings = NumberFormat(
      '0.#',
      Localizations.localeOf(context).toString(),
    ).format(_servings);
    final labelStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(
          context.tr('log_recipe_title'),
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    widget.recipe.name,
                    style: TextStyle(fontSize: 15, color: textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Text(context.tr('log_recipe_meal'), style: labelStyle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final meal in MealType.values)
                        AppChip(
                          label: context.tr('meal_${meal.dbValue}'),
                          isSelected: _meal == meal,
                          onTap: () => setState(() => _meal = meal),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('log_recipe_servings'),
                          style: labelStyle,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('cal_servings_less'),
                        onPressed: _servings > _step
                            ? () => _changeServings(-_step)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          servings,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('cal_servings_more'),
                        onPressed: _servings < _maxServings
                            ? () => _changeServings(_step)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_calories kcal',
                    style: TextStyle(fontSize: 15, color: textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AppButton(
                text: context.tr('log_recipe_save'),
                isLoading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
