import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/presentation/state/calorie_recipe_nudge_provider.dart';

/// Home-screen card connecting calorie tracking (Feature 6) to recipes:
/// "312 kcal left today — 3 dinner ideas from your list." Only shown to
/// users who opted into calorie tracking and have a configured goal; renders
/// nothing when there's no meaningful budget left or no stored-nutrition
/// recipe fits it. Dismissible for the rest of the day.
class CalorieRecipeNudgeCard extends ConsumerWidget {
  const CalorieRecipeNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(calorieNudgeDismissedProvider).valueOrNull ?? false;
    if (dismissed) return const SizedBox.shrink();

    final remaining = ref.watch(remainingCaloriesTodayProvider).valueOrNull;
    final suggestions =
        ref.watch(calorieRecipeSuggestionsProvider).valueOrNull ?? const [];
    if (remaining == null || suggestions.isEmpty) return const SizedBox.shrink();

    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        8,
        AppDimensions.screenHorizontalPadding,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AvoMascot(size: 22, expression: AvoExpression.happy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context
                        .tr('calorie_nudge_title', params: {'kcal': '$remaining'})
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await CalorieRecipeNudgeService.instance.dismissToday();
                    ref.invalidate(calorieNudgeDismissedProvider);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            for (final suggestion in suggestions)
              _RecipeSuggestionRow(
                suggestion: suggestion,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/recipes/${suggestion.recipe.id}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeSuggestionRow extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final VoidCallback onTap;

  const _RecipeSuggestionRow({
    required this.suggestion,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = suggestion.recipe;
    final calories = recipe.nutrition?.calories;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 38,
                  height: 38,
                  color: AppColors.recipeInput(context),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 38,
                  height: 38,
                  color: AppColors.recipeInput(context),
                  child: const Icon(Icons.restaurant_rounded, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  if (calories != null)
                    Text(
                      context.tr('calorie_nudge_line', params: {
                        'kcal': '$calories',
                        'time': '${recipe.totalTimeMinutes}',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  if (suggestion.usesListItems)
                    Text(
                      context.tr('calorie_nudge_uses_list', params: {
                        'items': suggestion.matchedListItems.take(2).join(', '),
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}
