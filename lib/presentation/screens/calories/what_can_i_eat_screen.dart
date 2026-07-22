import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/services/calorie_recipe_nudge_service.dart';
import 'package:shoply/presentation/state/calorie_recipe_nudge_provider.dart';

/// The dedicated in-app "What can I still eat today?" surface — the same
/// question Avo already answers in chat (`get_nutrition_status` →
/// `search_recipes`), but as a first-class dashboard screen for anyone who
/// doesn't want to open the chat for it. Reuses the exact same ranking
/// [CalorieRecipeNudgeService] already computes for the home card, just with
/// a longer list (up to 15 vs. 3) and no dismiss state — this is an
/// on-demand lookup, not a proactive nudge, so the two surfaces don't
/// compete with each other.
class WhatCanIEatScreen extends ConsumerWidget {
  const WhatCanIEatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final remainingAsync = ref.watch(remainingCaloriesTodayProvider);
    final suggestionsAsync = ref.watch(whatCanIEatSuggestionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(context.tr('what_can_i_eat_title'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(remainingCaloriesTodayProvider);
            ref.invalidate(whatCanIEatSuggestionsProvider);
          },
          child: remainingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text(context.tr('calories_log_error'))),
            data: (remaining) {
              if (remaining == null) {
                return AppEmptyState(
                  icon: Icons.restaurant_outlined,
                  title: context.tr('what_can_i_eat_empty_no_goal_title'),
                  subtitle: context.tr('what_can_i_eat_empty_no_goal_sub'),
                );
              }
              if (remaining < CalorieRecipeNudgeService.minRemainingCalories) {
                return AppEmptyState(
                  icon: Icons.no_meals_outlined,
                  title: context.tr('what_can_i_eat_empty_budget_title'),
                  subtitle: context.tr('what_can_i_eat_empty_budget_sub',
                      params: {'kcal': '$remaining'}),
                );
              }
              return suggestionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(context.tr('calories_log_error'))),
                data: (suggestions) {
                  if (suggestions.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 40),
                        AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: context.tr('what_can_i_eat_empty_no_match_title'),
                          subtitle: context.tr('what_can_i_eat_empty_no_match_sub'),
                          buttonText: context.tr('what_can_i_eat_browse_cta'),
                          onButtonPressed: () {
                            HapticFeedback.selectionClick();
                            context.go('/recipes');
                          },
                        ),
                      ],
                    );
                  }
                  return _SuggestionsList(remaining: remaining, suggestions: suggestions);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final int remaining;
  final List<RecipeSuggestion> suggestions;

  const _SuggestionsList({required this.remaining, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: suggestions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              context.tr('what_can_i_eat_subtitle', params: {
                'kcal': '$remaining',
                'n': '${suggestions.length}',
              }),
              style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
            ),
          );
        }
        final suggestion = suggestions[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RecipeCard(suggestion: suggestion, accent: accent),
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final Color accent;

  const _RecipeCard({required this.suggestion, required this.accent});

  @override
  Widget build(BuildContext context) {
    final recipe = suggestion.recipe;
    final calories = recipe.nutrition?.calories;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/recipes/${recipe.id}');
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: recipe.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 56,
                height: 56,
                color: AppColors.recipeInput(context),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppColors.recipeInput(context),
                child: const Icon(Icons.restaurant_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 3),
                if (calories != null)
                  Text(
                    context.tr('calorie_nudge_line', params: {
                      'kcal': '$calories',
                      'time': '${recipe.totalTimeMinutes}',
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                if (suggestion.usesListItems) ...[
                  const SizedBox(height: 3),
                  Text(
                    context.tr('calorie_nudge_uses_list', params: {
                      'items': suggestion.matchedListItems.take(2).join(', '),
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: accent),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: textSecondary),
        ],
      ),
    );
  }
}
