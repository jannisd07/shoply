import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/ml_recommendations_provider.dart';
import 'package:shoply/presentation/widgets/recommendations/recommendation_card.dart';

/// ML-powered AI Recommendations Section
/// Uses hybrid ML approach: Sequential History + Item Associations + Collaborative Filtering
class MLRecommendationsSection extends ConsumerStatefulWidget {
  final String? listId;
  final Function(String itemName, String? category, double? quantity) onAddItem;

  const MLRecommendationsSection({
    super.key,
    required this.listId,
    required this.onAddItem,
  });

  @override
  ConsumerState<MLRecommendationsSection> createState() => _MLRecommendationsSectionState();
}

class _MLRecommendationsSectionState extends ConsumerState<MLRecommendationsSection> {
  bool _isExpanded = false; // Start collapsed

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    if (widget.listId == null) {
      return const SizedBox.shrink();
    }

    final recommendationsAsync = ref.watch(mlRecommendationsProvider(widget.listId));

    // Use a fixed minimum height to prevent layout shifts
    const double minHeight = 72.0;

    return recommendationsAsync.when(
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? AppColors.accentDark.withOpacity(0.12) 
                : AppColors.accentLight.withOpacity(0.6),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with AI Badge
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // AI Icon - No background
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('ai_recommendations'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('based_on_purchases'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDarkMode 
                                    ? AppColors.accentDark.withOpacity(0.8) 
                                    : AppColors.accent.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Expand/Collapse Arrow
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDarkMode ? AppColors.accentDark : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Expandable Recommendations List
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recommendations.map((recommendation) {
                      return RecommendationCard(
                        recommendation: recommendation,
                        onAdd: () => widget.onAddItem(
                          recommendation.itemName,
                          recommendation.category,
                          recommendation.quantity,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: _isExpanded 
                    ? CrossFadeState.showFirst 
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? AppColors.accentDark.withOpacity(0.12) 
              : AppColors.accentLight.withOpacity(0.6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('ai_recommendations'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('loading'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkMode 
                          ? AppColors.accentDark.withOpacity(0.8) 
                          : AppColors.accent.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            CupertinoActivityIndicator(radius: 10, color: isDarkMode ? AppColors.accentDark : AppColors.accent,),
          ],
        ),
      ),
      error: (error, stack) {
        return const SizedBox.shrink();
      },
    );
  }
}
